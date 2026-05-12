import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../theme/colors.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _activeStatus = true;
  bool _chatHeads = true;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final displayName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : 'Anil Magar';
    final username = user?.username.isNotEmpty == true
        ? user!.username
        : 'anil.magar10116';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ProfileHeader(displayName: displayName, username: username),
          const SizedBox(height: 20),
          _Section(
            children: [
              _SettingSwitchTile(
                icon: Icons.circle,
                title: 'Active status',
                subtitle: _activeStatus ? 'On' : 'Off',
                value: _activeStatus,
                onChanged: (value) {
                  setState(() => _activeStatus = value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? 'Active status turned on'
                            : 'Active status turned off',
                      ),
                    ),
                  );
                },
              ),
              _SettingActionTile(
                icon: Icons.alternate_email,
                title: 'Username',
                subtitle: 'm.me/$username',
                onTap: () => _copyUsername(context, username),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionHeader('For families'),
          const SizedBox(height: 8),
          _Section(
            children: [
              _SettingActionTile(
                icon: Icons.family_restroom_outlined,
                title: 'Family Center',
                subtitle: 'Manage family settings',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Family Center',
                  description:
                      'Family Center helps manage safety and supervision tools.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionHeader('Services'),
          const SizedBox(height: 8),
          _Section(
            children: [
              _SettingActionTile(
                icon: Icons.shopping_bag_outlined,
                title: 'Orders',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Orders',
                  description: 'Orders will show your purchase history.',
                ),
              ),
              _SettingActionTile(
                icon: Icons.payments_outlined,
                title: 'Payments',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Payments',
                  description: 'Payments tools are not connected yet.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionHeader('Preferences'),
          const SizedBox(height: 8),
          _Section(
            children: [
              _SettingActionTile(
                icon: Icons.face_outlined,
                title: 'Avatar',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Avatar',
                  description: 'Avatar customization will be added here.',
                ),
              ),
              _SettingActionTile(
                icon: Icons.accessibility_new,
                title: 'Accessibility',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Accessibility',
                  description: 'Accessibility controls will be added here.',
                ),
              ),
              _SettingActionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy & safety',
                trailingDot: true,
                onTap: () => _openInfoPage(
                  context,
                  title: 'Privacy & safety',
                  description:
                      'Privacy settings will control who can see your activity.',
                ),
              ),
              _SettingActionTile(
                icon: Icons.notifications_none,
                title: 'Notifications & sounds',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Notifications & sounds',
                  description: 'Notification rules and sounds go here.',
                ),
              ),
              _SettingSwitchTile(
                icon: Icons.forum_outlined,
                title: 'Chat heads',
                subtitle: _chatHeads ? 'On' : 'Off',
                value: _chatHeads,
                onChanged: (value) => setState(() => _chatHeads = value),
              ),
              _SettingActionTile(
                icon: Icons.photo_outlined,
                title: 'Photos & media',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Photos & media',
                  description: 'Media permissions and preview settings.',
                ),
              ),
              _SettingActionTile(
                icon: Icons.history_outlined,
                title: 'Memories',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Memories',
                  description: 'Saved memories and archive tools.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionHeader('Safety'),
          const SizedBox(height: 8),
          _Section(
            children: [
              _SettingActionTile(
                icon: Icons.switch_account_outlined,
                title: 'Switch profile',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              _SettingActionTile(
                icon: Icons.report_problem_outlined,
                title: 'Report technical problem',
                onTap: () => _showReportDialog(context),
              ),
              _SettingActionTile(
                icon: Icons.help_outline,
                title: 'Help',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Help',
                  description: 'Help and support options will open here.',
                ),
              ),
              _SettingActionTile(
                icon: Icons.description_outlined,
                title: 'Legal & policies',
                onTap: () => _openInfoPage(
                  context,
                  title: 'Legal & policies',
                  description: 'Legal terms and policy pages go here.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _AccountsCenterCard(
            onPersonalDetails: () => _openInfoPage(
              context,
              title: 'Personal details',
              description: 'Edit personal details and account info.',
            ),
            onPasswordSecurity: () => _openInfoPage(
              context,
              title: 'Password and security',
              description: 'Manage password and security settings here.',
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            children: [
              _SettingActionTile(
                icon: Icons.logout,
                title: 'Log out',
                onTap: () => _logout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyUsername(BuildContext context, String username) async {
    await Clipboard.setData(ClipboardData(text: 'm.me/$username'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username copied to clipboard')),
    );
  }

  void _openInfoPage(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InfoPage(title: title, description: description),
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report technical problem'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Describe the issue'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      text.isEmpty
                          ? 'Please type a problem first'
                          : 'Report saved locally: $text',
                    ),
                  ),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Do you want to log out from this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (context.mounted) {
      context.read<MessageService>().disconnectSocket();
    }
    await context.read<AuthService>().logout();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logged out')));
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String username;

  const _ProfileHeader({required this.displayName, required this.username});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: MessengerColors.messengerGradient,
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color:
                          Theme.of(context).textTheme.headlineLarge?.color ??
                          Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).iconTheme.color ?? Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: TextStyle(
              color: Theme.of(context).textTheme.headlineLarge?.color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '@$username',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyMedium?.color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;

  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : const Color(0x0D000000),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool trailingDot;

  const _SettingActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: MessengerColors.messengerBlue, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13,
              ),
            ),
      trailing: trailingDot
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            )
          : Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color),
      onTap: onTap,
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: MessengerColors.messengerBlue, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontSize: 13,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: MessengerColors.messengerBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _AccountsCenterCard extends StatelessWidget {
  final VoidCallback onPersonalDetails;
  final VoidCallback onPasswordSecurity;

  const _AccountsCenterCard({
    required this.onPersonalDetails,
    required this.onPasswordSecurity,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black54;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.all_inclusive,
                color: MessengerColors.messengerBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Meta',
                style: TextStyle(color: subtitleColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Accounts Center',
            style: TextStyle(
              color: titleColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your connected experiences and account settings across Meta technologies.',
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          _AccountCenterRow(
            icon: Icons.person,
            label: 'Personal details',
            onTap: onPersonalDetails,
          ),
          const SizedBox(height: 12),
          _AccountCenterRow(
            icon: Icons.shield_outlined,
            label: 'Password and security',
            onTap: onPasswordSecurity,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {},
            child: const Text('See more in Accounts Center'),
          ),
        ],
      ),
    );
  }
}

class _AccountCenterRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AccountCenterRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: MessengerColors.messengerBlue),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: titleColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  final String title;
  final String description;

  const _InfoPage({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          description,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
