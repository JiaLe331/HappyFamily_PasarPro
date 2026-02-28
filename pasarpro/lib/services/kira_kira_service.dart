import 'dart:convert';
import 'dart:io';
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
  // Gemini Audio Transcription (replaces Android System STT)
  // ─────────────────────────────────────────────────────────────────────────

  /// Transcribes an audio [file] using Gemini's native multimodal API.
  ///
  /// This replaces the Android system `speech_to_text` package entirely.
  /// Gemini understands Malaysian English, Manglish, and Bahasa Malaysia
  /// out of the box — far more accurate than Android's `en_US` STT engine.
  ///
  /// Supported formats: m4a, wav, ogg, mp3, flac, webm.
  /// The audio is base64-encoded into an inline data part (no upload needed
  /// for files under ~20 MB, which easily covers 30-second voice clips).
  Future<String> transcribeAudio(File audioFile) async {
    final audioBytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(audioBytes);

    // Derive MIME type from file extension
    final ext = audioFile.path.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'mp3' => 'audio/mpeg',
      'flac' => 'audio/flac',
      'webm' => 'audio/webm',
      _ => 'audio/mp4', // default for Android record package
    };

    final url = Uri(
      scheme: 'https',
      host: _geminiHost,
      path: '/v1beta/models/$_geminiModel:generateContent',
      queryParameters: {'key': _apiKey},
    );

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {
            'text':
                'You are a highly accurate speech-to-text transcription AI '
                'specialising in Malaysian English, Manglish, and Bahasa Malaysia. '
                'The speaker is a Malaysian hawker stall owner. '
                'Common terms they use: RM, ringgit, sen, beli, jual, untung, modal, '
                'laksa, nasi lemak, mee, ayam, ikan, char kway teow, teh tarik, kopi. '
                'Transcribe EXACTLY what you hear. Do NOT summarise, translate, or '
                'add any punctuation beyond commas and periods. '
                'If the speaker mixes Malay and English, transcribe both as spoken. '
                'Output ONLY the plain transcribed text, nothing else.'
          }
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              // Inline audio data — no separate upload step required
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Audio,
              }
            },
            {'text': 'Transcribe this audio recording accurately.'}
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.0,
        'maxOutputTokens': 512,
        'candidateCount': 1,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini transcription error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
        as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('Empty transcription from Gemini');
    }

    return text.trim();
  }

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

  // ─────────────────────────────────────────────────────────────────────────
  // Delete Entry
  // ─────────────────────────────────────────────────────────────────────────

  /// Deletes a ledger entry by its Firestore document ID.
  Future<void> deleteEntry(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch Entries for a Specific Date
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches all entries for a specific [date], newest first.
  Future<List<LedgerEntry>> fetchEntriesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

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

  // ─────────────────────────────────────────────────────────────────────────
  // Receipt OCR (Snap-Ledger)
  // ─────────────────────────────────────────────────────────────────────────

  /// OCR system instruction for parsing handwritten / printed receipts.
  static const String _receiptOcrInstruction = """
You are a receipt and invoice OCR specialist for PasarPro, a Malaysian hawker app.

The user will send you a photo of a handwritten or printed receipt, invoice,
or note listing items with prices (in Malaysian Ringgit, RM / MYR).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
YOUR TASK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Read ALL line items from the receipt, even if the handwriting is messy.
2. Classify each line as either an EXPENSE or REVENUE item:
   - EXPENSE: items purchased / bought / ingredients / supplies / kos / modal
   - REVENUE: items sold / jualan / sales / income
   - If the receipt looks like a PURCHASE receipt (buying supplies), all items are EXPENSES.
   - If the receipt looks like a SALES record, all items are REVENUE.
3. Sum up all EXPENSE items → total expense
4. Sum up all REVENUE items → total revenue
5. Calculate profit = total revenue − total expense
6. Create a short transcript describing the receipt contents in one line.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT FORMAT (strict JSON only)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
  "expense": 0.0,
  "revenue": 0.0,
  "profit": 0.0,
  "transcript": "one-line summary of the receipt"
}

RULES:
• Output ONLY valid JSON. No markdown, no explanations.
• All amounts are in RM (Malaysian Ringgit).
• If you cannot read certain parts, make your best estimate and note it in transcript.
• If the receipt is not readable at all, return all zeros and transcript = "Could not read receipt".
""";

  /// Parses a receipt image using Gemini Vision OCR.
  ///
  /// Returns a map with keys: expense, revenue, profit (double), transcript (String).
  Future<Map<String, dynamic>> parseReceiptImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Determine mime type from extension
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    final url = Uri.parse(
        'https://$_geminiHost/v1beta/models/$_geminiModel:generateContent?key=$_apiKey');

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _receiptOcrInstruction}
        ]
      },
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            },
            {
              'text': 'Parse this receipt and extract the financial data as JSON.'
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Receipt OCR API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract the generated text from the Gemini response
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Receipt OCR: no candidates in response');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Receipt OCR: no parts in response');
    }

    final text = parts[0]['text'] as String? ?? '';

    // Parse the JSON response
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return {
      'expense': (parsed['expense'] as num?)?.toDouble() ?? 0.0,
      'revenue': (parsed['revenue'] as num?)?.toDouble() ?? 0.0,
      'profit': (parsed['profit'] as num?)?.toDouble() ?? 0.0,
      'transcript': parsed['transcript'] as String? ?? 'Receipt scanned',
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Itemized Breakdown (on-demand re-parsing)
  // ─────────────────────────────────────────────────────────────────────────

  /// Re-parses a [rawTranscript] to produce an itemized breakdown table.
  ///
  /// Returns a list of maps, each with:
  ///   - `item` (String): e.g. "Chicken", "Nasi Lemak"
  ///   - `qty` (int): quantity, default 1
  ///   - `unitPrice` (double): price per unit in RM
  ///   - `total` (double): qty × unitPrice
  ///   - `type` (String): "expense" or "revenue"
  Future<List<Map<String, dynamic>>> getItemizedBreakdown(
      String rawTranscript) async {
    final url = Uri.parse(
        'https://$_geminiHost/v1beta/models/$_geminiModel:generateContent?key=$_apiKey');

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {
            'text': '''
You are a financial line-item parser for PasarPro, a Malaysian hawker app.

Given a raw transcript of a hawker's voice entry or receipt scan, extract
EVERY SINGLE individual item mentioned into a separate row.

CRITICAL RULES:
• NEVER group items together as "Various Ingredients" or "Assorted Items".
  If the transcript mentions "kuey teow, eggs, prawns, cooking oil, chilli paste",
  you MUST create 5 separate rows — one for each ingredient.
• If only a total price is given for multiple items, estimate a reasonable
  price split across all named items.
• "type" must be either "expense" or "revenue"
• expense = things BOUGHT / purchased / ingredients / supplies / kos / modal
• revenue = things SOLD / jualan / sales / income
• If quantity is not mentioned, default to 1
• If unitPrice is not mentioned but total is, distribute the total equally
  across the items or estimate based on typical Malaysian market prices.
• All amounts are in RM (Malaysian Ringgit)
• Output ONLY a valid JSON array. No markdown, no explanations.

OUTPUT FORMAT (strict JSON array):
[
  {"item": "Kuey Teow (flat noodles)", "qty": 5, "unitPrice": 3.50, "total": 17.50, "type": "expense"},
  {"item": "Eggs", "qty": 30, "unitPrice": 0.45, "total": 13.50, "type": "expense"},
  {"item": "Prawns (kg)", "qty": 2, "unitPrice": 35.00, "total": 70.00, "type": "expense"},
  {"item": "Char Kuey Teow (plate)", "qty": 30, "unitPrice": 8.00, "total": 240.00, "type": "revenue"}
]
'''
          }
        ]
      },
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Extract itemized breakdown from this hawker record:\n\n"$rawTranscript"'
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Breakdown API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Breakdown: no candidates');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    final text = parts?[0]['text'] as String? ?? '[]';

    final parsed = jsonDecode(text) as List;
    return parsed
        .map((e) => {
              'item': e['item'] as String? ?? 'Item',
              'qty': (e['qty'] as num?)?.toInt() ?? 1,
              'unitPrice': (e['unitPrice'] as num?)?.toDouble() ?? 0.0,
              'total': (e['total'] as num?)?.toDouble() ?? 0.0,
              'type': e['type'] as String? ?? 'expense',
            })
        .toList();
  }
}
