import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../features/calls/data/services/call_service.dart';
import '../../../../features/calls/presentation/screens/call_screen.dart';
import '../../../../features/friends/presentation/screens/friends_screen.dart';
import '../../../../features/menu/presentation/screens/menu_screen.dart';
import '../../../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../../features/settings/presentation/screens/settings_screen.dart';
import '../../../../models/message_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/friend_service.dart';
import '../../../../services/story_service.dart';
import '../../../../models/story_model.dart';
import '../../../../theme/colors.dart';
import '../../../stories/presentation/screens/add_story_screen.dart';
import '../../../stories/presentation/screens/story_viewer_screen.dart';
import '../../data/services/message_service.dart';
import 'chat_screen.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    final storyService = context.read<StoryService>();
    final friendService = context.read<FriendService>();
    final token = auth.accessToken;

    if (mounted) {
      setState(() => _loading = false);
    }

    if (token != null) {
      await Future.wait([
        messageService.fetchCurrentUserProfile(token),
        messageService.fetchConversations(token),
        messageService.fetchAllUsers(token),
        storyService.fetchStories(token),
        friendService.fetchContacts(token),
        friendService.fetchRequests(token),
      ]);
    }
  }

  Future<void> _refreshData(BuildContext context) async {
    final auth = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    final storyService = context.read<StoryService>();
    final friendService = context.read<FriendService>();
    final token = auth.accessToken;

    if (token == null) return;

    await messageService.fetchCurrentUserProfile(token);
    await messageService.fetchConversations(token);
    await messageService.fetchAllUsers(token);
    await storyService.fetchStories(token);
    await friendService.fetchContacts(token);
    await friendService.fetchRequests(token);
  }

  @override
  Widget build(BuildContext context) {
    final messageService = context.watch<MessageService>();
    final storyService = context.watch<StoryService>();
    final friendService = context.watch<FriendService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBackground = theme.scaffoldBackgroundColor;
    final appBarBackground =
        theme.appBarTheme.backgroundColor ?? pageBackground;
    final appBarForeground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final primaryTextColor =
        theme.textTheme.bodyLarge?.color ?? appBarForeground;
    final secondaryTextColor =
        theme.textTheme.bodyMedium?.color ?? primaryTextColor.withAlpha(179);
    final borderColor =
        isDark ? const Color(0xFF2A2F36) : const Color(0xFFE9EEF5);
    final searchFillColor = theme.inputDecorationTheme.fillColor ??
        (isDark ? const Color(0xFF1B1F24) : const Color(0xFFF2F4F7));
    final currentUsername = messageService.currentUserProfile?.username ?? '';
    final users = _filteredUsers(
      messageService.allUsers,
      excludeUsername: currentUsername,
    );
    final conversations = _filteredUsers(messageService.conversations);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 18,
        title: Text(
          'messenger',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: appBarForeground,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MenuScreen()),
            ),
            icon: Icon(Icons.dashboard_outlined, color: appBarForeground),
            tooltip: 'Menu',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: Icon(Icons.notifications_none, color: appBarForeground),
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () => _refreshData(context),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                            child: _buildSearchBar(
                              fillColor: searchFillColor,
                              borderColor: borderColor,
                              textColor: primaryTextColor,
                              hintColor: secondaryTextColor,
                            ),
                          ),
                        ),
                        // Feature strip removed as per UI update request
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildStoriesRow(context, storyService),
                          ),
                        ),
                        if (users.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No registered users found',
                                style: TextStyle(color: secondaryTextColor),
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final user = users[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                  child: _buildUserTile(
                                    context,
                                    user,
                                    friendService,
                                  ),
                                );
                              },
                              childCount: users.length,
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: _buildSectionHeader(
                              context,
                              title: 'Recent chats',
                              subtitle: '${conversations.length} conversations',
                              titleColor: primaryTextColor,
                              subtitleColor: secondaryTextColor,
                            ),
                          ),
                        ),
                        if (conversations.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'No recent conversations yet',
                                style: TextStyle(color: secondaryTextColor),
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final user = conversations[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                  child: _buildConversationTile(context, user),
                                );
                              },
                              childCount: conversations.length,
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16 + 56,
                    child: Material(
                      color: const Color(0xFF9B4CFF),
                      shape: const CircleBorder(),
                      elevation: 6,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Meta AI feature coming soon'),
                            ),
                          );
                        },
                        child: const SizedBox(
                          width: 54,
                          height: 54,
                          child: Center(
                            child:
                                Icon(Icons.auto_awesome, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const _MessagingBottomNavBar(),
    );
  }

  Widget _buildSearchBar({
    required Color fillColor,
    required Color borderColor,
    required Color textColor,
    required Color hintColor,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: hintColor),
          hintText: 'Ask Meta AI or Search',
          hintStyle: TextStyle(color: hintColor),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFeatureStrip(BuildContext context) {
    final features = <_MessengerFeature>[
      _MessengerFeature(
        icon: Icons.person_outline,
        label: 'Profile',
        color: const Color(0xFF2F80FF),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      ),
      _MessengerFeature(
        icon: Icons.group_outlined,
        label: 'Friends',
        color: const Color(0xFF2F80FF),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        ),
      ),
      _MessengerFeature(
        icon: Icons.photo_library_outlined,
        label: 'Stories',
        color: const Color(0xFFFF6B6B),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddStoryScreen()),
        ),
      ),
      _MessengerFeature(
        icon: Icons.notifications_none,
        label: 'Alerts',
        color: const Color(0xFF6B7CFF),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
      _MessengerFeature(
        icon: Icons.settings_outlined,
        label: 'Settings',
        color: const Color(0xFF1F2937),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      _MessengerFeature(
        icon: Icons.dashboard_outlined,
        label: 'Menu',
        color: const Color(0xFF111827),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MenuScreen()),
        ),
      ),
      _MessengerFeature(
        icon: Icons.call,
        label: 'Calls',
        color: const Color(0xFF10B981),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Use the call buttons on each user row'),
            ),
          );
        },
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: features.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _FeatureChip(feature: features[index]),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoriesRow(BuildContext context, StoryService storyService) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black87);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ??
        (isDark ? const Color(0xFFB0B3B8) : Colors.black54);
    final borderColor =
        isDark ? const Color(0xFF2A2F36) : const Color(0xFFE9EEF5);
    final surfaceColor = theme.cardColor;

    final groups = storyService.stories;
    final messageService = context.read<MessageService>();
    final currentUser = messageService.currentUserProfile;

    // Build a map of existing story groups by username
    final Map<String, StoryGroup> groupMap = {
      for (final g in groups) g.username: g,
    };

    // Build a combined list of users to show as story bubbles (include current user first)
    final List<StoryGroup> displayGroups = [];

    // Add current user placeholder if present (will be shown after create bubble)
    if (currentUser != null) {
      if (groupMap.containsKey(currentUser.username)) {
        displayGroups.add(groupMap[currentUser.username]!);
      } else {
        displayGroups.add(StoryGroup(
          username: currentUser.username,
          displayName: currentUser.displayName,
          profileImage: currentUser.profileImage,
          isOnline: currentUser.isOnline,
          stories: [],
          hasUnviewed: false,
        ));
      }
    }

    // Add all registered users (including those without stories)
    for (final user in messageService.allUsers) {
      // include current user again only once
      if (currentUser != null && user.username == currentUser.username) {
        continue;
      }
      if (groupMap.containsKey(user.username)) {
        displayGroups.add(groupMap[user.username]!);
      } else {
        displayGroups.add(StoryGroup(
          username: user.username,
          displayName: user.displayName,
          profileImage: user.profileImage,
          isOnline: user.isOnline,
          stories: [],
          hasUnviewed: false,
        ));
      }
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: 1 + displayGroups.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Create story bubble (current user action)
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddStoryScreen()),
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 31,
                          backgroundColor: surfaceColor,
                          child: Icon(Icons.add, color: primaryTextColor),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              Icons.add,
                              color: primaryTextColor,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 74,
                      child: Text(
                        'Create story',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: secondaryTextColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final group = displayGroups[index - 1];

          return _storyBubble(
            label: group.displayName.split(' ').first,
            child: CircleAvatar(
              radius: 31,
              backgroundImage: group.profileImage != null
                  ? NetworkImage(group.profileImage!)
                  : null,
              child: group.profileImage == null
                  ? Text(
                      group.displayName.isNotEmpty ? group.displayName[0] : '?',
                      style: TextStyle(color: primaryTextColor),
                    )
                  : null,
            ),
            hasRing: group.hasUnviewed || group.stories.isNotEmpty,
            onTap: () {
              if (group.stories.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoryViewerScreen(storyGroup: group),
                  ),
                );
              } else {
                // No stories: open chat with that user if available
                final chatUser = messageService.allUsers
                    .firstWhere((u) => u.username == group.username,
                        orElse: () => ChatUser(
                              username: group.username,
                              firstName: group.displayName,
                              lastName: '',
                              email: '',
                            ));
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(chatUser: chatUser)));
              }
            },
          );
        },
      ),
    );
  }

  Widget _storyBubble({
    required String label,
    required Widget child,
    VoidCallback? onTap,
    bool hasRing = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = theme.textTheme.bodyMedium?.color ??
        (isDark ? const Color(0xFFB0B3B8) : Colors.black54);
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: hasRing
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2F80FF),
                        width: 2,
                      ),
                    )
                  : null,
              child: child,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 74,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: labelColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(
    BuildContext context,
    ChatUser user,
    FriendService friendService,
  ) {
    final auth = context.read<AuthService>();
    final token = auth.accessToken;
    final isFriend = friendService.isFriend(user.username);
    final isRequestPending = friendService.requests.contains(user.username);
    final actionLabel = isFriend
        ? 'Chat'
        : isRequestPending
            ? 'Requested'
            : 'Add friend';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black87);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ??
        (isDark ? const Color(0xFFB0B3B8) : Colors.black54);
    final borderColor =
        isDark ? const Color(0xFF2A2F36) : const Color(0xFFE9EEF5);
    final surfaceColor = theme.cardColor;

    return Card(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor:
                  isDark ? const Color(0xFF1E2228) : const Color(0xFFF0F4F8),
              backgroundImage: user.profileImage != null
                  ? NetworkImage(user.profileImage!)
                  : null,
              child: user.profileImage == null
                  ? Text(
                      user.initials,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            if (user.isOnline)
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF12B76A),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(
                        color: isDark ? const Color(0xFF1B1F24) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          user.displayName.isNotEmpty ? user.displayName : user.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          user.lastMessage?.isNotEmpty == true
              ? user.lastMessage!
              : user.bio.isNotEmpty
                  ? user.bio
                  : user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: secondaryTextColor),
        ),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!isFriend)
              OutlinedButton.icon(
                onPressed: token == null || isRequestPending
                    ? null
                    : () => _sendFriendRequest(context, user.username, token),
                icon: Icon(
                  isRequestPending ? Icons.hourglass_top : Icons.person_add,
                  size: 18,
                ),
                label: Text(actionLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isRequestPending
                      ? secondaryTextColor
                      : MessengerColors.messengerBlue,
                  side: BorderSide(
                    color: isRequestPending
                        ? borderColor
                        : MessengerColors.messengerBlue,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
            if (isFriend)
              _IconCircleButton(
                icon: Icons.call_outlined,
                color: const Color(0xFF10B981),
                tooltip: 'Call',
                onTap: token == null
                    ? null
                    : () => _startDirectCall(
                          context,
                          user,
                          token,
                          false,
                          isFriend,
                        ),
              ),
            if (isFriend)
              _IconCircleButton(
                icon: Icons.videocam_outlined,
                color: const Color(0xFF7C3AED),
                tooltip: 'Video',
                onTap: token == null
                    ? null
                    : () => _startDirectCall(
                          context,
                          user,
                          token,
                          true,
                          isFriend,
                        ),
              ),
          ],
        ),
        onTap: token == null
            ? null
            : () async {
                await context
                    .read<MessageService>()
                    .selectUser(user.username, token);
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(chatUser: user)),
                );
              },
      ),
    );
  }

  Future<void> _sendFriendRequest(
    BuildContext context,
    String username,
    String token,
  ) async {
    final friendService = context.read<FriendService>();
    final success = await friendService.sendRequest(token, username);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Friend request sent to $username'
              : 'Failed to send request: ${friendService.error ?? 'unknown error'}',
        ),
      ),
    );

    if (success) {
      await friendService.fetchRequests(token);
    }
  }

  Future<void> _startDirectCall(
    BuildContext context,
    ChatUser user,
    String token,
    bool videoCall,
    bool isFriend,
  ) async {
    final friendService = context.read<FriendService>();
    final callService = context.read<CallService>();
    final messageService = context.read<MessageService>();

    var allowed = isFriend;
    if (!allowed) {
      await friendService.fetchContacts(token);
      if (!context.mounted) return;
      allowed = friendService.isFriend(user.username);
    }

    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call is available only after becoming friends'),
        ),
      );
      return;
    }

    try {
      await callService.startOutgoingCall(
        user,
        videoCall: videoCall,
        callerProfileImage: messageService.currentUserProfile?.profileImage,
      );
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CallScreen()),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call failed: $e')),
      );
    }
  }

  Widget _buildConversationTile(BuildContext context, ChatUser user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black87);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ??
        (isDark ? const Color(0xFFB0B3B8) : Colors.black54);
    final borderColor =
        isDark ? const Color(0xFF2A2F36) : const Color(0xFFE9EEF5);
    final surfaceColor = theme.cardColor;

    return Card(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              isDark ? const Color(0xFF1E2228) : const Color(0xFFF0F4F8),
          backgroundImage: user.profileImage != null
              ? NetworkImage(user.profileImage!)
              : null,
          child: user.profileImage == null
              ? Text(
                  user.initials,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        title: Text(
          user.displayName.isNotEmpty ? user.displayName : user.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          user.lastMessage?.isNotEmpty == true
              ? user.lastMessage!
              : 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: secondaryTextColor),
        ),
        trailing: user.lastMessageTime == null
            ? null
            : Text(
                _formatDateLabel(user.lastMessageTime!),
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
        onTap: () async {
          final auth = context.read<AuthService>();
          final token = auth.accessToken;
          if (token != null) {
            await context
                .read<MessageService>()
                .selectUser(user.username, token);
          }
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatScreen(chatUser: user)),
          );
        },
      ),
    );
  }

  String _formatDateLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('T')) {
      return trimmed.split('T').first;
    }
    return trimmed;
  }

  List<ChatUser> _filteredUsers(
    List<ChatUser> users, {
    String? excludeUsername,
  }) {
    final query = _searchQuery.toLowerCase();
    return users.where((user) {
      if (excludeUsername != null && user.username == excludeUsername) {
        return false;
      }
      if (query.isEmpty) return true;
      return user.displayName.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          (user.lastMessage ?? '').toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }
}

class _MessengerFeature {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MessengerFeature({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _FeatureChip extends StatelessWidget {
  final _MessengerFeature feature;

  const _FeatureChip({required this.feature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF2A2F36) : const Color(0xFFE9EEF5);
    final surfaceColor = theme.cardColor;
    final primaryTextColor = theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black87);
    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(feature.icon, color: feature.color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                feature.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagingBottomNavBar extends StatelessWidget {
  const _MessagingBottomNavBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF2A2F36) : const Color(0xFFE9EEF5);
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.chat_bubble,
            label: 'Chats',
            color: MessengerColors.messengerBlue,
            onTap: () {
              // Already on Chats screen; do nothing or pop to root
            },
          ),
          _NavItem(
            icon: Icons.photo_library_outlined,
            label: 'Stories',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddStoryScreen()),
            ),
          ),
          _NavItem(
            icon: Icons.notifications_none,
            label: 'Notifications',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          _NavItem(
            icon: Icons.menu,
            label: 'Menu',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MenuScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _NavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayColor =
        color ?? (isDark ? const Color(0xFFB0B3B8) : Colors.black54);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: displayColor, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: displayColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final String? tooltip;

  const _IconCircleButton({
    required this.icon,
    this.onTap,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor =
        color ?? (isDark ? const Color(0xFFB0B3B8) : Colors.black54);
    final bg = baseColor.withValues(alpha: 0.12);
    final iconColor = baseColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
