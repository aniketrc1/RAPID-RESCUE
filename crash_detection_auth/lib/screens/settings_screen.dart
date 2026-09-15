import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Settings tab mirroring the mockups for configurations and logout.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  static const String routeName = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _crashDetectionEnabled = true;
  bool _pushNotificationsEnabled = true;

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Logout', style: TextStyle(color: Color(0xFF1E293B))),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AppAuthProvider>().signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Soft off-white
      appBar: AppBar(
        automaticallyImplyLeading: false, // Hidden for bottom tab
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        title: const Text('Settings', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('SAFETY & SECURITY'),
              _buildGroupedCard([
                _buildToggleRow(
                  icon: Icons.shield_rounded,
                  title: 'Crash Detection',
                  subtitle: 'Notify emergency contacts if a\ncrash is detected',
                  value: _crashDetectionEnabled,
                  onChanged: (v) => setState(() => _crashDetectionEnabled = v),
                ),
                _buildDivider(),
                _buildActionRow(
                  icon: Icons.group_rounded,
                  title: 'Emergency Contacts',
                  subtitle: 'Manage 3 active contacts',
                  onTap: () {},
                ),
              ]),
              
              const SizedBox(height: 30),
              
              _buildSectionHeader('APP PREFERENCES'),
              _buildGroupedCard([
                _buildToggleRow(
                  icon: Icons.notifications_rounded,
                  title: 'Push Notifications',
                  subtitle: 'Sound and banner alerts',
                  value: _pushNotificationsEnabled,
                  onChanged: (v) => setState(() => _pushNotificationsEnabled = v),
                ),
                _buildDivider(),
                _buildActionRow(
                  icon: Icons.location_on_rounded,
                  title: 'Location Permissions',
                  subtitle: '✓ Always On',
                  onTap: () {},
                ),
              ]),
              
              const SizedBox(height: 30),
              
              _buildSectionHeader('ACCOUNT & LEGAL'),
              _buildGroupedCard([
                _buildActionRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Help Center',
                  subtitle: null,
                  trailingIcon: Icons.open_in_new_rounded,
                  onTap: () {},
                ),
                _buildDivider(),
                _buildActionRow(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy Policy',
                  subtitle: null,
                  onTap: () {},
                ),
              ]),
              
              const SizedBox(height: 40),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE5E5), // Very light pale red
                    foregroundColor: const Color(0xFFDC3545), // Deep red icon/text
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 24),
                  label: const Text('Logout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Center(
                child: Text(
                  'Rapid Rescue Version 1.2.0 (Build 442)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.blueGrey[400],
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[100], indent: 64);
  }

  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF0), // Pale pink background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: const Color(0xFFFF8B9A), size: 20),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildIcon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFFFFB3BA),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    String? subtitle,
    IconData trailingIcon = Icons.chevron_right_rounded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _buildIcon(icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.bold)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                  ]
                ],
              ),
            ),
            Icon(trailingIcon, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }
}
