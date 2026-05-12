import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/message_model.dart';
import '../models/note_model.dart';
import '../models/story_model.dart';
import '../screens/add_note_screen.dart';
import '../screens/add_story_screen.dart';
import '../screens/call_screen.dart';
import '../screens/chat_screen.dart' as chat_screen;
import '../screens/menu_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/note_viewer_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/story_viewer_screen.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/message_service.dart';
import '../services/note_service.dart';
import '../services/notification_service.dart';
import '../services/story_service.dart';
import '../services/theme_service.dart';
import '../theme/colors.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  int _homeTabIndex = 0;
  int _chatFilterIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _conversationRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _startConversationRefreshTimer();
    });
  }

  @override
  void dispose() {
    _conversationRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startConversationRefreshTimer() {
    _conversationRefreshTimer?.cancel();
    _conversationRefreshTimer = Timer.periodic(const Duration(seconds: 8), (
      _,
    ) async {
      final authService = context.read<AuthService>();
      if (authService.accessToken == null || !mounted) {
        return;
      }
      await context.read<MessageService>().fetchConversations(
        authService.accessToken!,
      );
    });
  }

  Future<void> _loadData() async {
    final authService = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    final noteService = context.read<NoteService>();
    final storyService = context.read<StoryService>();

    if (authService.accessToken != null && mounted) {
      await messageService.fetchCurrentUserProfile(authService.accessToken!);
      if (mounted) {
        await messageService.fetchConversations(authService.accessToken!);
      }
      if (mounted) {
        await messageService.fetchAllUsers(authService.accessToken!);
      }
      if (mounted) {
        await noteService.fetchNotes(authService.accessToken!);
      }
      if (mounted) {
        await storyService.fetchStories(authService.accessToken!);
      }
    }
  }

  Future<void> _startConversationCall(ChatUser user, bool videoCall) async {
    final authService = context.read<AuthService>();
    final callService = context.read<CallService>();
    final messageService = context.read<MessageService>();

    if (authService.accessToken == null) return;

    try {
      await callService.startOutgoingCall(
        user,
        videoCall: videoCall,
        callerProfileImage: messageService.currentUserProfile?.profileImage,
      );
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CallScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to start call: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageService = context.watch<MessageService>();
    final storyService = context.watch<StoryService>();
    final noteService = context.watch<NoteService>();
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: _buildAppBar(context),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _homeTabIndex,
        children: [
          _buildChatsTab(
            messageService,
            storyService,
            noteService,
            authService,
          ),
          _buildStoriesTab(storyService, messageService, authService),
          const NotificationsScreen(),
          const MenuScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _homeTabIndex,
        onDestinationSelected: (index) => setState(() => _homeTabIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Stories',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu_open),
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final appBarBg =
        appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    final appBarForeground =
        appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final appBarTitleStyle = appBarTheme.titleTextStyle;

    return AppBar(
      title: Text(
        _homeTabIndex == 0
            ? 'Messenger'
            : _homeTabIndex == 1
            ? 'Stories'
            : _homeTabIndex == 2
            ? 'Notifications'
            : 'Menu',
      ),
      elevation: 0,
      backgroundColor: appBarBg,
      foregroundColor: appBarForeground,
      titleTextStyle: (appBarTitleStyle ?? TextStyle(color: appBarForeground))
          .copyWith(
            fontSize: _homeTabIndex == 0 ? 34 : 22,
            fontWeight: FontWeight.w800,
          ),
      actions: [
        Consumer<NotificationService>(
          builder: (context, notificationService, _) {
            final unreadCount = notificationService.unreadCount;
            return Stack(
              children: [
                IconButton(
                  onPressed: () => setState(() => _homeTabIndex = 2),
                  icon: Icon(Icons.notifications, color: appBarForeground),
                  tooltip: 'Notifications',
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Consumer<ThemeService>(
          builder: (context, themeService, _) {
            final isDarkMode = themeService.isDarkMode;
            return IconButton(
              onPressed: () => themeService.toggleDarkMode(),
              icon: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: appBarForeground,
              ),
              tooltip: isDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
            );
          },
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          icon: Icon(Icons.account_circle, color: appBarForeground),
          tooltip: 'My Profile',
        ),
      ],
      bottom: _homeTabIndex == 0
          ? PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildChatsTab(
    MessageService messageService,
    StoryService storyService,
    NoteService noteService,
    AuthService authService,
  ) {
    final entries = _buildAllRegisteredUserEntries(messageService);
    final groupEntries = _filteredGroups(messageService.groups);
    final currentProfile = messageService.currentUserProfile;
    final profileRowUsers = <ChatUser>[
      if (currentProfile != null) currentProfile,
      ...entries
          .map((entry) => entry.user)
          .where((user) => user.username != currentProfile?.username),
    ];
    final unreadEntries = entries
        .where((entry) => entry.user.unreadCount > 0)
        .toList();
    final unreadGroups = groupEntries
        .where((group) => group.unreadCount > 0)
        .toList();
    final unreadTotal =
        unreadEntries.fold<int>(0, (sum, item) => sum + item.user.unreadCount) +
        unreadGroups.fold<int>(0, (sum, item) => sum + item.unreadCount);
    final visibleEntries = _chatFilterIndex == 1 ? unreadEntries : entries;

    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildUserProfileStrip(profileRowUsers, messageService, authService),
          _buildChatFilters(unreadTotal),
          Container(height: 0.5, color: MessengerColors.dividerColor),
          Expanded(
            child:
                messageService.isLoading &&
                    visibleEntries.isEmpty &&
                    groupEntries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _chatFilterIndex == 2
                ? _buildGroupList(groupEntries, messageService, authService)
                : _chatFilterIndex == 1
                ? _buildUnreadList(
                    unreadEntries,
                    unreadGroups,
                    messageService,
                    authService,
                  )
                : visibleEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: MessengerColors.messengerBlue.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Registered users will appear here',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: MessengerColors.messengerBlue,
                    onRefresh: () async {
                      await messageService.fetchConversations(
                        authService.accessToken ?? '',
                      );
                      await messageService.fetchGroups(
                        authService.accessToken ?? '',
                      );
                      await messageService.fetchAllUsers(
                        authService.accessToken ?? '',
                      );
                    },
                    child: ListView.separated(
                      itemCount: visibleEntries.length,
                      separatorBuilder: (context, index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 0.5,
                        color: MessengerColors.dividerColor,
                      ),
                      itemBuilder: (context, index) {
                        return _buildUnifiedChatTile(
                          visibleEntries[index],
                          messageService,
                          authService,
                          context,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreadList(
    List<_ChatListEntry> unreadEntries,
    List<GroupChat> unreadGroups,
    MessageService messageService,
    AuthService authService,
  ) {
    if (unreadEntries.isEmpty && unreadGroups.isEmpty) {
      return Center(
        child: Text(
          'No unread messages',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      );
    }

    return ListView(
      children: [
        if (unreadEntries.isNotEmpty)
          ...unreadEntries.map(
            (entry) => _buildUnifiedChatTile(
              entry,
              messageService,
              authService,
              context,
            ),
          ),
        if (unreadEntries.isNotEmpty && unreadGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Unread Groups',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13,
              ),
            ),
          ),
        if (unreadGroups.isNotEmpty)
          ...unreadGroups.map(
            (group) => ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: MessengerColors.messengerBlue.withOpacity(
                  0.15,
                ),
                child: const Icon(Icons.groups_rounded),
              ),
              title: Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${group.members.length} members • ${group.lastMessage ?? 'No messages yet'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: group.unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        group.unreadCount > 99
                            ? '99+'
                            : group.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
              onTap: () async {
                if (authService.accessToken == null) return;
                await messageService.selectGroup(
                  group.id,
                  authService.accessToken!,
                );
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => chat_screen.ChatScreen(
                      chatUser: ChatUser(
                        username: group.id,
                        firstName: group.name,
                        lastName: '',
                        email: '',
                        profileImage: group.avatar,
                      ),
                      isGroupChat: true,
                      groupChat: group,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildChatFilters(int unreadTotal) {
    Widget chip({required int index, required String label, int badge = 0}) {
      final selected = _chatFilterIndex == index;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _chatFilterIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? MessengerColors.messengerBlue
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white24 : Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          chip(index: 0, label: 'All'),
          chip(index: 1, label: 'Unread', badge: unreadTotal),
          chip(index: 2, label: 'Groups'),
        ],
      ),
    );
  }

  Widget _buildStoriesTab(
    StoryService storyService,
    MessageService messageService,
    AuthService authService,
  ) {
    final groups = storyService.stories;
    final profile = messageService.currentUserProfile;
    final currentUsername = authService.currentUser?.username ?? '';
    final currentDisplayName =
        authService.currentUser?.fullName?.trim().isNotEmpty == true
        ? authService.currentUser!.fullName.trim()
        : (authService.currentUser?.username ?? 'You');
    final currentStoryGroup = _findUserStoryGroup(groups, currentUsername);
    final otherStories = groups
        .where((story) => story.username != currentUsername)
        .toList();

    if (storyService.isLoading && groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      color: MessengerColors.messengerBlue,
      onRefresh: () => storyService.fetchStories(authService.accessToken ?? ''),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStoryRailTile(
                label: 'You',
                avatar: _buildCurrentUserAvatar(
                  profile?.profileImage,
                  currentUsername,
                  currentDisplayName,
                ),
                hasStory: currentStoryGroup != null,
                onTap: () {
                  if (currentStoryGroup != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            StoryViewerScreen(storyGroup: currentStoryGroup),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddStoryScreen()),
                    );
                  }
                },
              ),
              for (final story in otherStories) ...[
                const SizedBox(width: 12),
                _buildStoryRailTile(
                  label: story.displayName.isNotEmpty
                      ? story.displayName.split(' ').first
                      : story.username,
                  avatar: _buildCurrentUserAvatar(
                    story.profileImage,
                    story.username,
                    story.displayName,
                  ),
                  hasStory: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StoryViewerScreen(storyGroup: story),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryRailTile({
    required String label,
    required Widget avatar,
    required bool hasStory,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasStory
                      ? MessengerColors.messengerBlue
                      : Theme.of(context).dividerColor,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).cardColor,
                ),
                child: ClipOval(child: avatar),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  StoryGroup? _findUserStoryGroup(List<StoryGroup> stories, String username) {
    if (username.isEmpty) return null;
    for (final storyGroup in stories) {
      if (storyGroup.username == username && storyGroup.stories.isNotEmpty) {
        return storyGroup;
      }
    }
    return null;
  }

  Widget _buildAddStoryCard(ChatUser? profile, AuthService authService) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddStoryScreen()));
        if (mounted && authService.accessToken != null) {
          await context.read<StoryService>().fetchStories(
            authService.accessToken!,
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2A2D34), Color(0xFF16181C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add, size: 24),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  profile == null ? 'Add story' : 'Add to story',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(StoryGroup group) {
    final latest = group.stories.isNotEmpty ? group.stories.last : null;
    final name = group.displayName.isNotEmpty
        ? group.displayName
        : group.username;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryViewerScreen(storyGroup: group),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildStoryCover(latest),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAA000000)],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  _buildStoryAvatar(group),
                  const Spacer(),
                  if (group.stories.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        group.stories.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCover(Story? story) {
    final imageData = _decodeBase64(story?.thumbnailUrl ?? story?.mediaUrl);
    if (imageData != null) {
      return Image.memory(imageData, fit: BoxFit.cover);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF515A6A), Color(0xFF2E3540)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.image, color: Colors.white54, size: 44),
    );
  }

  Widget _buildStoryAvatar(StoryGroup group) {
    final imageData = _decodeBase64(group.profileImage);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: group.hasUnviewed
              ? MessengerColors.messengerBlue
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).cardColor,
            backgroundImage: imageData != null ? MemoryImage(imageData) : null,
            child: imageData == null
                ? Text(
                    (group.displayName.isNotEmpty
                            ? group.displayName
                            : group.username)[0]
                        .toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  )
                : null,
          ),
          if (group.isOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: MessengerColors.onlineGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_ChatListEntry> _buildAllRegisteredUserEntries(
    MessageService messageService,
  ) {
    final users = _filteredUsers(messageService.allUsers);
    final conversations = _filteredConversations(messageService.conversations);
    final conversationByUsername = {
      for (final conversation in conversations)
        conversation.username: conversation,
    };

    final entries = users.map((user) {
      final conversation = conversationByUsername[user.username];
      final mergedUser = conversation == null
          ? user
          : ChatUser(
              username: user.username,
              firstName: user.firstName,
              lastName: user.lastName,
              email: user.email,
              profileImage: user.profileImage,
              bio: user.bio,
              isOnline: user.isOnline,
              lastSeen: user.lastSeen,
              lastMessage: conversation.lastMessage,
              lastMessageTime: conversation.lastMessageTime,
              unreadCount: conversation.unreadCount,
            );
      return _ChatListEntry(
        user: mergedUser,
        hasConversation: conversation != null,
      );
    }).toList();

    final existing = entries.map((e) => e.user.username).toSet();
    for (final conversation in conversations) {
      if (!existing.contains(conversation.username)) {
        entries.add(_ChatListEntry(user: conversation, hasConversation: true));
      }
    }

    entries.sort((a, b) {
      final aTime = _parseDateTime(a.user.lastMessageTime);
      final bTime = _parseDateTime(b.user.lastMessageTime);

      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
      if (aTime != null) return -1;
      if (bTime != null) return 1;

      if (a.user.isOnline != b.user.isOnline) {
        return a.user.isOnline ? -1 : 1;
      }

      return (a.user.displayName.isNotEmpty
              ? a.user.displayName
              : a.user.username)
          .toLowerCase()
          .compareTo(
            (b.user.displayName.isNotEmpty
                    ? b.user.displayName
                    : b.user.username)
                .toLowerCase(),
          );
    });

    return entries;
  }

  DateTime? _parseDateTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }

  Widget _buildUserProfileStrip(
    List<ChatUser> users,
    MessageService messageService,
    AuthService authService,
  ) {
    final currentProfile = messageService.currentUserProfile;
    final combinedUsers = <ChatUser>[
      if (currentProfile != null) currentProfile,
      ...users.where((user) => user.username != currentProfile?.username),
    ];

    if (combinedUsers.isEmpty) {
      return const SizedBox(height: 8);
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: combinedUsers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final user = combinedUsers[index];
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                if (authService.accessToken == null) return;
                await messageService.selectUser(
                  user.username,
                  authService.accessToken!,
                );
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          chat_screen.ChatScreen(chatUser: user),
                    ),
                  );
                }
              },
              child: SizedBox(
                width: 66,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildProfileAvatar(user),
                        if (user.isOnline)
                          Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: MessengerColors.onlineGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.displayName.isNotEmpty
                          ? user.displayName.split(' ').first
                          : user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStoriesStrip(
    StoryService storyService,
    MessageService messageService,
    AuthService authService,
  ) {
    final currentUsername = authService.currentUser?.username;
    final groups = storyService.stories
        .where((group) => group.username != currentUsername)
        .toList();

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            final name = group.displayName.isNotEmpty
                ? group.displayName
                : group.username;

            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoryViewerScreen(storyGroup: group),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: group.hasUnviewed
                            ? MessengerColors.messengerBlue
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).cardColor,
                      backgroundImage: _decodeBase64(group.profileImage) != null
                          ? MemoryImage(_decodeBase64(group.profileImage)!)
                          : null,
                      child: _decodeBase64(group.profileImage) == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHighlightTile(ChatUser? profile, NoteGroup? noteGroup) {
    final avatar = _buildCurrentUserAvatar(
      profile?.profileImage,
      profile?.username ?? '',
      profile?.displayName.isNotEmpty == true ? profile!.displayName : 'You',
    );

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const ProfileScreen()));
      },
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: MessengerColors.messengerGradient,
                    boxShadow: [
                      BoxShadow(
                        color: MessengerColors.messengerBlue.withOpacity(0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(child: avatar),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              profile?.displayName.isNotEmpty == true
                  ? profile!.displayName.split(' ').first
                  : 'You',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUserAvatar(
    String? profileImage,
    String username,
    String fallbackName,
  ) {
    final imageData = _decodeBase64(profileImage);
    if (imageData != null) {
      return ClipOval(child: Image.memory(imageData, fit: BoxFit.cover));
    }

    final label = fallbackName.trim().isNotEmpty
        ? fallbackName.trim()[0].toUpperCase()
        : (username.trim().isNotEmpty ? username.trim()[0].toUpperCase() : 'U');

    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: MessengerColors.messengerGradient,
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildThoughtBubble(NoteGroup? noteGroup) {
    final hasNote = noteGroup != null && noteGroup.notes.isNotEmpty;
    final noteText = hasNote ? noteGroup.notes.last.textContent.trim() : '';
    final emoji = hasNote ? _extractEmoji(noteText) : '💭';
    final preview = hasNote
        ? (noteText.isNotEmpty ? noteText : 'Tap to view note')
        : 'Drop a thought';

    return GestureDetector(
      onTap: () {
        if (hasNote) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoteViewerScreen(noteGroup: noteGroup!),
            ),
          );
          return;
        }

        Navigator.of(context)
            .push(
              MaterialPageRoute(builder: (context) => const AddNoteScreen()),
            )
            .then((_) {
              final authToken = context.read<AuthService>().accessToken;
              if (mounted && authToken != null) {
                context.read<NoteService>().fetchNotes(authToken);
              }
            });
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: MessengerColors.messengerGradient,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddStoryTile(
    AuthService authService,
    StoryService storyService,
    ChatUser? profile,
  ) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddStoryScreen()));
        if (mounted && authService.accessToken != null) {
          await storyService.fetchStories(authService.accessToken!);
        }
      },
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor,
                border: Border.all(
                  color: MessengerColors.messengerBlue.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  color: MessengerColors.messengerBlue,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile?.displayName.isNotEmpty == true
                  ? 'Create story'
                  : 'Add story',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractEmoji(String text) {
    final emojiMatch = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}]',
      unicode: true,
    ).firstMatch(text);
    return emojiMatch?.group(0) ?? '💭';
  }

  NoteGroup? _findUserNoteGroup(List<NoteGroup> notes, String username) {
    if (username.isEmpty) return null;
    for (final noteGroup in notes) {
      if (noteGroup.username == username && noteGroup.notes.isNotEmpty) {
        return noteGroup;
      }
    }
    return null;
  }

  Widget _buildUnifiedChatTile(
    _ChatListEntry entry,
    MessageService messageService,
    AuthService authService,
    BuildContext context,
  ) {
    final user = entry.user;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            _buildProfileAvatar(user),
            if (user.isOnline)
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: MessengerColors.onlineGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
          ],
        ),
        title: Text(
          user.displayName.isNotEmpty ? user.displayName : user.username,
          style: TextStyle(
            fontWeight: entry.hasConversation
                ? FontWeight.w700
                : FontWeight.w600,
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          entry.hasConversation
              ? (user.lastMessage ?? '@${user.username}')
              : '@${user.username}  •  Online now',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
        trailing: SizedBox(
          width: 110,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (entry.hasConversation && user.lastMessageTime != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _formatMessageTime(user.lastMessageTime!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A8D91),
                    ),
                  ),
                ),
              if (user.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    user.unreadCount > 99 ? '99+' : user.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.call,
                  color: MessengerColors.messengerBlue,
                ),
                onSelected: (value) =>
                    _startConversationCall(user, value == 'video'),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'audio',
                    child: Row(
                      children: [
                        Icon(Icons.call),
                        SizedBox(width: 10),
                        Text('Audio call'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'video',
                    child: Row(
                      children: [
                        Icon(Icons.videocam),
                        SizedBox(width: 10),
                        Text('Video call'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () async {
          if (authService.accessToken == null) return;
          await messageService.selectUser(
            user.username,
            authService.accessToken!,
          );
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => chat_screen.ChatScreen(chatUser: user),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildGroupList(
    List<GroupChat> groups,
    MessageService messageService,
    AuthService authService,
  ) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.groups_2_outlined,
              size: 58,
              color: Color(0xFF98A0AE),
            ),
            const SizedBox(height: 12),
            const Text(
              'No group chats yet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () =>
                  _showCreateGroupDialog(messageService, authService),
              icon: const Icon(Icons.add),
              label: const Text('Create group'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showCreateGroupDialog(messageService, authService),
              icon: const Icon(Icons.group_add),
              label: const Text('Create New Group'),
            ),
          );
        }
        final group = groups[index - 1];
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: MessengerColors.messengerBlue.withOpacity(0.15),
            child: const Icon(Icons.groups_rounded),
          ),
          title: Text(
            group.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${group.members.length} members • ${group.lastMessage ?? 'No messages yet'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: group.unreadCount > 0
              ? Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    group.unreadCount > 99
                        ? '99+'
                        : group.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
          onTap: () async {
            if (authService.accessToken == null) {
              return;
            }
            await messageService.selectGroup(
              group.id,
              authService.accessToken!,
            );
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => chat_screen.ChatScreen(
                  chatUser: ChatUser(
                    username: group.id,
                    firstName: group.name,
                    lastName: '',
                    email: '',
                    profileImage: group.avatar,
                  ),
                  isGroupChat: true,
                  groupChat: group,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<GroupChat> _filteredGroups(List<GroupChat> groups) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return groups;
    return groups
        .where(
          (group) =>
              _matchesSearch(group.name, query) ||
              group.members.any((m) => _matchesSearch(m.displayName, query)),
        )
        .toList();
  }

  Future<void> _showCreateGroupDialog(
    MessageService messageService,
    AuthService authService,
  ) async {
    if (authService.accessToken != null) {
      await messageService.fetchAllUsers(authService.accessToken!);
      await messageService.fetchConversations(authService.accessToken!);
    }

    final controller = TextEditingController();
    final selected = <String>{};
    String? avatarBase64;
    final groupUsers = _groupSelectionUsers(messageService);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Group'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Group name',
                      prefixIcon: Icon(Icons.groups),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image == null) {
                          return;
                        }
                        avatarBase64 = await StoryService.fileToBase64(image);
                        if (context.mounted) {
                          setStateDialog(() {});
                        }
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        avatarBase64 == null
                            ? 'Add group image'
                            : 'Change group image',
                      ),
                    ),
                  ),
                  if (avatarBase64 != null)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Group image selected',
                        style: TextStyle(
                          color: MessengerColors.messengerBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (groupUsers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No users available to add to group',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...groupUsers.map((user) {
                      final checked = selected.contains(user.username);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName
                              : user.username,
                        ),
                        subtitle: Text('@${user.username}'),
                        onChanged: (_) {
                          setStateDialog(() {
                            if (checked) {
                              selected.remove(user.username);
                            } else {
                              selected.add(user.username);
                            }
                          });
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (authService.accessToken == null) return;

              final groupName = controller.text.trim();
              if (groupName.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter group name')),
                  );
                }
                return;
              }

              if (selected.length < 1) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select at least 1 member')),
                  );
                }
                return;
              }
              final created = await messageService.createGroup(
                name: groupName,
                members: selected.toList(),
                avatarBase64: avatarBase64,
                accessToken: authService.accessToken!,
              );
              if (mounted) {
                if (created) {
                  setState(() {
                    _searchQuery = '';
                    _chatFilterIndex = 0;
                  });
                  await messageService.fetchConversations(
                    authService.accessToken!,
                  );
                  await messageService.fetchGroups(authService.accessToken!);
                  await messageService.fetchAllUsers(authService.accessToken!);
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      created
                          ? 'Group created successfully'
                          : (messageService.error ?? 'Failed to create group'),
                    ),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  List<ChatUser> _filteredConversations(List<ChatUser> conversations) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return conversations;

    return conversations.where((user) {
      return _matchesSearch(user.username, query) ||
          _matchesSearch(user.displayName, query) ||
          _matchesSearch('${user.firstName} ${user.lastName}', query) ||
          _matchesSearch(user.lastMessage ?? '', query) ||
          _matchesSearch(user.email, query);
    }).toList();
  }

  List<ChatUser> _filteredUsers(List<ChatUser> users) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return users;

    return users.where((user) {
      return _matchesSearch(user.username, query) ||
          _matchesSearch(user.displayName, query) ||
          _matchesSearch('${user.firstName} ${user.lastName}', query) ||
          _matchesSearch(user.email, query) ||
          _matchesSearch(user.bio, query);
    }).toList();
  }

  List<ChatUser> _groupSelectionUsers(MessageService messageService) {
    final merged = <String, ChatUser>{};

    for (final user in messageService.allUsers) {
      merged[user.username] = user;
    }

    for (final conversation in messageService.conversations) {
      merged.putIfAbsent(conversation.username, () => conversation);
    }

    final currentUsername = messageService.currentUserProfile?.username;
    if (currentUsername != null) {
      merged.remove(currentUsername);
    }

    final users = merged.values.toList();
    users.sort((a, b) {
      final aLabel = a.displayName.isNotEmpty ? a.displayName : a.username;
      final bLabel = b.displayName.isNotEmpty ? b.displayName : b.username;
      return aLabel.toLowerCase().compareTo(bLabel.toLowerCase());
    });

    return users;
  }

  bool _matchesSearch(String value, String query) {
    return value.toLowerCase().contains(query);
  }

  Widget _buildProfileAvatar(ChatUser user) {
    final imageData = _decodeBase64(user.profileImage);
    if (imageData != null) {
      return CircleAvatar(backgroundImage: MemoryImage(imageData), radius: 24);
    }
    return _buildInitialsAvatar(user);
  }

  Widget _buildInitialsAvatar(ChatUser user) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: MessengerColors.messengerGradient,
      ),
      child: Center(
        child: Text(
          user.initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Uint8List? _decodeBase64(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final cleaned = value.contains(',') ? value.split(',').last : value;
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  String _formatMessageTime(String timestamp) {
    try {
      final messageTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(messageTime);

      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else {
        return '${messageTime.month}/${messageTime.day}';
      }
    } catch (_) {
      return '';
    }
  }
}

class _ChatListEntry {
  final ChatUser user;
  final bool hasConversation;

  const _ChatListEntry({required this.user, required this.hasConversation});
}
