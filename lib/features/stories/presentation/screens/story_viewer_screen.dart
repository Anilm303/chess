import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import '../../../../models/story_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/story_service.dart';
import '../../../chat/data/services/message_service.dart';
import '../../../../services/api_service.dart';

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

  final TextEditingController _replyController = TextEditingController();
  bool _showReplyBox = false;
  bool _showEmojiPicker = false;
  bool _isSending = false;
  String? _chosenReaction;
  bool _isMuted = false;

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
        final currentUsername = authService.currentUser?.username ?? '';
        final currentStory = _stories[_currentIndex];
        final alreadyViewed = currentStory.viewers.any(
          (viewer) => viewer['username'] == currentUsername,
        );
        if (currentUsername.isNotEmpty && !alreadyViewed) {
          setState(() {
            currentStory.viewers.add({
              'username': currentUsername,
              'timestamp': DateTime.now().toIso8601String(),
            });
          });
        }
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

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  Future<void> _deleteCurrentStory() async {
    final authService = context.read<AuthService>();
    final storyService = context.read<StoryService>();
    final story = _stories[_currentIndex];

    if (authService.accessToken == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete story?'),
        content: const Text('This story will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);
    final success = await storyService.deleteStory(
      story.id,
      authService.accessToken!,
    );
    setState(() => _isSending = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story deleted')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete story')),
      );
    }
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
        final username = authService.currentUser?.username ?? '';
        if (username.isNotEmpty) {
          final reactions = Map<String, String>.from(
            _stories[_currentIndex].reactions,
          );
          if (reactions[username] == emoji) {
            reactions.remove(username);
          } else {
            reactions[username] = emoji;
          }
          setState(() {
            _stories[_currentIndex].reactions
              ..clear()
              ..addAll(reactions);
          });
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
    final isOwner = widget.storyGroup.username ==
        context.read<AuthService>().currentUser?.username;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white24,
                                child: _buildUserAvatar(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.storyGroup.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _stories.isNotEmpty
                                          ? _getTimeAgo(
                                              _stories[_currentIndex].timestamp)
                                          : '',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isOwner) ...[
                                const SizedBox(height: 8),
                                if (_stories.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => _showStoryInsights(context),
                                    child: _MetricChip(
                                      icon: Icons.visibility_outlined,
                                      label:
                                          '${_stories[_currentIndex].viewCount}',
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleMute,
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                          ),
                        ),
                        if (isOwner)
                          IconButton(
                            onPressed: _isSending ? null : _deleteCurrentStory,
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: List.generate(
                        _stories.length,
                        (index) => Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              right: index == _stories.length - 1 ? 0 : 4,
                            ),
                            height: 3,
                            decoration: BoxDecoration(
                              color: index <= _currentIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isOwner && _showReplyBox) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _replyController,
                                      style: const TextStyle(fontSize: 15),
                                      decoration: const InputDecoration(
                                        hintText: 'Send a message',
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _isSending ? null : _sendReply,
                                    icon: _isSending
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _toggleReplyBox,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!isOwner)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _toggleReplyBox,
                              child: Container(
                                height: 44,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.message_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Send message',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          for (final r in ['❤️', '😂', '😮'])
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () => _sendReactionAsMessage(r),
                                child: Text(
                                  r,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    final s = _stories[_currentIndex];
    return s.profileImage != null
        ? Image.memory(base64Decode(s.profileImage!), fit: BoxFit.cover)
        : Text(s.username.isNotEmpty ? s.username[0].toUpperCase() : 'U');
  }

  String _getTimeAgo(dynamic timestamp) {
    DateTime dt;
    if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _showStoryInsights(BuildContext context) {
    final story = _stories[_currentIndex];
    final viewers = story.viewers;
    final reactions = story.reactionDetails;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF7F8FA),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Story details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _InsightsSection(
                  title: 'Reactions',
                  emptyText: 'No reactions yet',
                  children: reactions.entries
                      .map(
                        (entry) => _InsightRow(
                          icon: _emojiIcon(
                              entry.value['emoji']?.toString() ?? '🙂'),
                          title: entry.key,
                          subtitle: entry.value['timestamp']?.toString(),
                          trailing: entry.value['emoji']?.toString() ?? '',
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                _InsightsSection(
                  title: 'Viewed by',
                  emptyText: 'No views yet',
                  children: viewers
                      .map(
                        (viewer) => _InsightRow(
                          icon: Icons.visibility_outlined,
                          title: viewer['username']?.toString() ?? 'unknown',
                          subtitle: viewer['timestamp']?.toString(),
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _emojiIcon(String emoji) {
    switch (emoji) {
      case '❤️':
        return Icons.favorite;
      case '😂':
        return Icons.emoji_emotions;
      case '😮':
        return Icons.sentiment_very_satisfied;
      case '😢':
        return Icons.sentiment_dissatisfied;
      case '🔥':
        return Icons.local_fire_department;
      case '👏':
        return Icons.back_hand;
      default:
        return Icons.emoji_emotions_outlined;
    }
  }

  Widget _buildStoryView(Story story) {
    final mediaUrl =
        '${ApiService.baseUrl.replaceAll('/api', '')}${story.mediaUrl}';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (story.mediaType == 'image')
          Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Image story failed to load',
                  style: TextStyle(color: Colors.black54),
                ),
              );
            },
          )
        else
          _StoryVideoPlayer(mediaUrl: mediaUrl, muted: _isMuted),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.22),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.45),
              ],
              stops: const [0.0, 0.18, 0.75, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<Widget> children;

  const _InsightsSection({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              emptyText,
              style: const TextStyle(color: Colors.black54),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  const _InsightRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF1F4F8),
            child: Icon(icon, size: 18, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryVideoPlayer extends StatefulWidget {
  final String mediaUrl;
  final bool muted;

  const _StoryVideoPlayer({required this.mediaUrl, required this.muted});

  @override
  State<_StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<_StoryVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant _StoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _disposeController();
      _loadVideo();
    } else if (oldWidget.muted != widget.muted && _controller != null) {
      _controller!.setVolume(widget.muted ? 0.0 : 1.0);
    }
  }

  void _loadVideo() {
    final uri = Uri.tryParse(widget.mediaUrl);
    if (uri == null) {
      return;
    }

    _controller = VideoPlayerController.networkUrl(uri);
    _initializeFuture = _controller!.initialize().then((_) {
      if (!mounted) return;
      _controller!
        ..setLooping(true)
        ..setVolume(widget.muted ? 0.0 : 1.0)
        ..play();
      setState(() {});
    });
    setState(() {});
  }

  void _disposeController() {
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _initializeFuture = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _initializeFuture == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !_controller!.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        );
      },
    );
  }
}
