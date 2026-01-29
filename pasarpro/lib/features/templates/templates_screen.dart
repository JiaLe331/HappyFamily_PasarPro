import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menu of Inspiration 🎨',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Pre-made video styles so you don\'t start from scratch',
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            _buildTemplateCard(
              context,
              emoji: '⚡',
              title: 'Flash Sale',
              description: 'Limited time offer with countdown timer',
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            _buildTemplateCard(
              context,
              emoji: '🔥',
              title: 'Sold Out',
              description: 'Show popular items that flew off the shelf',
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            _buildTemplateCard(
              context,
              emoji: '🌧️',
              title: 'Rainy Day Special',
              description: 'Hot soup promo perfect for rainy weather',
              color: AppColors.secondary,
            ),
            const SizedBox(height: 12),
            _buildTemplateCard(
              context,
              emoji: '⭐',
              title: 'Customer Favorite',
              description: 'Highlight your best-selling dishes',
              color: AppColors.accent,
            ),
            const SizedBox(height: 12),
            _buildTemplateCard(
              context,
              emoji: '🎉',
              title: 'New Menu Item',
              description: 'Announce new dishes with excitement',
              color: Color(0xFF8B5CF6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title template - Coming soon!')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
