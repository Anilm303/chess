import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/story_model.dart';
import '../models/note_model.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/note_service.dart';
import '../services/story_service.dart';
import '../services/call_service.dart';
import 'story_viewer_screen.dart';
import 'add_story_screen.dart';
import 'note_viewer_screen.dart';
import 'add_note_screen.dart';

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
            authService.currentUser?.fullName?.trim().isNotEmpty == true
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
                          builder: (context) =>
                              StoryViewerScreen(storyGroup: userStoryGroup),
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
                            builder: (context) =>
                                StoryViewerScreen(storyGroup: story),
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
                          hintText: 'Write a short status note...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MessengerColors.messengerBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Post Note'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                Navigator.of(sheetContext).pop();
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddStoryScreen(),
                                      ),
                                    )
                                    .then((_) => _loadStories());
                              },
                        child: const Text('Add Story instead'),
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

    textController.dispose();
  }

  Widget _buildCurrentUserAvatar(
    String? profileImage,
    String username,
    String fallbackName,
  ) {
    if (profileImage != null && profileImage.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(base64Decode(profileImage), fit: BoxFit.cover),
        );
      } catch (_) {}
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
}

class _HighlightCircle extends StatelessWidget {
  final String label;
  final Widget avatar;
  final bool hasContent;
  final bool showAddButton;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;

  const _HighlightCircle({
    required this.label,
    required this.avatar,
    required this.hasContent,
    this.showAddButton = false,
    required this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasContent
                      ? MessengerColors.messengerGradient
                      : null,
                  color: hasContent ? null : Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: hasContent
                          ? MessengerColors.messengerBlue.withOpacity(0.22)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(child: avatar),
                ),
              ),

              if (showAddButton)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MessengerColors.messengerBlue,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAddTap,
                        customBorder: const CircleBorder(),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
