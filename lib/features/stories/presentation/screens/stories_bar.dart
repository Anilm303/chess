import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../../models/story_model.dart';
import '../../../../models/note_model.dart';
import '../../../../theme/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../chat/data/services/message_service.dart';
import '../../../../services/note_service.dart';
import '../../../../services/story_service.dart';
import '../../../calls/data/services/call_service.dart';
import '../../../../features/stories/presentation/screens/story_viewer_screen.dart';
import '../../../../features/stories/presentation/screens/add_story_screen.dart';

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStories();
      _loadNotes();
      _setupSocketListeners();
    });
  }

  void _setupSocketListeners() {
    final callService = context.read<CallService>();
    if (callService.socket != null) {
      callService.socket!.on('new_story', (_) => _loadStories());
      callService.socket!.on('new_note', (_) => _loadNotes());
    }
  }

  Future<void> _loadStories() async {
    final authService = context.read<AuthService>();
    final storyService = context.read<StoryService>();
    if (authService.accessToken != null && mounted) {
      await storyService.fetchStories(authService.accessToken!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<StoryService, MessageService>(
      builder: (context, storyService, messageService, _) {
        final authService = context.watch<AuthService>();
        final currentUsername = authService.currentUser?.username ?? '';
        final currentDisplayName =
            authService.currentUser?.fullName.trim().isNotEmpty == true
                ? authService.currentUser!.fullName.trim()
                : (authService.currentUser?.username ?? 'You');
        final currentUserProfile = messageService.currentUserProfile;
        final userStoryGroup = _findUserStoryGroup(
          storyService.stories,
          currentUsername,
        );

        final otherStories = storyService.stories
            .where((g) => g.username != currentUsername)
            .toList();

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HighlightCircle(
                  label: 'Your Story',
                  avatar: _buildCurrentUserAvatar(
                    currentUserProfile?.profileImage,
                    currentUsername,
                    currentDisplayName,
                  ),
                  hasContent: userStoryGroup != null,
                  showAddButton: false,
                  onTap: () {
                    if (userStoryGroup != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StoryViewerScreen(
                            storyGroup: userStoryGroup,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddStoryScreen(),
                        ),
                      );
                    }
                  },
                ),
                for (final story in otherStories)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _HighlightCircle(
                      label: story.displayName.isNotEmpty
                          ? story.displayName.split(' ').first
                          : story.username,
                      avatar: _buildCurrentUserAvatar(
                        story.profileImage,
                        story.username,
                        story.displayName,
                      ),
                      hasContent: true,
                      showAddButton: false,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => StoryViewerScreen(
                              storyGroup: story,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

  NoteGroup? _findUserNoteGroup(List<NoteGroup> notes, String username) {
    if (username.isEmpty) return null;
    for (final noteGroup in notes) {
      if (noteGroup.username == username && noteGroup.notes.isNotEmpty) {
        return noteGroup;
      }
    }
    return null;
  }

  Future<void> _loadNotes() async {
    final authService = context.read<AuthService>();
    final noteService = context.read<NoteService>();
    if (authService.accessToken != null && mounted) {
      await noteService.fetchNotes(authService.accessToken!);
    }
  }

  Future<void> _openQuickNoteSheet(
    BuildContext context, {
    required bool hasNote,
  }) async {
    final textController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              final authService = context.read<AuthService>();
              final noteService = context.read<NoteService>();
              final text = textController.text.trim();

              if (authService.accessToken == null || text.isEmpty) {
                return;
              }

              setSheetState(() => isSubmitting = true);
              final success = await noteService.uploadNote(
                accessToken: authService.accessToken!,
                noteType: 'text',
                textContent: text,
              );

              if (!sheetContext.mounted) return;
              setSheetState(() => isSubmitting = false);

              if (success) {
                Navigator.of(sheetContext).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(noteService.error ?? 'Failed to post note'),
                  ),
                );
              }
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        hasNote ? 'Update Note' : 'Quick Note',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: textController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Write something...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: isSubmitting ? null : submit,
                            child: isSubmitting
                                ? const CircularProgressIndicator()
                                : const Text('Post'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentUserAvatar(
    String? profileImage,
    String username,
    String displayName,
  ) {
    if (profileImage != null && profileImage.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(profileImage),
            fit: BoxFit.cover,
            width: 52,
            height: 52,
          ),
        );
      } catch (_) {}
    }

    final name = displayName.trim().isNotEmpty ? displayName : username;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: MessengerColors.messengerBlue.withAlpha(31),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HighlightCircle extends StatelessWidget {
  final String label;
  final Widget avatar;
  final bool hasContent;
  final bool showAddButton;
  final VoidCallback onTap;

  const _HighlightCircle({
    required this.label,
    required this.avatar,
    required this.hasContent,
    required this.showAddButton,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      hasContent ? MessengerColors.messengerGradient : null,
                  color: hasContent ? null : Colors.grey[300],
                ),
                child: ClipOval(child: avatar),
              ),
              if (showAddButton)
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: MessengerColors.messengerBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 62,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
