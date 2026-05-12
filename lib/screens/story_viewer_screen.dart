import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../models/story_model.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../services/message_service.dart';
import '../services/api_service.dart';
import 'story_analytics_screen.dart';

const _storyQuickReactions = ['❤️', '😂', '😮', '😢', '🔥', '👏'];

class StoryViewerScreen extends StatefulWidget {
  final StoryGroup storyGroup;

  const StoryViewerScreen({super.key, required this.storyGroup});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  late List<Story> _stories;

  // Reply / reaction state
  final TextEditingController _replyController = TextEditingController();
  bool _showReplyBox = false;
  bool _showEmojiPicker = false;
  bool _isSending = false;
  String? _chosenReaction; // emoji chosen for current story

  @override
  void initState() {
    super.initState();
    _stories = widget.storyGroup.stories;
    _pageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _markStoryViewed());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _markStoryViewed() async {
    final authService = context.read<AuthService>();
    final storyService = context.read<StoryService>();
    if (authService.accessToken != null) {
      final success = await storyService.markStoryViewed(
        _stories[_currentIndex].id,
        authService.accessToken!,
      );
      if (success) {
        // Refresh stories so UI reflects viewed state (strip badges)
        await storyService.fetchStories(authService.accessToken!);
      }
    }
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleReplyBox() {
    setState(() {
      _showReplyBox = !_showReplyBox;
      _showEmojiPicker = false;
      if (!_showReplyBox) _replyController.clear();
    });
  }

  Future<void> _sendReactionAsMessage(String emoji) async {
    final authService = context.read<AuthService>();
    final storyService = context.read<StoryService>();

    if (authService.accessToken == null) return;

    setState(() => _isSending = true);
    final success = await storyService.reactToStory(
      _stories[_currentIndex].id,
      emoji,
      authService.accessToken!,
    );

    setState(() {
      if (success) {
        _chosenReaction = emoji;
        // Optimistically update the current story's reactions
        final username = authService.currentUser?.username ?? '';
        if (username.isNotEmpty) {
          final reactions = Map<String, String>.from(
            _stories[_currentIndex].reactions,
          );
          if (reactions[username] == emoji) {
            reactions.remove(username); // toggle off
          } else {
            reactions[username] = emoji; // toggle on
          }
          // We can't directly modify the final Story object easily here without rebuilding,
          // but fetchStories will update it.
        }
      }
      _isSending = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reaction sent!'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final authService = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    if (authService.accessToken == null) return;

    setState(() => _isSending = true);
    final success = await messageService.sendMessage(
      widget.storyGroup.username,
      text,
      authService.accessToken!,
    );
    setState(() => _isSending = false);

    if (success && mounted) {
      _replyController.clear();
      setState(() {
        _showReplyBox = false;
        _showEmojiPicker = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reply sent to ${widget.storyGroup.displayName}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner =
        widget.storyGroup.username ==
        context.read<AuthService>().currentUser?.username;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Full-screen story viewer ───────────────────────────────
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _chosenReaction = null;
                  _showReplyBox = false;
                  _showEmojiPicker = false;
                });
                _markStoryViewed();
              },
              itemCount: _stories.length,
              itemBuilder: (context, index) {
                final story = _stories[index];
                return _buildStoryView(story);
              },
            ),
          ),

          // ── Top gradient + header ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // User info
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: _buildUserAvatar(),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.storyGroup.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _getTimeAgo(_stories[_currentIndex].timestamp),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Story counter pill
                        if (_stories.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_currentIndex + 1}/${_stories.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Analytics button (only for story owner)
                        if (isOwner)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StoryAnalyticsScreen(
                                    story: _stories[_currentIndex],
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.white.withOpacity(0.9),
                                size: 24,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Left/Right tap areas for navigation ───────────────────
          Positioned(
            left: 0,
            top: 80,
            bottom: 160,
            width: MediaQuery.of(context).size.width * 0.3,
            child: GestureDetector(
              onTap: _previousStory,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            right: 0,
            top: 80,
            bottom: 160,
            width: MediaQuery.of(context).size.width * 0.3,
            child: GestureDetector(
              onTap: _nextStory,
              behavior: HitTestBehavior.opaque,
            ),
          ),

          // ── Bottom area: reactions + reply ────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji picker (above reply box)
                if (_showEmojiPicker)
                  SizedBox(
                    height: 260,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _replyController.text += emoji.emoji;
                      },
                      config: Config(
                        emojiViewConfig: EmojiViewConfig(
                          backgroundColor: Colors.grey[900]!,
                          columns: 8,
                          emojiSizeMax: 26,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          indicatorColor: MessengerColors.messengerBlue,
                          iconColorSelected: MessengerColors.messengerBlue,
                          backgroundColor: Colors.grey[900]!,
                          iconColor: Colors.white54,
                        ),
                        bottomActionBarConfig: const BottomActionBarConfig(
                          enabled: false,
                        ),
                        searchViewConfig: SearchViewConfig(
                          backgroundColor: Colors.grey[900]!,
                        ),
                      ),
                    ),
                  ),

                // Bottom gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // View and reaction indicators (Only for owner)
                      if (isOwner &&
                          (_stories[_currentIndex].viewCount > 0 ||
                              _stories[_currentIndex].reactionCount > 0))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              if (_stories[_currentIndex].viewCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        color: Colors.white.withOpacity(0.8),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_stories[_currentIndex].viewCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_stories[_currentIndex].reactionCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.emoji_emotions,
                                        color: Colors.white.withOpacity(0.8),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_stories[_currentIndex].reactionCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Messenger style story reactions summary bubble (Only for owner)
                      if (isOwner &&
                          _stories[_currentIndex].reactions.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => _showReactionsDialog(
                              context,
                              _stories[_currentIndex],
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _stories[_currentIndex].reactions.values
                                        .take(3)
                                        .join(''),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_stories[_currentIndex].reactions.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Quick reaction row
                      if (!_showReplyBox)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ..._storyQuickReactions.map((emoji) {
                              final isChosen = _chosenReaction == emoji;
                              return GestureDetector(
                                onTap: () => _sendReactionAsMessage(emoji),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isChosen
                                        ? Colors.white.withOpacity(0.25)
                                        : Colors.white.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                    border: isChosen
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    emoji,
                                    style: TextStyle(
                                      fontSize: isChosen ? 28 : 24,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),

                      const SizedBox(height: 8),

                      // Reply input row
                      Row(
                        children: [
                          if (_showReplyBox) ...[
                            // Emoji toggle in reply box
                            GestureDetector(
                              onTap: () => setState(
                                () => _showEmojiPicker = !_showEmojiPicker,
                              ),
                              child: Icon(
                                _showEmojiPicker
                                    ? Icons.keyboard
                                    : Icons.emoji_emotions_outlined,
                                color: Colors.white70,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white38,
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: _replyController,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Reply to story…',
                                    hintStyle: TextStyle(color: Colors.white54),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onTap: () =>
                                      setState(() => _showEmojiPicker = false),
                                  onSubmitted: (_) => _sendReply(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _isSending ? null : _sendReply,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: MessengerColors.messengerGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: _isSending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                              ),
                            ),
                          ] else ...[
                            // "Reply" button placeholder
                            Expanded(
                              child: GestureDetector(
                                onTap: _toggleReplyBox,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white30,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'Reply to story…',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Cancel reply
                          if (_showReplyBox) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _toggleReplyBox,
                              child: const Icon(
                                Icons.close,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReactionsDialog(BuildContext context, Story story) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Reactions (${story.reactions.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: story.reactions.length,
                itemBuilder: (context, index) {
                  final entry = story.reactions.entries.elementAt(index);
                  final storyService = context.read<StoryService>();
                  final reactorGroup = storyService.stories
                      .where((g) => g.username == entry.key)
                      .toList();
                  final hasStory = reactorGroup.isNotEmpty;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: hasStory
                        ? () {
                            Navigator.pop(context); // close sheet
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StoryViewerScreen(
                                  storyGroup: reactorGroup.first,
                                ),
                              ),
                            );
                          }
                        : null,
                    leading: CircleAvatar(
                      backgroundColor: MessengerColors.messengerBlue,
                      child: Text(
                        _initialForName(entry.key),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: hasStory
                        ? const Text(
                            'Tap to view their story',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          )
                        : null,
                    trailing: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 24),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryView(Story story) {
    if (story.mediaType == 'image') {
      return _buildImageView(story);
    } else {
      return _buildVideoPlaceholder(story);
    }
  }

  Widget _buildImageView(Story story) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Image.network(
          '${ApiService.baseUrl.replaceAll('/api', '')}${story.mediaUrl}',
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.error, color: Colors.white, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(Story story) {
    return _VideoPlayerWidget(
      url: '${ApiService.baseUrl.replaceAll('/api', '')}${story.mediaUrl}',
    );
  }

  Widget _buildUserAvatar() {
    if (widget.storyGroup.profileImage != null &&
        widget.storyGroup.profileImage!.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(widget.storyGroup.profileImage!),
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        return _buildInitialsAvatar();
      }
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final names = _safeNameParts;
    final initials = names.length >= 2
        ? '${names[0][0].toUpperCase()}${names[1][0].toUpperCase()}'
        : names.isNotEmpty && names.first.isNotEmpty
        ? names.first[0].toUpperCase()
        : 'S';

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: MessengerColors.messengerGradient,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _initialForName(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      return trimmed[0].toUpperCase();
    }
    return 'U';
  }

  List<String> get _safeNameParts {
    final displayName = widget.storyGroup.displayName.trim();
    if (displayName.isNotEmpty) {
      return displayName
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
    }
    final username = widget.storyGroup.username.trim();
    if (username.isNotEmpty) {
      return [username];
    }
    return const [];
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return 'Yesterday';
  }
}

// ── Video Player Widget ────────────────────────────────────────────────────────
class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  const _VideoPlayerWidget({Key? key, required this.url}) : super(key: key);

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
          _controller.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
