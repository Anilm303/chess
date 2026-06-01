import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../services/api_service.dart';
import '../../../../theme/colors.dart';

class MediaViewerScreen extends StatefulWidget {
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? title;

  const MediaViewerScreen({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.title,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showControls = true;

  String _resolveMediaUrl(String mediaUrl) {
    final trimmed = mediaUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return trimmed;
    }

    final base = ApiService.baseUrl.replaceAll('/api', '');
    if (trimmed.startsWith('/')) {
      return Uri.parse(base).resolve(trimmed).toString();
    }
    return Uri.parse('$base/').resolve(trimmed).toString();
  }

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    final fullUrl = _resolveMediaUrl(widget.mediaUrl);
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl))
        ..initialize().then((_) {
          setState(() => _isVideoInitialized = true);
          _videoController!.play();
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    final fullMediaUrl = _resolveMediaUrl(widget.mediaUrl);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBackground = theme.scaffoldBackgroundColor;
    final appBarBg =
        (theme.appBarTheme.backgroundColor ?? pageBackground).withAlpha(235);
    final appBarFore =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: _showControls
          ? AppBar(
              title: widget.title != null
                  ? Text(
                      widget.title!,
                      style: TextStyle(color: appBarFore),
                    )
                  : null,
              backgroundColor: appBarBg,
              elevation: 0,
              iconTheme: IconThemeData(color: appBarFore),
            )
          : null,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child: widget.mediaType == 'image'
              ? InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.network(
                    fullMediaUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: theme.iconTheme.color ?? Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withAlpha(160),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              : _isVideoInitialized && _videoController != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                        if (_showControls)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (isDark ? Colors.black : Colors.white)
                                      .withAlpha(77),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        if (_showControls)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                VideoProgressIndicator(
                                  _videoController!,
                                  allowScrubbing: true,
                                  colors: VideoProgressColors(
                                    playedColor: MessengerColors.messengerBlue,
                                    backgroundColor: isDark
                                        ? Colors.white30
                                        : Colors.black12,
                                    bufferedColor: isDark
                                        ? Colors.white60
                                        : Colors.black26,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(
                                        _videoController!.value.position,
                                      ),
                                      style: TextStyle(
                                        color:
                                            theme.textTheme.bodySmall?.color ??
                                                Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(
                                        _videoController!.value.duration,
                                      ),
                                      style: TextStyle(
                                        color:
                                            theme.textTheme.bodySmall?.color ??
                                                Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (_showControls)
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.black : Colors.white)
                                      .withAlpha(200),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: isDark ? Colors.white : Colors.black,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          MessengerColors.messengerBlue,
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
