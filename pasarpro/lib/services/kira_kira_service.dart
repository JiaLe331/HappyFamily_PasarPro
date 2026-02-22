import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

/// A single financial ledger entry parsed from a voice transcript.
class LedgerEntry {
  final String id;
  final double expense;
  final double revenue;
  final double profit;
  final String rawTranscript;
  final DateTime timestamp;

  LedgerEntry({
    required this.id,
    required this.expense,
    required this.revenue,
    required this.profit,
    required this.rawTranscript,
    required this.timestamp,
  });

  factory LedgerEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Use millisecondsSinceEpoch (stored as int) to avoid Int64 dart2js issues
    // on Flutter Web. Falls back to Timestamp if the field is a Timestamp.
    DateTime ts;
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      ts = DateTime.now();
    }

    return LedgerEntry(
      id: doc.id,
      expense: (data['expense'] as num).toDouble(),
      revenue: (data['revenue'] as num).toDouble(),
      profit: (data['profit'] as num).toDouble(),
      rawTranscript: data['rawTranscript'] as String? ?? '',
      timestamp: ts,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'expense': expense,
        'revenue': revenue,
        'profit': profit,
        'rawTranscript': rawTranscript,
        // Store as milliseconds int — avoids Int64 dart2js crash on Flutter Web
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
}

/// Aggregated totals for a set of ledger entries.
class LedgerSummary {
  final double totalExpense;
  final double totalRevenue;
  final double totalProfit;

  const LedgerSummary({
    required this.totalExpense,
    required this.totalRevenue,
    required this.totalProfit,
  });

  factory LedgerSummary.fromEntries(List<LedgerEntry> entries) {
    double expense = 0, revenue = 0, profit = 0;
    for (final e in entries) {
      expense += e.expense;
      revenue += e.revenue;
      profit += e.profit;
    }
    return LedgerSummary(
      totalExpense: expense,
      totalRevenue: revenue,
      totalProfit: profit,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Uses Gemini AI Studio REST API (generativelanguage.googleapis.com) for
/// transcript parsing and Cloud Firestore for ledger persistence.
///
/// Key design decisions:
/// • `responseMimeType: "application/json"` forces the model to emit a valid
///   JSON object — no markdown fences, no prose, guaranteed structure.
/// • `responseSchema` (the REST equivalent of the Dart SDK's Schema /
///   GenerationConfig) declares exactly three required `number` properties:
///   expense, revenue, profit. The model is constrained to this shape.
/// • The system instruction is detailed enough to handle English, Malay,
///   and Manglish (mixed) input — covering all common hawker vocabulary.
class KiraKiraService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'kira_kira_ledgers';

  // Gemini AI Studio — simple API key auth, no OAuth needed
  static const String _geminiHost = 'generativelanguage.googleapis.com';

  // gemini-2.0-flash: stable, fast, supports structured output / responseSchema
  static const String _geminiModel = 'gemini-2.5-flash';

  late final String _apiKey;

  KiraKiraService() {
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // System Prompt
  // ─────────────────────────────────────────────────────────────────────────

  /// Comprehensive system instruction for the Malaysian hawker financial parser.
  ///
  /// Written in the style of a strict financial accountant who speaks Malay
  /// and English. The prompt covers:
  ///   • Malay / Manglish vocabulary mapping (beli, jual, untung, modal, etc.)
  ///   • Implicit quantity × price multiplication
  ///   • Profit recalculation rule (always revenue − expense)
  ///   • Strict output constraint (only the schema fields, nothing else)
  static const String _systemInstruction = """
You are a strict financial accounting AI embedded inside PasarPro, a mobile app
used by Malaysian hawker stall owners (peniaga gerai) to track their daily
income and expenses by voice.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LANGUAGE UNDERSTANDING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The user may speak in English, Bahasa Malaysia, or Manglish (a mix).
Recognise and map these terms correctly:

EXPENSE keywords (money going OUT — modal / kos):
  beli, membeli, belanja, kos, modal, bayar, purchase, bought, buy, spend,
  spent, keluar, keluarkan, pelaburan, invest, overhead, sewa, ingredients,
  bahan, upah, gaji

REVENUE keywords (money coming IN — hasil jualan):
  jual, menjual, jualkan, sold, sell, sales, hasil, pendapatan, terima,
  dapat, kutip, income, proceeds, wang masuk, masuk

PROFIT keywords (usually stated or calculated — untung / keuntungan):
  untung, keuntungan, profit, earn, earned, buat, dapat untung, lebihan

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CALCULATION RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. If the user says "X unit at RM Y each" (or "X ketul RM Y"):
   → multiply: total = X × Y. Assign result to the correct category.

2. ALWAYS recalculate profit yourself:
   profit = revenue − expense
   Never trust a profit figure stated by the user; recalculate from
   the expense and revenue you extracted.

3. If only expense is mentioned and no revenue, set revenue = 0.
4. If only revenue is mentioned and no expense, set expense = 0.
5. Ignore any words that are not numbers or financial terms.
6. Currency symbols (RM, MYR, ringgit, sen) are NOT part of the number.
7. Use floating-point precision (e.g. 240.50, not 240).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EXAMPLE INPUTS → EXPECTED VALUES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input : "Beli ayam RM50, jual 30 mangkuk mee RM6 sorang"
Result: expense=50, revenue=180 (30×6), profit=130

Input : "Spent RM120 on ingredients. Sold total RM350 today."
Result: expense=120, revenue=350, profit=230

Input : "Modal hari ini RM80. Dapat RM200 dari jualan nasi lemak."
Result: expense=80, revenue=200, profit=120

Input : "Jual ABC 20 bungkus RM3.50 each, beli bahan RM45"
Result: expense=45, revenue=70 (20×3.50), profit=25

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT CONSTRAINT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
You MUST return ONLY the structured JSON object matching the declared schema.
Do NOT include any explanation, commentary, markdown, or extra fields.
All three fields (expense, revenue, profit) are required and must be numbers.
""";

  // ─────────────────────────────────────────────────────────────────────────
  // Response Schema  (REST-API equivalent of Dart SDK's Schema + SchemaType)
  // ─────────────────────────────────────────────────────────────────────────

  /// Declares the strict output shape the model must conform to.
  ///
  /// Mirrors what the Dart SDK expresses as:
  ///   Schema(SchemaType.object, properties: {
  ///     'expense': Schema(SchemaType.number, ...),
  ///     'revenue': Schema(SchemaType.number, ...),
  ///     'profit':  Schema(SchemaType.number, ...),
  ///   }, requiredProperties: ['expense', 'revenue', 'profit'])
  static const Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'description':
        'Structured financial figures extracted from a Malaysian hawker '
        'stall voice summary.',
    'properties': {
      'expense': {
        'type': 'NUMBER',
        'description':
            'Total money spent (modal / kos) in Malaysian Ringgit (RM). '
            'Must be >= 0.',
      },
      'revenue': {
        'type': 'NUMBER',
        'description':
            'Total money received from sales (hasil jualan) in RM. '
            'Must be >= 0.',
      },
      'profit': {
        'type': 'NUMBER',
        'description':
            'Net profit = revenue − expense. May be negative if a loss '
            '(rugi) occurred.',
      },
    },
    'required': ['expense', 'revenue', 'profit'],
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Gemini AI Studio Parsing
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends [transcript] to Gemini via the AI Studio REST API.
  ///
  /// The request uses:
  ///   • `responseMimeType: "application/json"` — instructs the model to
  ///     return a machine-readable JSON object, not prose.
  ///   • `responseSchema` — declares the exact output shape (expense,
  ///     revenue, profit as NUMBER types). The model is constrained to
  ///     produce ONLY this structure.
  ///   • `temperature: 0` — deterministic, no creative variation.
  ///
  /// Returns a [Map] with keys `expense`, `revenue`, `profit` (all double).
  Future<Map<String, double>> parseTranscript(String transcript) async {
    // AI Studio REST endpoint — uses ?key= query param, no OAuth required
    final url = Uri(
      scheme: 'https',
      host: _geminiHost,
      path: '/v1beta/models/$_geminiModel:generateContent',
      queryParameters: {'key': _apiKey},
    );

    // ── Build the request body ─────────────────────────────────────────────
    final body = jsonEncode({
      // System instruction: tells the model WHO it is and WHAT to do
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction}
        ],
      },

      // User turn: the raw voice transcript to parse
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': transcript}
          ],
        }
      ],

      // GenerationConfig equivalent — controls model behaviour & output format
      'generationConfig': {
        // ── Structured Output (core of this implementation) ───────────────
        // responseMimeType forces the output to be a valid JSON object.
        // This is the REST equivalent of GenerationConfig(responseMimeType:
        // "application/json") in the Dart SDK.
        'responseMimeType': 'application/json',

        // responseSchema constrains the JSON shape the model must produce.
        // REST equivalent of GenerationConfig(responseSchema: Schema(...)).
        // When both responseMimeType and responseSchema are set, the model
        // outputs ONLY a JSON object that matches this exact structure.
        'responseSchema': _responseSchema,

        // ── Thinking budget ───────────────────────────────────────────────
        // gemini-2.5-flash activates extended "thinking" by default, which
        // consumes hidden tokens BEFORE writing any output. Setting
        // thinkingBudget=0 disables thinking entirely for this task —
        // our extraction is straightforward and needs no chain-of-thought.
        // This is critical: without this, thinking tokens eat the output
        // budget and the JSON is truncated mid-write.
        'thinkingConfig': {
          'thinkingBudget': 0,
        },

        // ── Sampling parameters ───────────────────────────────────────────
        // temperature=0: fully deterministic — no creative guessing.
        'temperature': 0.0,

        // topP=1: include all tokens (temperature already constrains output).
        'topP': 1.0,

        // 1024 gives the model plenty of room for the JSON output even if
        // some preamble tokens slip through. The actual JSON is ~60 chars.
        'maxOutputTokens': 1024,

        // candidateCount=1: we need exactly one response.
        'candidateCount': 1,
      },
    });

    // ── HTTP call ──────────────────────────────────────────────────────────
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    // ── Parse the response ─────────────────────────────────────────────────
    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    // Guard against MAX_TOKENS truncation — if the model was cut off, the
    // JSON will be incomplete (exactly the bug we saw: {"expense":50,"revenue":
    // was returned without closing the object). Detect and surface this early.
    final candidate = responseData['candidates']?[0] as Map<String, dynamic>?;
    final finishReason = candidate?['finishReason'] as String?;
    if (finishReason != null &&
        finishReason != 'STOP' &&
        finishReason != 'FINISH_REASON_UNSPECIFIED') {
      throw Exception(
          'Gemini response was cut off (finishReason=$finishReason). '
          'This usually means the model ran out of output tokens. '
          'Raw body: ${response.body}');
    }

    // With responseMimeType=application/json, the model returns the JSON
    // object directly in the text field — no markdown fences or prose.
    final rawText = candidate?['content']?['parts']?[0]?['text'] as String?;

    if (rawText == null || rawText.trim().isEmpty) {
      throw Exception('Empty response from Gemini');
    }

    // ── Decode the guaranteed-JSON text ───────────────────────────────────
    // The model is schema-constrained, so we can decode directly.
    // As a safety net we still strip any accidental whitespace.
    late Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(rawText.trim()) as Map<String, dynamic>;
    } on FormatException {
      // Extremely rare fallback: try to extract a JSON object by regex
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
      if (jsonMatch == null) {
        throw Exception(
            'Could not find JSON in Gemini response: $rawText');
      }
      parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    }

    final expense = (parsed['expense'] as num?)?.toDouble() ?? 0.0;
    final revenue = (parsed['revenue'] as num?)?.toDouble() ?? 0.0;

    // Always recalculate profit on the client side for consistency —
    // ensures profit == revenue − expense even if the model drifts.
    final profit = revenue - expense;

    return {'expense': expense, 'revenue': revenue, 'profit': profit};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Firestore CRUD
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a new ledger entry and returns the saved [LedgerEntry].
  Future<LedgerEntry> saveEntry({
    required double expense,
    required double revenue,
    required double profit,
    required String rawTranscript,
  }) async {
    final now = DateTime.now();
    final entry = LedgerEntry(
      id: '',
      expense: expense,
      revenue: revenue,
      profit: profit,
      rawTranscript: rawTranscript,
      timestamp: now,
    );

    final docRef = await _db.collection(_collection).add(entry.toFirestore());
    return LedgerEntry(
      id: docRef.id,
      expense: expense,
      revenue: revenue,
      profit: profit,
      rawTranscript: rawTranscript,
      timestamp: now,
    );
  }

  /// Fetches all entries for today (local time), newest first.
  Future<List<LedgerEntry>> fetchTodayEntries() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Query using millisecond ints (matches how we store timestamps)
    final snapshot = await _db
        .collection(_collection)
        .where('timestamp',
            isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
        .where('timestamp',
            isLessThan: endOfDay.millisecondsSinceEpoch)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map(LedgerEntry.fromFirestore).toList();
  }

  /// Fetches all entries for the current month, newest first.
  Future<List<LedgerEntry>> fetchMonthEntries() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

    final snapshot = await _db
        .collection(_collection)
        .where('timestamp',
            isGreaterThanOrEqualTo: startOfMonth.millisecondsSinceEpoch)
        .where('timestamp',
            isLessThan: startOfNextMonth.millisecondsSinceEpoch)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map(LedgerEntry.fromFirestore).toList();
  }
}
