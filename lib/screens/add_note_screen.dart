import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/note_service.dart';
import '../theme/colors.dart';

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isUploading = false;
  XFile? _pickedMedia;
  String? _pickedType;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(String type) async {
    final picker = ImagePicker();
    final media = type == 'image'
        ? await picker.pickImage(source: ImageSource.gallery)
        : await picker.pickVideo(source: ImageSource.gallery);
    if (media != null && mounted) {
      setState(() {
        _pickedMedia = media;
        _pickedType = type;
      });
    }
  }

  Future<void> _submitNote() async {
    final authService = context.read<AuthService>();
    final noteService = context.read<NoteService>();

    if (authService.accessToken == null) return;

    final text = _textController.text.trim();
    final hasMedia = _pickedMedia != null && _pickedType != null;
    if (text.isEmpty && !hasMedia) return;

    setState(() => _isUploading = true);

    String? mediaBase64;
    if (hasMedia) {
      mediaBase64 = await NoteService.fileToBase64(_pickedMedia!);
    }

    final success = await noteService.uploadNote(
      accessToken: authService.accessToken!,
      noteType: hasMedia ? _pickedType! : 'text',
      textContent: text,
      mediaBase64: mediaBase64,
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(noteService.error ?? 'Failed to post note')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: MessengerColors.messengerGradient,
          ),
        ),
        title: const Text(
          'New Note',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'Write a note...'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : () => _pickMedia('image'),
                  icon: const Icon(Icons.image),
                  label: const Text('Photo'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : () => _pickMedia('video'),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_pickedMedia != null)
              Row(
                children: [
                  Icon(
                    _pickedType == 'video' ? Icons.videocam : Icons.image,
                    color: MessengerColors.messengerBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pickedMedia!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MessengerColors.messengerBlue,
                  foregroundColor: Colors.white,
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
