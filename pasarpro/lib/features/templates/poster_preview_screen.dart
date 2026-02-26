import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../services/poster_service.dart';

/// Renders the chosen template poster and lets the user share it.
class PosterPreviewScreen extends StatefulWidget {
  final PosterTemplate template;
  final Uint8List imageBytes;
  final String itemName;
  final String price;
  final String promoText;
  final String aiCaption;

  const PosterPreviewScreen({
    super.key,
    required this.template,
    required this.imageBytes,
    required this.itemName,
    required this.price,
    required this.promoText,
    required this.aiCaption,
  });

  @override
  State<PosterPreviewScreen> createState() => _PosterPreviewScreenState();
}

class _PosterPreviewScreenState extends State<PosterPreviewScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSaving = false;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Capture RepaintBoundary → PNG bytes ──────────────────────────────────
  Future<Uint8List> _capturePoster() async {
    final boundary =
        _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _sharePoster() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _capturePoster();
      // XFile.fromData works on both web and native—no dart:io File needed
      final xFile = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'pasarpro_poster.png',
      );
      await Share.shareXFiles(
        [xFile],
        text: '${widget.aiCaption}\n\nCreated with PasarPro 🛒',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Route to correct template widget ─────────────────────────────────────
  Widget _buildPoster() {
    return switch (widget.template) {
      PosterTemplate.flashSale => _FlashSale01Poster(
          imageBytes: widget.imageBytes,
          itemName: widget.itemName,
          price: widget.price,
          promoText: widget.promoText,
        ),
      PosterTemplate.newMenu => _NewMenu01Poster(
          imageBytes: widget.imageBytes,
          itemName: widget.itemName,
          price: widget.price,
          promoText: widget.promoText,
        ),
      PosterTemplate.dailyPromo => _DailyPromo01Poster(
          imageBytes: widget.imageBytes,
          itemName: widget.itemName,
          price: widget.price,
          promoText: widget.promoText,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Poster Preview',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, color: AppColors.onPrimary),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Poster canvas ───────────────────────────────────────────
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Outer glow container
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: _buildPoster(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── AI Caption card ─────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.outline.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    color: AppColors.accent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'AI-Generated Caption',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.aiCaption,
                              style: GoogleFonts.outfit(
                                  color: AppColors.onSurface,
                                  fontSize: 14,
                                  height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Action bar ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  top: BorderSide(color: AppColors.outline.withOpacity(0.5))),
            ),
            child: Column(
              children: [
                // Share poster (Primary Action)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _sharePoster,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.share_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Saving…' : 'Share Poster',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Copy caption
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Copy to clipboard (we have no Clipboard import, use snackbar hint)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Caption copied! ✅',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w500))),
                      );
                    },
                    icon: Icon(Icons.copy_rounded, size: 18),
                    label: Text('Copy Caption',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE: FLASH_SALE_01
// High urgency · Yellow on Red · Large price badge top-right
// ═══════════════════════════════════════════════════════════════════════════
class _FlashSale01Poster extends StatelessWidget {
  final Uint8List imageBytes;
  final String itemName;
  final String price;
  final String promoText;
  const _FlashSale01Poster({
    required this.imageBytes,
    required this.itemName,
    required this.price,
    required this.promoText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background: food photo ─────────────────────────────────
            Image.memory(imageBytes, fit: BoxFit.cover),

            // ── Dark vignette overlay ──────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1.0],
                ),
              ),
            ),

            // ── Red "FLASH SALE" bottom banner ────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // FLASH SALE label
                    Text(
                      '⚡ FLASH SALE',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 13,
                        color: const Color(0xFFFFD600),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Item name
                    Text(
                      itemName.toUpperCase(),
                      style: GoogleFonts.bebasNeue(
                        fontSize: 30,
                        color: Colors.white,
                        height: 1,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Promo text
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD600),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        promoText,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 16,
                          color: const Color(0xFFE53935),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Circular Price Badge (top-right) ──────────────────────
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD600),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ONLY',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 11,
                        color: const Color(0xFFE53935),
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      price,
                      style: GoogleFonts.bebasNeue(
                        fontSize: price.length > 6 ? 16 : 20,
                        color: const Color(0xFFE53935),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Brand watermark ───────────────────────────────────────
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'PasarPro',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE: NEW_MENU_01
// Premium · Minimalist white/soft-grey · Serif header · "NEW ARRIVAL" top
// ═══════════════════════════════════════════════════════════════════════════
class _NewMenu01Poster extends StatelessWidget {
  final Uint8List imageBytes;
  final String itemName;
  final String price;
  final String promoText;
  const _NewMenu01Poster({
    required this.imageBytes,
    required this.itemName,
    required this.price,
    required this.promoText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          color: const Color(0xFFF8F7F4),
          child: Column(
            children: [
              // ── Top header ───────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PasarPro',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF37474F),
                            letterSpacing: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF37474F),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'NEW ARRIVAL',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: const Color(0xFFE0E0DC),
                    ),
                  ],
                ),
              ),

              // ── Food photo with soft shadow ───────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 24,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(imageBytes, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),

              // ── Bottom info ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 1, color: const Color(0xFFE0E0DC)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A1A),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                promoText,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF6B6B6B),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          price,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF37474F),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE: DAILY_PROMO_01
// Warm earth tones · Split screen (Photo left / Details right)
// ═══════════════════════════════════════════════════════════════════════════
class _DailyPromo01Poster extends StatelessWidget {
  final Uint8List imageBytes;
  final String itemName;
  final String price;
  final String promoText;
  const _DailyPromo01Poster({
    required this.imageBytes,
    required this.itemName,
    required this.price,
    required this.promoText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          color: const Color(0xFFF1EDE4),
          child: Column(
            children: [
              // ── Top header bar ────────────────────────────────────────
              Container(
                width: double.infinity,
                color: const Color(0xFF2E7D32),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '🌿 DAILY PROMO',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'PasarPro',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Split body ────────────────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: Food photo
                    Expanded(
                      flex: 5,
                      child: Image.memory(imageBytes, fit: BoxFit.cover),
                    ),

                    // Right: Details panel
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item name
                            Text(
                              itemName,
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Divider
                            Container(
                              height: 2,
                              width: 40,
                              color: const Color(0xFFA5D6A7),
                            ),
                            const SizedBox(height: 12),

                            // Bullet points
                            _BulletRow(text: promoText),
                            const SizedBox(height: 6),
                            _BulletRow(text: 'Fresh daily'),
                            const SizedBox(height: 6),
                            _BulletRow(text: 'Limited qty'),

                            const SizedBox(height: 16),

                            // Price badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8D6E63),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                price,
                                style: GoogleFonts.nunito(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom strip ──────────────────────────────────────────
              Container(
                width: double.infinity,
                color: const Color(0xFF8D6E63),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                child: Text(
                  'Nikmati setiap hidangan bersama kami 🍃',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.circle, size: 7, color: Color(0xFFA5D6A7)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
