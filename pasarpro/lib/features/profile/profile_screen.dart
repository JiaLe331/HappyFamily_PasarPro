import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildBusinessDetails(context),
            const SizedBox(height: 16),
            _buildSettings(context),
            const SizedBox(height: 16),
            _buildAbout(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.store_rounded, size: 50, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          'Uncle Ah Meng',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Char Kway Teow Specialist',
          style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Edit Profile'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Details 🏪',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _buildListTile(
                icon: Icons.storefront_rounded,
                title: 'Stall Name',
                subtitle: 'Ah Meng Char Kway Teow',
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.location_on_rounded,
                title: 'Location',
                subtitle: 'Penang Road, Georgetown',
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.restaurant_rounded,
                title: 'Cuisine Type',
                subtitle: 'Malaysian Street Food',
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.phone_rounded,
                title: 'Contact',
                subtitle: '+60 12-345 6789',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings ⚙️', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _buildListTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'English, Malay, Mandarin',
                trailing: Icons.arrow_forward_ios_rounded,
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                subtitle: 'Push, Email',
                trailing: Icons.arrow_forward_ios_rounded,
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.help_rounded,
                title: 'Help & Support',
                subtitle: 'FAQs, Contact us',
                trailing: Icons.arrow_forward_ios_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAbout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About PasarPro', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      color: AppColors.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'KitaHack 2026',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'The "One-Click" Marketing Agency & OS for Every Hawker',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Powered by: Gemini 3 Pro, Nano Banana, Veo, Firebase & Google Maps',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    IconData? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
      ),
      trailing: trailing != null
          ? Icon(trailing, color: AppColors.onSurfaceVariant, size: 16)
          : null,
    );
  }
}
