import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../services/auth_service.dart';
import '../services/note_service.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import 'media_viewer_screen.dart';

class NoteViewerScreen extends StatefulWidget {
  final NoteGroup noteGroup;

  const NoteViewerScreen({super.key, required this.noteGroup});

  @override
  State<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  late List<Note> _notes;

  @override
  void initState() {
    super.initState();
    _notes = widget.noteGroup.notes;
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markViewed());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markViewed() async {
    final authService = context.read<AuthService>();
    final noteService = context.read<NoteService>();
    if (authService.accessToken != null && _notes.isNotEmpty) {
      await noteService.markNoteViewed(
        _notes[_currentIndex].id,
        authService.accessToken!,
      );
    }
  }

  void _nextNote() {
    if (_currentIndex < _notes.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousNote() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _markViewed();
              },
              itemCount: _notes.length,
              itemBuilder: (context, index) => _buildNoteView(_notes[index]),
            ),
          ),
          Positioned(
            left: 0,
            top: 80,
            bottom: 120,
            width: MediaQuery.of(context).size.width * 0.3,
            child: GestureDetector(
              onTap: _previousNote,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            right: 0,
            top: 80,
            bottom: 120,
            width: MediaQuery.of(context).size.width * 0.3,
            child: GestureDetector(
              onTap: _nextNote,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: MessengerColors.messengerBlue,
                      child: Text(
                        widget.noteGroup.displayName.trim().isNotEmpty
                            ? widget.noteGroup.displayName
                                  .trim()[0]
                                  .toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.noteGroup.displayName.isNotEmpty
                                ? widget.noteGroup.displayName
                                : widget.noteGroup.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _formatTime(_notes[_currentIndex].timestamp),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteView(Note note) {
    final fullUrl = note.mediaUrl == null
        ? null
        : '${ApiService.baseUrl.replaceAll('/api', '')}${note.mediaUrl}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (note.mediaType == 'text')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  note.textContent,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, height: 1.4),
                ),
              )
            else if (note.mediaType == 'image' && fullUrl != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MediaViewerScreen(
                      mediaUrl: note.mediaUrl!,
                      mediaType: 'image',
                      title: 'Note Photo',
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(fullUrl, fit: BoxFit.contain),
                ),
              )
            else if (note.mediaType == 'video' && fullUrl != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MediaViewerScreen(
                      mediaUrl: note.mediaUrl!,
                      mediaType: 'video',
                      title: 'Note Video',
                    ),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  height: 320,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: NetworkImage(
                        '${ApiService.baseUrl.replaceAll('/api', '')}${note.thumbnailUrl ?? note.mediaUrl}',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
              ),
            if (note.textContent.isNotEmpty && note.mediaType != 'text') ...[
              const SizedBox(height: 16),
              Text(
                note.textContent,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
