import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../theme/colors.dart';
import '../widgets/notification_panel.dart';
import 'add_story_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        automaticallyImplyLeading: false,
        centerTitle: false,
        elevation: 0,
        title: const Text(
          'Menu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Consumer<NotificationService>(
            builder: (context, notificationService, _) {
              return Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Align(
                          alignment: Alignment.topRight,
                          child: NotificationPanel(
                            onClose: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                    tooltip: 'Notifications',
                  ),
                  if (notificationService.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: MessengerColors.messengerBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Colors.white,
            ),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _SectionCard(
            children: [
              _MenuTile(
                icon: Icons.account_circle_outlined,
                iconBackground: const Color(0xFFEAF2FF),
                iconColor: MessengerColors.messengerBlue,
                title: 'Profile',
                subtitle: 'View and edit your profile',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SectionCard(
            children: [
              _MenuTile(
                icon: Icons.person_add_alt_1,
                title: 'Friends',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friends screen coming soon')),
                  );
                },
              ),
              const _ThinDivider(),
              _MenuTile(
                icon: Icons.groups_2_outlined,
                title: 'Communities',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Communities screen coming soon'),
                    ),
                  );
                },
              ),
              const _ThinDivider(),
              _MenuTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SectionCard(
            children: [
              _MenuTile(
                icon: Icons.logout,
                title: 'Log out',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logout flow not wired yet')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade200);
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconBackground;
  final Color? iconColor;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconBackground,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        iconBackground ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final fgColor =
        iconColor ?? Theme.of(context).iconTheme.color ?? Colors.black87;

    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: fgColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: onTap,
    );
  }
}
