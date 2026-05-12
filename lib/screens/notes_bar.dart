import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../services/auth_service.dart';
import '../services/note_service.dart';
import '../theme/colors.dart';
import 'note_viewer_screen.dart';

class NotesBar extends StatefulWidget {
  const NotesBar({super.key});

  @override
  State<NotesBar> createState() => _NotesBarState();
}

class _NotesBarState extends State<NotesBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotes());
  }

  Future<void> _loadNotes() async {
    final authService = context.read<AuthService>();
    final noteService = context.read<NoteService>();
    if (authService.accessToken != null && mounted) {
      await noteService.fetchNotes(authService.accessToken!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteService>(
      builder: (context, noteService, _) {
        final currentUsername =
            context.watch<AuthService>().currentUser?.username ?? '';
        final noteGroups = noteService.notes
            .where((group) => group.username != currentUsername)
            .toList();

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: SizedBox(
            height: 92,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final noteGroup in noteGroups)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _NoteAvatar(noteGroup: noteGroup),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoteAvatar extends StatelessWidget {
  final NoteGroup noteGroup;

  const _NoteAvatar({required this.noteGroup});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NoteViewerScreen(noteGroup: noteGroup),
          ),
        );
      },
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: noteGroup.hasUnviewed
                      ? MessengerColors.messengerGradient
                      : null,
                  color: noteGroup.hasUnviewed ? null : Colors.grey[200],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: _buildAvatar(),
                ),
              ),
              if (noteGroup.isOnline)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MessengerColors.onlineGreen,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 54,
            child: Text(
              _label,
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

  Widget _buildAvatar() {
    if (noteGroup.profileImage != null && noteGroup.profileImage!.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(noteGroup.profileImage!),
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return _buildInitials();
      }
    }
    return _buildInitials();
  }

  Widget _buildInitials() {
    final displayName = noteGroup.displayName.trim();
    final username = noteGroup.username.trim();
    final name = displayName.isNotEmpty ? displayName : username;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'N';

    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: MessengerColors.messengerGradient,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String get _label {
    final displayName = noteGroup.displayName.trim();
    if (displayName.isNotEmpty) {
      return displayName.split(RegExp(r'\s+')).first;
    }
    if (noteGroup.username.trim().isNotEmpty) {
      return noteGroup.username.trim();
    }
    return 'Note';
  }
}
