import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/poster_service.dart';
import 'poster_generator_screen.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Templates',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero header──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🎨 Graphic Engine',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pick a Template.\nCreate a Poster.',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your food photo, fill in the details, '
                    'and we\'ll render a stunning promotional poster — '
                    'with an AI-written caption.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Templates',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── FLASH SALE 01 ──────────────────────────────────────
                  _TemplateCard(
                    template: PosterTemplate.flashSale,
                    headline: 'FLASH SALE',
                    tagline: 'High urgency · High contrast',
                    description:
                        'Large circular price badge at top-right.\n'
                        '"FLASH SALE" banner stamped at the bottom.\n'
                        'Red background, bold yellow typography.',
                    gradient: const [Color(0xFFE53935), Color(0xFFFF7043)],
                    badgeColor: const Color(0xFFFFD600),
                    badgeTextColor: const Color(0xFFE53935),
                    featureTags: const [
                      '⚡ Urgency',
                      '💰 Price Badge',
                      '🔴 Bold Red',
                    ],
                    onTap: () => _navigate(context, PosterTemplate.flashSale),
                  ),

                  const SizedBox(height: 16),

                  // ── NEW MENU 01 ────────────────────────────────────────
                  _TemplateCard(
                    template: PosterTemplate.newMenu,
                    headline: 'NEW ARRIVAL',
                    tagline: 'Clean · Premium · Minimalist',
                    description:
                        'Food photo centred with a soft drop shadow.\n'
                        '"NEW ARRIVAL" pill badge in the header.\n'
                        'Elegant serif typography on a warm white canvas.',
                    gradient: const [Color(0xFF37474F), Color(0xFF607D8B)],
                    badgeColor: Colors.white,
                    badgeTextColor: const Color(0xFF37474F),
                    featureTags: const [
                      '✨ Elegant',
                      '🖼️ Centred Photo',
                      '🤍 Minimalist',
                    ],
                    onTap: () => _navigate(context, PosterTemplate.newMenu),
                  ),

                  const SizedBox(height: 16),

                  // ── DAILY PROMO 01 ─────────────────────────────────────
                  _TemplateCard(
                    template: PosterTemplate.dailyPromo,
                    headline: 'DAILY PROMO',
                    tagline: 'Warm · Community · Earth Tones',
                    description:
                        'Split-screen layout — photo on the left,\n'
                        'offer details with bullet points on the right.\n'
                        'Rounded, friendly Nunito typface.',
                    gradient: const [Color(0xFF2E7D32), Color(0xFF388E3C)],
                    badgeColor: const Color(0xFF8D6E63),
                    badgeTextColor: Colors.white,
                    featureTags: const [
                      '🌿 Earthy',
                      '↔️ Split Screen',
                      '📋 Bullet Points',
                    ],
                    onTap: () =>
                        _navigate(context, PosterTemplate.dailyPromo),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, PosterTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosterGeneratorScreen(initialTemplate: template),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Template Card Widget
// ═══════════════════════════════════════════════════════════════════════════
class _TemplateCard extends StatelessWidget {
  final PosterTemplate template;
  final String headline;
  final String tagline;
  final String description;
  final List<Color> gradient;
  final Color badgeColor;
  final Color badgeTextColor;
  final List<String> featureTags;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.headline,
    required this.tagline,
    required this.description,
    required this.gradient,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.featureTags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Gradient header ────────────────────────────────────────
            Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  // Template emoji watermark
                  Positioned(
                    right: -12,
                    top: -12,
                    child: Text(
                      template.emoji,
                      style: const TextStyle(fontSize: 90),
                    ),
                  ),
                  // Headline
                  Positioned(
                    left: 20,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: GoogleFonts.bebasNeue(
                            fontSize: 26,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          tagline,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'USE',
                        style: GoogleFonts.outfit(
                          color: badgeTextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: featureTags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: gradient.first.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: gradient.first.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: gradient.first,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  // CTA Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradient),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Create Poster',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 16),
                            ],
                          ),
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
    );
  }
}
