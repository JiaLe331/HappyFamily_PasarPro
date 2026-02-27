import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../services/poster_service.dart';
import '../../services/database_service.dart';
import '../../models/saved_generation.dart';
import 'poster_preview_screen.dart';

class PosterGeneratorScreen extends StatefulWidget {
  final PosterTemplate initialTemplate;
  final Uint8List? initialImageBytes;
  final String? initialItemName;

  const PosterGeneratorScreen({
    super.key,
    required this.initialTemplate,
    this.initialImageBytes,
    this.initialItemName,
  });

  @override
  State<PosterGeneratorScreen> createState() => _PosterGeneratorScreenState();
}

class _PosterGeneratorScreenState extends State<PosterGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late PosterTemplate _selectedTemplate;
  Uint8List? _pickedImageBytes;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _promoTextCtrl = TextEditingController();
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.initialTemplate;
    _pickedImageBytes = widget.initialImageBytes;
    if (widget.initialItemName != null) {
      _itemNameCtrl.text = widget.initialItemName!;
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _itemNameCtrl.dispose();
    _priceCtrl.dispose();
    _promoTextCtrl.dispose();
    super.dispose();
  }

  // ── Colours & labels per template ─────────────────────────────────────────
  Color get _primaryColor => switch (_selectedTemplate) {
    PosterTemplate.flashSale => const Color(0xFFE53935),
    PosterTemplate.newMenu => const Color(0xFF37474F),
    PosterTemplate.dailyPromo => const Color(0xFF2E7D32),
  };

  Color get _accentColor => switch (_selectedTemplate) {
    PosterTemplate.flashSale => const Color(0xFFFFD600),
    PosterTemplate.newMenu => const Color(0xFFB0BEC5),
    PosterTemplate.dailyPromo => const Color(0xFF8D6E63),
  };

  String get _pricePlaceholder => switch (_selectedTemplate) {
    PosterTemplate.flashSale => 'e.g. RM 5.00',
    PosterTemplate.newMenu => 'e.g. RM 12.90',
    PosterTemplate.dailyPromo => 'e.g. RM 8.00',
  };

  String get _promoPlaceholder => switch (_selectedTemplate) {
    PosterTemplate.flashSale => 'e.g. Buy 1 Free 1',
    PosterTemplate.newMenu => 'e.g. Freshly launched today!',
    PosterTemplate.dailyPromo => 'e.g. 3 pcs for RM10',
  };

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final srcStr = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(primaryColor: _primaryColor),
    );
    if (srcStr == null) return;

    if (srcStr == 'enhanced') {
      await _pickFromEnhancedPhotos();
      return;
    }

    final src = srcStr == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final xFile = await picker.pickImage(source: src, imageQuality: 85);
    if (xFile != null && mounted) {
      final bytes = await xFile.readAsBytes();
      setState(() => _pickedImageBytes = bytes);
    }
  }

  Future<void> _pickFromEnhancedPhotos() async {
    final dbService = DatabaseService();
    final generations = await dbService.getAllGenerations();

    if (generations.isEmpty) {
      _showSnack('No enhanced photos available yet.');
      return;
    }

    if (!mounted) return;

    final selectedGeneration = await showModalBottomSheet<SavedGeneration>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EnhancedPhotoPickerSheet(
        generations: generations,
        primaryColor: _primaryColor,
      ),
    );

    if (selectedGeneration != null && mounted) {
      final String? selectedImagePath = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _ImageVariantPickerSheet(
          generation: selectedGeneration,
          primaryColor: _primaryColor,
        ),
      );

      if (selectedImagePath != null && mounted) {
        final file = File(selectedImagePath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          setState(() {
            _pickedImageBytes = bytes;
            if (_itemNameCtrl.text.isEmpty &&
                selectedGeneration.foodName.isNotEmpty) {
              _itemNameCtrl.text = selectedGeneration.foodName;
            }
          });
        }
      }
    }
  }

  // ── Navigate to preview ────────────────────────────────────────────────────
  Future<void> _proceed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImageBytes == null) {
      _showSnack('Please upload a photo first 📸');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final posterService = PosterService();
      final caption = await posterService.generateCaption(
        template: _selectedTemplate,
        itemName: _itemNameCtrl.text.trim(),
        price: _priceCtrl.text.trim(),
        promoText: _promoTextCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PosterPreviewScreen(
            template: _selectedTemplate,
            imageBytes: _pickedImageBytes!,
            itemName: _itemNameCtrl.text.trim(),
            price: _priceCtrl.text.trim(),
            promoText: _promoTextCtrl.text.trim(),
            aiCaption: caption,
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Poster Generator',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Step 1: Template selector ──────────────────────────
                _SectionHeader(
                  step: '01',
                  title: 'Choose Template',
                  color: _primaryColor,
                ),
                const SizedBox(height: 12),
                _TemplateSelector(
                  selected: _selectedTemplate,
                  onChanged: (t) => setState(() => _selectedTemplate = t),
                ),

                const SizedBox(height: 28),

                // ── Step 2: Upload image ───────────────────────────────
                _SectionHeader(
                  step: '02',
                  title: 'Upload Photo',
                  color: _primaryColor,
                ),
                const SizedBox(height: 12),
                _ImageUploadBox(
                  imageBytes: _pickedImageBytes,
                  primaryColor: _primaryColor,
                  onTap: _pickImage,
                ),

                const SizedBox(height: 28),

                // ── Step 3: Details ────────────────────────────────────
                _SectionHeader(
                  step: '03',
                  title: 'Fill in Details',
                  color: _primaryColor,
                ),
                const SizedBox(height: 12),
                _PasarTextField(
                  controller: _itemNameCtrl,
                  label: 'Item Name',
                  hint: 'e.g. Nasi Lemak',
                  icon: Icons.restaurant_menu_rounded,
                  accentColor: _primaryColor,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter item name'
                      : null,
                ),
                const SizedBox(height: 14),
                _PasarTextField(
                  controller: _priceCtrl,
                  label: 'Price',
                  hint: _pricePlaceholder,
                  icon: Icons.attach_money_rounded,
                  accentColor: _primaryColor,
                  keyboardType: TextInputType.text,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter price' : null,
                ),
                const SizedBox(height: 14),
                _PasarTextField(
                  controller: _promoTextCtrl,
                  label: 'Promo Text',
                  hint: _promoPlaceholder,
                  icon: Icons.local_offer_rounded,
                  accentColor: _primaryColor,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter promo text'
                      : null,
                ),

                const SizedBox(height: 36),

                // ── Generate button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _accentColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _proceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Generate Poster',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String step;
  final String title;
  final Color color;
  const _SectionHeader({
    required this.step,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            step,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Template Selector Chips ──────────────────────────────────────────────────
class _TemplateSelector extends StatelessWidget {
  final PosterTemplate selected;
  final ValueChanged<PosterTemplate> onChanged;
  const _TemplateSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: PosterTemplate.values
          .map(
            (t) => _TemplateChip(
              template: t,
              isSelected: t == selected,
              onTap: () => onChanged(t),
            ),
          )
          .toList(),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final PosterTemplate template;
  final bool isSelected;
  final VoidCallback onTap;
  const _TemplateChip({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  Color get _color => switch (template) {
    PosterTemplate.flashSale => const Color(0xFFE53935),
    PosterTemplate.newMenu => const Color(0xFF37474F),
    PosterTemplate.dailyPromo => const Color(0xFF2E7D32),
  };

  String get _subtitle => switch (template) {
    PosterTemplate.flashSale => 'High urgency · Yellow on Red · Bold',
    PosterTemplate.newMenu => 'Premium · Minimalist White · Elegant',
    PosterTemplate.dailyPromo => 'Warm · Community · Earth Tones',
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? _color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? _color : AppColors.outline,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: _color.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(template.emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(
          template.displayName,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isSelected ? _color : AppColors.onSurface,
          ),
        ),
        subtitle: Text(
          _subtitle,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: _color)
            : const Icon(
                Icons.radio_button_unchecked_rounded,
                color: AppColors.outline,
              ),
      ),
    );
  }
}

// ── Image Upload Box ─────────────────────────────────────────────────────────
class _ImageUploadBox extends StatelessWidget {
  final Uint8List? imageBytes;
  final Color primaryColor;
  final VoidCallback onTap;
  const _ImageUploadBox({
    required this.imageBytes,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          color: imageBytes == null
              ? primaryColor.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: imageBytes == null
                ? primaryColor.withOpacity(0.4)
                : Colors.transparent,
            width: 2,
            style: imageBytes == null ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: imageBytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 52,
                    color: primaryColor.withOpacity(0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to upload food photo',
                    style: GoogleFonts.outfit(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Camera or Gallery',
                    style: GoogleFonts.outfit(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(imageBytes!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Text Field ───────────────────────────────────────────────────────────────
class _PasarTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _PasarTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.outfit(fontSize: 15, color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          color: AppColors.onSurfaceVariant,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.outfit(
          color: accentColor,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: accentColor, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

// ── Image Source Bottom Sheet ────────────────────────────────────────────────
class _ImageSourceSheet extends StatelessWidget {
  final Color primaryColor;
  const _ImageSourceSheet({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose Photo Source',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SourceTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: primaryColor,
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SourceTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: primaryColor,
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SourceTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Enhanced',
                  color: primaryColor,
                  onTap: () => Navigator.pop(context, 'enhanced'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Enhanced Photo Picker Sheets ─────────────────────────────────────────────
class _EnhancedPhotoPickerSheet extends StatelessWidget {
  final List<SavedGeneration> generations;
  final Color primaryColor;
  const _EnhancedPhotoPickerSheet({
    required this.generations,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a Generation',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: generations.length,
                  itemBuilder: (context, index) {
                    final gen = generations[index];
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, gen),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(gen.originalImagePath),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                child: Text(
                                  gen.foodName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImageVariantPickerSheet extends StatelessWidget {
  final SavedGeneration generation;
  final Color primaryColor;
  const _ImageVariantPickerSheet({
    required this.generation,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> paths = [
      generation.originalImagePath,
      ...generation.enhancedImagePaths,
    ];
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose Version',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: paths.length,
              itemBuilder: (context, index) {
                final isOriginal = index == 0;
                final path = paths[index];
                return GestureDetector(
                  onTap: () => Navigator.pop(context, path),
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOriginal ? 'Original' : 'Enhanced $index',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
