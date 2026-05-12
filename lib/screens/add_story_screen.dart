import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';

class AddStoryScreen extends StatefulWidget {
  const AddStoryScreen({super.key});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  XFile? _selectedMedia;
  Uint8List? _webMediaBytes;
  String _mediaType = 'image'; // 'image' or 'video'
  bool _isUploading = false;
  VideoPlayerController? _videoController;

  Future<void> _pickMedia(String type) async {
    final storyService = context.read<StoryService>();
    final media = await storyService.pickMedia(type);

    if (media != null) {
      Uint8List? bytes;
      if (kIsWeb && type == 'image') {
        bytes = await media.readAsBytes();
      }
      setState(() {
        _selectedMedia = media;
        _webMediaBytes = bytes;
        _mediaType = type;
      });
      // If picked a video on a non-web platform, initialize video controller for preview
      if (!kIsWeb && type == 'video') {
        try {
          await (_videoController?.dispose() ?? Future.value());
        } catch (_) {}
        try {
          _videoController = VideoPlayerController.file(File(media.path));
          await _videoController!.initialize();
          _videoController!.setLooping(true);
          _videoController!.play();
          setState(() {});
        } catch (_) {
          // ignore preview errors
        }
      }
    }
  }

  Future<void> _uploadStory() async {
    if (_selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image or video')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final authService = context.read<AuthService>();
      final storyService = context.read<StoryService>();

      if (authService.accessToken == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not authenticated')));
        return;
      }

      bool success = false;

      // For videos prefer multipart upload to avoid large base64 payloads
      if (_mediaType == 'video' && _selectedMedia != null) {
        print('📤 Uploading video story: ${_selectedMedia!.name}');
        success = await storyService.uploadStoryFile(
          _selectedMedia!,
          _mediaType,
          authService.accessToken!,
        );
      } else {
        // Convert file to base64
        print('📤 Uploading image story: ${_selectedMedia!.name}');
        final mediaBase64 = await StoryService.fileToBase64(_selectedMedia!);

        if (mediaBase64 == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process media')),
          );
          return;
        }

        // Upload story (JSON base64 fallback)
        success = await storyService.uploadStory(
          mediaBase64,
          _mediaType,
          authService.accessToken!,
        );
      }

      if (mounted) {
        if (success) {
          print('✅ Story uploaded successfully!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Story uploaded successfully! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        } else {
          print('❌ Story upload failed: ${storyService.error}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(storyService.error ?? 'Failed to upload story'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MessengerColors.chatBackground,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: MessengerColors.messengerGradient,
          ),
        ),
        title: const Text(
          'Add Story',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),

            // Media preview
            if (_selectedMedia != null)
              _buildMediaPreview()
            else
              _buildEmptyState(),

            const SizedBox(height: 32),

            // Pick buttons
            if (_selectedMedia == null) ...[
              _buildPickButton(
                icon: Icons.image,
                label: 'Pick Image',
                onTap: () => _pickMedia('image'),
              ),
              const SizedBox(height: 16),
              _buildPickButton(
                icon: Icons.videocam,
                label: 'Pick Video',
                onTap: () => _pickMedia('video'),
              ),
            ] else ...[
              // Upload button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: MessengerColors.messengerGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: MessengerColors.messengerBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isUploading ? null : _uploadStory,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _isUploading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.cloud_upload, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Share Story',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Change button
              OutlinedButton.icon(
                onPressed: _isUploading ? null : () => _changeMedia(),
                icon: const Icon(Icons.edit),
                label: const Text('Change'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MessengerColors.messengerBlue,
                  side: const BorderSide(color: MessengerColors.messengerBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MessengerColors.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.image, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No media selected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose an image or video to share',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A8D91)),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_mediaType == 'image')
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? (_webMediaBytes != null
                        ? Image.memory(
                            _webMediaBytes!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          )
                        : const Center(child: CircularProgressIndicator()))
                  : Image.file(
                      File(_selectedMedia!.path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
            )
          else
            // For non-web platforms show playable preview; on web show placeholder
            (!kIsWeb &&
                    _videoController != null &&
                    _videoController!.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.videocam, size: 64, color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Video Selected',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
        ],
      ),
    );
  }

  Widget _buildPickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MessengerColors.messengerBlue, width: 2),
        boxShadow: [
          BoxShadow(
            color: MessengerColors.messengerBlue.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: MessengerColors.messengerBlue, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: MessengerColors.messengerBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _changeMedia() {
    setState(() {
      _selectedMedia = null;
      try {
        _videoController?.dispose();
      } catch (_) {}
      _videoController = null;
    });
  }

  @override
  void dispose() {
    try {
      _videoController?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
