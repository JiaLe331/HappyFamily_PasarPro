import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
  final AudioRecorder _recorder = AudioRecorder();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isScanningReceipt = false;
  String? _recordingPath;

  String _transcript = '';
  String _statusMessage = 'Hold & speak your daily summary';

  // Date filter — defaults to today
  DateTime _selectedDate = DateTime.now();

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

  Future<void> _loadTodayData() async {
    try {
      final entries = await _service.fetchEntriesForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _entries = entries;
          _summary = LedgerSummary.fromEntries(entries);
        });
      }
    } catch (e) {
      debugPrint('KiraKira: failed to load data: $e');
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadTodayData();
    }
  }

  // ── Delete Entry ──────────────────────────────────────────────────────────

  Future<void> _deleteEntry(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Record',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete this entry?\n\n"${entry.rawTranscript.length > 60 ? '${entry.rawTranscript.substring(0, 60)}…' : entry.rawTranscript}"',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteEntry(entry.id);
        setState(() {
          _entries.removeWhere((e) => e.id == entry.id);
          _summary = LedgerSummary.fromEntries(_entries);
        });
        _showSnack('Record deleted');
      } catch (e) {
        _showSnack('Failed to delete', isError: true);
      }
    }
  }

  // ── Snap Receipt (OCR) ────────────────────────────────────────────────────

  Future<void> _snapReceipt() async {
    // Show bottom sheet to choose camera or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Snap Receipt 📸',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Take a photo or pick from gallery',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _isScanningReceipt = true;
      _statusMessage = 'Scanning receipt with Gemini AI…';
    });

    try {
      final result = await _service.parseReceiptImage(File(picked.path));

      final transcript = result['transcript'] as String;
      setState(() => _transcript = '📸 $transcript');

      // Save to Firestore
      final entry = await _service.saveEntry(
        expense: result['expense'] as double,
        revenue: result['revenue'] as double,
        profit: result['profit'] as double,
        rawTranscript: '📸 $transcript',
      );

      setState(() {
        _entries = [entry, ..._entries];
        _summary = LedgerSummary.fromEntries(_entries);
        _statusMessage = 'Receipt scanned! ✅';
      });

      _showSnack('Receipt processed! 🧾');
    } catch (e) {
      debugPrint('Receipt OCR error: $e');
      _showSnack('Failed to scan receipt. Try again.', isError: true);
      setState(() => _statusMessage = 'Hold & speak your daily summary');
    } finally {
      if (mounted) setState(() => _isScanningReceipt = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Recording (Gemini-powered STT) ────────────────────────────────────────

  Future<void> _startListening() async {
    if (_isListening || _isProcessing) return;

    // Check microphone permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnack('Microphone permission denied. Please allow in Settings.',
          isError: true);
      return;
    }

    // Build a unique file path in the app's temp directory
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/kira_kira_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC-LC → .m4a, excellent quality
        bitRate: 128000,
        sampleRate: 16000, // 16 kHz — optimal for speech recognition
        numChannels: 1,   // Mono — speech doesn't need stereo
      ),
      path: _recordingPath!,
    );

    if (mounted) {
      setState(() {
        _isListening = true;
        _transcript = '';
        _statusMessage = 'Listening… (Gemini AI)';
      });
    }
  }

  Future<void> _stopListeningAndProcess() async {
    if (!_isListening) return;

    final path = await _recorder.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = 'Transcribing with Gemini AI…';
        _isProcessing = true;
      });
    }

    if (path == null) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Recording failed. Try again.';
        });
        _showSnack('Recording failed. Please try again.', isError: true);
      }
      return;
    }

    try {
      // Stage 1: Gemini multimodal → accurate transcript
      final text = await _service.transcribeAudio(File(path));

      if (text.isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Could not hear anything. Try again.';
          });
          _showSnack('Could not understand audio. Please try again.',
              isError: true);
        }
        return;
      }

      if (mounted) setState(() => _transcript = text);

      // Stage 2: Parse transcript → financial figures
      await _processTranscript(text);
    } catch (e) {
      debugPrint('KiraKira transcription error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Hold & speak your daily summary';
        });
        _showSnack('Transcription failed. Please try again.', isError: true);
      }
    } finally {
      // Clean up the temp audio file
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
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
          icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
          onPressed: _isScanningReceipt ? null : _snapReceipt,
          tooltip: 'Snap Receipt',
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
          onPressed: _pickDate,
          tooltip: 'Pick Date',
        ),
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
                  _isToday ? 'Today\'s Summary' : '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
            const SizedBox(height: 16),
            // ── Snap Receipt inline button ──
            OutlinedButton.icon(
              onPressed: _isScanningReceipt ? null : _snapReceipt,
              icon: _isScanningReceipt
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(Icons.receipt_long_rounded,
                      color: AppColors.primary, size: 18),
              label: Text(
                _isScanningReceipt ? 'Scanning...' : 'Or snap a receipt',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        ...(_entries.take(10).map((e) => Dismissible(
          key: Key(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            await _deleteEntry(e);
            return false; // we handle removal in _deleteEntry
          },
          child: GestureDetector(
            onTap: () => _showEntryDetail(e),
            child: _EntryTile(entry: e),
          ),
        ))),
      ],
    );
  }

  // ── Entry Detail Bottom Sheet ──────────────────────────────────────────────

  Future<void> _showEntryDetail(LedgerEntry entry) async {
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _EntryDetailSheet(
          entry: entry,
          timeStr: timeStr,
          dateStr: dateStr,
          service: _service,
        );
      },
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

/// Button used in the receipt image source picker bottom sheet.
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that shows an itemized breakdown for a ledger entry.
class _EntryDetailSheet extends StatefulWidget {
  final LedgerEntry entry;
  final String timeStr;
  final String dateStr;
  final KiraKiraService service;

  const _EntryDetailSheet({
    required this.entry,
    required this.timeStr,
    required this.dateStr,
    required this.service,
  });

  @override
  State<_EntryDetailSheet> createState() => _EntryDetailSheetState();
}

class _EntryDetailSheetState extends State<_EntryDetailSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBreakdown();
  }

  Future<void> _loadBreakdown() async {
    try {
      final items =
          await widget.service.getItemizedBreakdown(widget.entry.rawTranscript);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Breakdown error: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not load details';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProfit = widget.entry.profit >= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              // ── Handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Compact Header ──
              Row(
                children: [
                  Icon(
                    widget.entry.rawTranscript.startsWith('📸')
                        ? Icons.receipt_long_rounded
                        : Icons.record_voice_over_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.dateStr}  •  ${widget.timeStr}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${isProfit ? '+' : ''}RM${widget.entry.profit.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isProfit ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 12),
                        Text('Analysing with Gemini AI…'),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(_error!,
                        style: GoogleFonts.poppins(color: AppColors.error)),
                  ),
                )
              else ...[
                // ── Table Header ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Item',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant))),
                      Expanded(
                          child: Text('Qty',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant))),
                      Expanded(
                          flex: 2,
                          child: Text('Unit (RM)',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant))),
                      Expanded(
                          flex: 2,
                          child: Text('Total (RM)',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant))),
                    ],
                  ),
                ),

                // ── Table Rows ──
                ..._items.asMap().entries.map((mapEntry) {
                  final i = mapEntry.key;
                  final item = mapEntry.value;
                  final isExpense = item['type'] == 'expense';
                  final rowColor = isExpense
                      ? AppColors.error.withValues(alpha: 0.04)
                      : AppColors.success.withValues(alpha: 0.04);
                  final textColor =
                      isExpense ? AppColors.error : AppColors.success;
                  final isLast = i == _items.length - 1;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: rowColor,
                      border: Border(
                        bottom: isLast
                            ? BorderSide.none
                            : BorderSide(
                                color:
                                    AppColors.outline.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Icon(
                                isExpense
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: textColor,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item['item'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${item['qty']}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            (item['unitPrice'] as double).toStringAsFixed(2),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${isExpense ? '-' : '+'}${(item['total'] as double).toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // ── Totals ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12)),
                    border: Border(
                      top: BorderSide(
                          color: AppColors.outline.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Column(
                    children: [
                      _totalRow('Revenue', widget.entry.revenue,
                          AppColors.success),
                      const SizedBox(height: 4),
                      _totalRow(
                          'Expense', widget.entry.expense, AppColors.error),
                      const Divider(height: 12),
                      _totalRow(
                        'Net Profit',
                        widget.entry.profit,
                        isProfit ? AppColors.success : AppColors.error,
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _totalRow(String label, double value, Color color,
      {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          'RM${value.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
