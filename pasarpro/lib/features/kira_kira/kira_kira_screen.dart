import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/constants/app_colors.dart';
import '../../services/kira_kira_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class KiraKiraScreen extends StatefulWidget {
  const KiraKiraScreen({super.key});

  @override
  State<KiraKiraScreen> createState() => _KiraKiraScreenState();
}

class _KiraKiraScreenState extends State<KiraKiraScreen>
    with TickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────────────────────
  final KiraKiraService _service = KiraKiraService();
  final SpeechToText _speech = SpeechToText();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isProcessing = false;

  String _transcript = '';
  String _statusMessage = 'Hold & speak your daily summary';

  List<LedgerEntry> _entries = [];
  LedgerSummary _summary = const LedgerSummary(
    totalExpense: 0,
    totalRevenue: 0,
    totalProfit: 0,
  );

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initPulse();
    _initSpeech();
    _loadTodayData();
  }

  void _initPulse() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage = 'Microphone error: ${e.errorMsg}';
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
            }
          }
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }

    if (!_speechAvailable && mounted) {
      _showSnack(
        'Microphone permission denied. Please allow microphone access.',
        isError: true,
      );
    }
  }

  Future<void> _loadTodayData() async {
    try {
      final entries = await _service.fetchTodayEntries();
      if (mounted) {
        setState(() {
          _entries = entries;
          _summary = LedgerSummary.fromEntries(entries);
        });
      }
    } catch (e) {
      debugPrint('KiraKira: failed to load today data: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  // ── Speech ────────────────────────────────────────────────────────────────

  void _startListening() {
    if (!_speechAvailable) {
      _showSnack(
        'Microphone not available. Please check permissions.',
        isError: true,
      );
      return;
    }
    if (_isListening || _isProcessing) return;

    setState(() {
      _isListening = true;
      _transcript = '';
      _statusMessage = 'Listening…';
    });

    _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _transcript = result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> _stopListeningAndProcess() async {
    if (!_isListening) return;

    await _speech.stop();
    setState(() {
      _isListening = false;
      _statusMessage = 'Processing…';
    });

    final text = _transcript.trim();
    if (text.isEmpty) {
      setState(() => _statusMessage = 'Could not hear anything. Try again.');
      _showSnack('Could not understand audio. Please try again.',
          isError: true);
      return;
    }

    await _processTranscript(text);
  }

  Future<void> _processTranscript(String text) async {
    setState(() => _isProcessing = true);

    try {
      // 1. Parse via Gemini
      final parsed = await _service.parseTranscript(text);

      // 2. Save to Firestore
      final entry = await _service.saveEntry(
        expense: parsed['expense']!,
        revenue: parsed['revenue']!,
        profit: parsed['profit']!,
        rawTranscript: text,
      );

      // 3. Update local state
      setState(() {
        _entries = [entry, ..._entries];
        _summary = LedgerSummary.fromEntries(_entries);
        _statusMessage = 'Saved successfully! ✅';
      });

      _showSnack('New record added! 🎉');
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('API error') || msg.contains('Network')) {
        _showSnack('Network error. Please check your internet connection.',
            isError: true);
      } else {
        _showSnack('Failed to process. Please try again.', isError: true);
      }
      setState(() => _statusMessage = 'Hold & speak your daily summary');
      debugPrint('KiraKira error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCards(),
              const SizedBox(height: 20),
              _buildChart(),
              const SizedBox(height: 28),
              _buildMicSection(),
              const SizedBox(height: 20),
              if (_transcript.isNotEmpty) _buildTranscriptCard(),
              const SizedBox(height: 20),
              if (_entries.isNotEmpty) _buildRecentEntries(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kira-Kira 💰',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            'Voice Financial Ledger',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadTodayData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ── Summary Cards ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Revenue',
            value: _summary.totalRevenue,
            icon: Icons.trending_up_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Expense',
            value: _summary.totalExpense,
            icon: Icons.trending_down_rounded,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Profit',
            value: _summary.totalProfit,
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // ── Chart ─────────────────────────────────────────────────────────────────

  Widget _buildChart() {
    final hasData = _summary.totalRevenue > 0 ||
        _summary.totalExpense > 0 ||
        _summary.totalProfit != 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_entries.length} record${_entries.length == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: hasData
                  ? BarChart(_buildBarChartData())
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic_none_rounded,
                              color: AppColors.outline, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'No records yet today',
                            style: GoogleFonts.poppins(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Speak your first entry below',
                            style: GoogleFonts.poppins(
                              color: AppColors.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (hasData) ...[
              const SizedBox(height: 16),
              _buildChartLegend(),
            ],
          ],
        ),
      ),
    );
  }

  BarChartData _buildBarChartData() {
    final maxVal = [
      _summary.totalRevenue,
      _summary.totalExpense,
      _summary.totalProfit.abs(),
    ].reduce((a, b) => a > b ? a : b);

    final yMax = maxVal == 0 ? 100.0 : maxVal * 1.3;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: yMax,
      minY: _summary.totalProfit < 0 ? _summary.totalProfit * 1.3 : 0,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.onSurface,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final labels = ['Revenue', 'Expense', 'Profit'];
            return BarTooltipItem(
              '${labels[group.x]}\nRM ${rod.toY.toStringAsFixed(2)}',
              GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const labels = ['Revenue', 'Expense', 'Profit'];
              if (value.toInt() >= labels.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  labels[value.toInt()],
                  style: GoogleFonts.poppins(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 52,
            getTitlesWidget: (value, meta) {
              if (value == meta.max || value == meta.min) {
                return const SizedBox();
              }
              return Text(
                'RM${value.toInt()}',
                style: GoogleFonts.poppins(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 9,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.outline,
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: [
        _makeBar(0, _summary.totalRevenue, AppColors.success),
        _makeBar(1, _summary.totalExpense, AppColors.error),
        _makeBar(2, _summary.totalProfit, AppColors.primary),
      ],
    );
  }

  BarChartGroupData _makeBar(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 28,
          borderRadius: BorderRadius.circular(6),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 0,
            color: AppColors.outline.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: AppColors.success, label: 'Revenue'),
        const SizedBox(width: 16),
        _LegendDot(color: AppColors.error, label: 'Expense'),
        const SizedBox(width: 16),
        _LegendDot(color: AppColors.primary, label: 'Profit'),
      ],
    );
  }

  // ── Microphone Section ────────────────────────────────────────────────────

  Widget _buildMicSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: _isListening ? AppColors.error : AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListeningAndProcess(),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final scale = _isListening ? _pulseAnimation.value : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [AppColors.error, const Color(0xFFFF6B6B)]
                          : [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isListening ? AppColors.error : AppColors.primary)
                                .withValues(alpha: 0.35),
                        blurRadius: _isListening ? 28 : 14,
                        spreadRadius: _isListening ? 6 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isProcessing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isListening
                  ? 'Release to process'
                  : _isProcessing
                      ? 'Analysing with AI…'
                      : 'Hold the button and speak',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'e.g. "Bought chicken RM50, sold 30 bowls at RM8 each"',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Transcript Card ───────────────────────────────────────────────────────

  Widget _buildTranscriptCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isListening
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.accent.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.record_voice_over_rounded,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Recognised Text',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _transcript,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent Entries ────────────────────────────────────────────────────────

  Widget _buildRecentEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Recent Records',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ),
        ...(_entries.take(5).map((e) => _EntryTile(entry: e))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'RM ${value.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final LedgerEntry entry;

  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isProfit = entry.profit >= 0;
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (isProfit ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isProfit
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isProfit ? AppColors.success : AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.rawTranscript.length > 55
                        ? '${entry.rawTranscript.substring(0, 55)}…'
                        : entry.rawTranscript,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _MiniTag(
                        label: 'Rev: RM${entry.revenue.toStringAsFixed(0)}',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      _MiniTag(
                        label: 'Exp: RM${entry.expense.toStringAsFixed(0)}',
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isProfit ? '+' : ''}RM${entry.profit.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isProfit ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
