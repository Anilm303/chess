import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../../../models/message_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../features/calls/data/services/call_service.dart';
import '../../../../services/friend_service.dart';
import '../../../../features/media/presentation/screens/media_viewer_screen.dart';
import '../../data/services/message_service.dart';
import '../../../../theme/colors.dart';
import '../../../../features/calls/presentation/screens/call_screen.dart';

enum _AttachmentAction { aiImages, files, playGames, location }

class ChatScreen extends StatefulWidget {
  final ChatUser chatUser;
  final bool isGroupChat;
  final dynamic groupChat;

  const ChatScreen({
    super.key,
    required this.chatUser,
    this.isGroupChat = false,
    this.groupChat,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  Timer? _typingTimer;
  bool _showEmojiPicker = false;
  bool _isUploading = false;
  bool _isRecordingVoice = false;
  String? _voiceRecordingPath;
  Timer? _voiceRecordingTimer;
  Duration _voiceRecordingDuration = Duration.zero;

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
  void dispose() {
    _typingTimer?.cancel();
    _voiceRecordingTimer?.cancel();
    try {
      _voiceRecorder.dispose();
    } catch (_) {}
    _stopTyping();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _chatTargetId() {
    if (widget.isGroupChat) {
      return widget.groupChat is GroupChat
          ? (widget.groupChat as GroupChat).id
          : widget.chatUser.username;
    }
    return widget.chatUser.username;
  }

  void _stopTyping() {
    context.read<MessageService>().sendTyping(
          isGroupChat: widget.isGroupChat,
          targetId: _chatTargetId(),
          isTyping: false,
        );
  }

  Future<void> _toggleVoiceRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Voice messages are not supported on web yet')),
      );
      return;
    }

    if (_isRecordingVoice) {
      await _stopAndSendVoiceNote();
      return;
    }

    final auth = context.read<AuthService>();
    final token = auth.accessToken;
    if (token == null) return;

    final permissionGranted = await _voiceRecorder.hasPermission();
    if (!permissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = '${tempDir.path}/$fileName';

    try {
      await _voiceRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      _voiceRecordingTimer?.cancel();
      _voiceRecordingDuration = Duration.zero;
      _voiceRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecordingVoice) return;
        setState(() {
          _voiceRecordingDuration += const Duration(seconds: 1);
        });
      });
      setState(() {
        _isRecordingVoice = true;
        _voiceRecordingPath = filePath;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopAndSendVoiceNote() async {
    if (!_isRecordingVoice) return;

    final auth = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    final token = auth.accessToken;
    if (token == null) return;

    _voiceRecordingTimer?.cancel();

    String? recordedPath;
    try {
      recordedPath = await _voiceRecorder.stop();
    } catch (e) {
      recordedPath = null;
      debugPrint('Voice recorder stop error: $e');
    }

    setState(() {
      _isRecordingVoice = false;
    });

    final path = recordedPath ?? _voiceRecordingPath;
    _voiceRecordingPath = null;
    if (path == null || path.isEmpty) return;

    final sentAt = DateTime.now().toIso8601String();
    final xFile = XFile(path);

    setState(() => _isUploading = true);
    final success = widget.isGroupChat
        ? await messageService.sendGroupMessageFile(
            widget.groupChat is GroupChat
                ? (widget.groupChat as GroupChat).id
                : widget.chatUser.username,
            xFile,
            token,
            messageType: 'audio',
            text: '',
            timestamp: sentAt,
          )
        : await messageService.sendMessageFile(
            widget.chatUser.username,
            xFile,
            token,
            messageType: 'audio',
            text: '',
            timestamp: sentAt,
          );
    setState(() => _isUploading = false);

    if (!mounted) return;

    if (success) {
      _scrollToBottom();
    } else if (messageService.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageService.error!)),
      );
    }
  }

  void _handleTypingChanged(String value) {
    final messageService = context.read<MessageService>();
    final hasText = value.trim().isNotEmpty;
    messageService.sendTyping(
      isGroupChat: widget.isGroupChat,
      targetId: _chatTargetId(),
      isTyping: hasText,
    );

    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        context.read<MessageService>().sendTyping(
              isGroupChat: widget.isGroupChat,
              targetId: _chatTargetId(),
              isTyping: false,
            );
      });
    }
  }

  String _chatTitle(MessageService messageService) {
    if (widget.isGroupChat) {
      final group = widget.groupChat;
      if (group is GroupChat) {
        return group.name;
      }
    }
    return widget.chatUser.displayName.isNotEmpty
        ? widget.chatUser.displayName
        : widget.chatUser.username;
  }

  String? _chatSubtitle(MessageService messageService) {
    if (widget.isGroupChat) {
      final group = widget.groupChat;
      if (group is GroupChat) {
        final count = group.members.length;
        return '$count members';
      }
      return 'Group chat';
    }
    return widget.chatUser.isOnline
        ? 'Online'
        : widget.chatUser.lastSeen != null
            ? 'Last seen ${widget.chatUser.lastSeen}'
            : null;
  }

  ChatUser? _callTarget(MessageService messageService) {
    if (!widget.isGroupChat) {
      return widget.chatUser;
    }

    final currentUsername = messageService.currentUserProfile?.username;
    final group = widget.groupChat;
    if (group is GroupChat) {
      for (final member in group.members) {
        if (member.username == currentUsername) continue;
        final parts = member.displayName.trim().split(RegExp(r'\s+'));
        final firstName = parts.isNotEmpty ? parts.first : member.username;
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        return ChatUser(
          username: member.username,
          firstName: firstName,
          lastName: lastName,
          email: '',
          profileImage: member.profileImage,
          isOnline: member.isOnline,
        );
      }
    }

    return null;
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final sentAt = DateTime.now().toIso8601String();

    final auth = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    final token = auth.accessToken;
    if (token == null) return;

    setState(() => _isUploading = true);
    final success = widget.isGroupChat
        ? await messageService.sendGroupMessage(
            widget.groupChat is GroupChat
                ? (widget.groupChat as GroupChat).id
                : widget.chatUser.username,
            text,
            token,
            timestamp: sentAt,
          )
        : await messageService.sendMessage(
            widget.chatUser.username,
            text,
            token,
            timestamp: sentAt,
          );
    setState(() => _isUploading = false);

    if (!mounted) return;
    if (success) {
      _messageController.clear();
      _stopTyping();
      _scrollToBottom();
    } else if (messageService.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageService.error!)));
    }
  }

  Future<void> _sendQuickActionText(String text) async {
    final auth = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    final token = auth.accessToken;
    if (token == null || text.trim().isEmpty) return;
    final sentAt = DateTime.now().toIso8601String();

    final success = widget.isGroupChat
        ? await messageService.sendGroupMessage(
            widget.groupChat is GroupChat
                ? (widget.groupChat as GroupChat).id
                : widget.chatUser.username,
            text,
            token,
            timestamp: sentAt,
          )
        : await messageService.sendMessage(
            widget.chatUser.username,
            text,
            token,
            timestamp: sentAt,
          );

    if (!mounted) return;
    if (success) {
      _stopTyping();
      _scrollToBottom();
    } else if (messageService.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageService.error!)));
    }
  }

  Future<void> _sendMedia(ImageSource source, String messageType) async {
    final auth = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    final token = auth.accessToken;
    if (token == null) return;
    final sentAt = DateTime.now().toIso8601String();

    final xFile = messageType == 'video'
        ? await _imagePicker.pickVideo(source: source)
        : await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (xFile == null) return;

    setState(() => _isUploading = true);
    bool success = false;
    if (widget.isGroupChat) {
      final groupId = widget.groupChat is GroupChat
          ? (widget.groupChat as GroupChat).id
          : widget.chatUser.username;
      success = await messageService.sendGroupMessageFile(
        groupId,
        xFile,
        token,
        messageType: messageType,
        text: _messageController.text.trim(),
        timestamp: sentAt,
      );
    } else {
      success = await messageService.sendMessageFile(
        widget.chatUser.username,
        xFile,
        token,
        messageType: messageType,
        text: _messageController.text.trim(),
        timestamp: sentAt,
      );
    }
    setState(() => _isUploading = false);

    if (!mounted) return;
    if (success) {
      _messageController.clear();
      _stopTyping();
      _scrollToBottom();
    } else if (messageService.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageService.error!)));
    }
  }

  Future<void> _pickFileTypeAndSend() async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Image file'),
                onTap: () => Navigator.of(sheetContext).pop('image'),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Video file'),
                onTap: () => Navigator.of(sheetContext).pop('video'),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await _sendMedia(ImageSource.gallery, selected);
  }

  Future<void> _openAiImagePrompt() async {
    final controller = TextEditingController();
    final prompt = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('AI image prompt'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Describe the image you want...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final cleaned = prompt?.trim() ?? '';
    if (cleaned.isEmpty) return;
    await _sendQuickActionText('🧠 AI image request: $cleaned');
  }

  Future<void> _openAttachmentMenu() async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('AI images'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachmentAction.aiImages),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Files'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachmentAction.files),
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports),
                title: const Text('Play games'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachmentAction.playGames),
              ),
              ListTile(
                leading: const Icon(Icons.near_me),
                title: const Text('Location'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachmentAction.location),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    switch (selected) {
      case _AttachmentAction.aiImages:
        await _openAiImagePrompt();
      case _AttachmentAction.files:
        await _pickFileTypeAndSend();
      case _AttachmentAction.playGames:
        await _sendQuickActionText('🎮 Game invite sent');
      case _AttachmentAction.location:
        await _sendQuickActionText('📍 Shared location');
    }
  }

  void _showMessageOptions(BuildContext context, Message msg, bool isMe) {
    if (msg.messageType == 'deleted') return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '😂', '😮', '😢', '😡', '👍'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _reactToMessage(msg.id, emoji);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Unsend message',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _unsendMessage(msg.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _unsendMessage(String messageId) async {
    final messageService = context.read<MessageService>();
    final authService = context.read<AuthService>();
    final token = authService.accessToken;
    if (token != null) {
      await messageService.deleteMessage(messageId, token);
    }
  }

  void _reactToMessage(String messageId, String emoji) async {
    final messageService = context.read<MessageService>();
    final authService = context.read<AuthService>();
    final token = authService.accessToken;
    if (token != null) {
      await messageService.reactToMessage(messageId, emoji, token);
    }
  }

  void _onEmojiSelected(String emoji) {
    _messageController.text += emoji;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startCall(bool videoCall) async {
    final auth = context.read<AuthService>();
    final messageService = context.read<MessageService>();
    final friendService = context.read<FriendService>();
    final callService = context.read<CallService>();
    final target = _callTarget(messageService);
    final token = auth.accessToken;

    if (token == null || target == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No call target available')));
      return;
    }

    if (!widget.isGroupChat) {
      var isFriend = friendService.isFriend(target.username);
      if (!isFriend) {
        await friendService.fetchContacts(token);
        if (!mounted) return;
        isFriend = friendService.isFriend(target.username);
      }
      if (!isFriend) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call is available only after becoming friends'),
          ),
        );
        return;
      }
    }

    await callService.startOutgoingCall(
      target,
      videoCall: videoCall,
      callerProfileImage: messageService.currentUserProfile?.profileImage,
    );

    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CallScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final messageService = context.watch<MessageService>();
    final friendService = context.watch<FriendService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBackground = isDark ? Colors.black : Colors.white;
    final incomingBubble =
        isDark ? const Color(0xFF1A1A1C) : const Color(0xFFF2F3F5);
    final composerBackground = pageBackground;
    final inputBackground =
        isDark ? const Color(0xFF1E1E20) : const Color(0xFFF2F3F5);
    final accentIconColor =
        isDark ? const Color(0xFF4C9BFF) : MessengerColors.messengerBlue;
    final messages = widget.isGroupChat
        ? messageService.currentGroupConversation
        : messageService.currentConversation;
    final canDirectInteract =
        widget.isGroupChat || friendService.isFriend(widget.chatUser.username);
    final title = _chatTitle(messageService);
    final subtitle =
        messageService.typingIndicatorText ?? _chatSubtitle(messageService);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: MessengerColors.messengerBlue.withAlpha(51),
              backgroundImage: widget.chatUser.profileImage != null
                  ? NetworkImage(widget.chatUser.profileImage!)
                  : null,
              child: widget.chatUser.profileImage == null
                  ? Text(
                      widget.chatUser.initials,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withAlpha(179),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: canDirectInteract ? () => _startCall(false) : null,
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Voice call',
          ),
          IconButton(
            onPressed: canDirectInteract ? () => _startCall(true) : null,
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video call',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final Message msg = messages[index];
                final isMe =
                    msg.sender == messageService.currentUserProfile?.username;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: () => _showMessageOptions(context, msg, isMe),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? MessengerColors.messengerBlue
                            : incomingBubble,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _buildMessageBody(context, msg, isMe),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showEmojiPicker)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) => _onEmojiSelected(emoji.emoji),
                config: Config(
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: Theme.of(context).cardColor,
                    columns: 8,
                    emojiSizeMax: 28,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    indicatorColor: MessengerColors.messengerBlue,
                    iconColorSelected: MessengerColors.messengerBlue,
                    backgroundColor: Theme.of(context).cardColor,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    enabled: false,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: Theme.of(context).cardColor,
                  ),
                ),
              ),
            ),
          Container(
            color: composerBackground,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: canDirectInteract ? _openAttachmentMenu : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: accentIconColor,
                    tooltip: 'Attachments',
                  ),
                  IconButton(
                    onPressed: !canDirectInteract || _isUploading
                        ? null
                        : () => _sendMedia(ImageSource.camera, 'image'),
                    icon: const Icon(Icons.camera_alt_outlined),
                    color: accentIconColor,
                    tooltip: 'Camera',
                  ),
                  IconButton(
                    onPressed: !canDirectInteract || _isUploading
                        ? null
                        : _pickFileTypeAndSend,
                    icon: const Icon(Icons.photo_library_outlined),
                    color: accentIconColor,
                    tooltip: 'Gallery',
                  ),
                  IconButton(
                    onPressed: canDirectInteract && !_isUploading
                        ? _toggleVoiceRecording
                        : null,
                    icon: Icon(
                      _isRecordingVoice
                          ? Icons.stop_circle
                          : Icons.mic_none_outlined,
                    ),
                    color: accentIconColor,
                    tooltip:
                        _isRecordingVoice ? 'Stop voice note' : 'Voice note',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: canDirectInteract && !_isRecordingVoice,
                      onChanged: (value) {
                        setState(() {});
                        _handleTypingChanged(value);
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: _isRecordingVoice
                            ? 'Recording voice note...'
                            : _isUploading
                                ? 'Sending...'
                                : (canDirectInteract
                                    ? 'Type a message'
                                    : 'Become friends to chat'),
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white.withAlpha(166)
                              : Colors.black.withAlpha(141),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: inputBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _messageController.text.trim().isEmpty
                          ? Icons.thumb_up_alt_outlined
                          : Icons.send,
                    ),
                    color: accentIconColor,
                    onPressed:
                        _isUploading || _isRecordingVoice || !canDirectInteract
                            ? null
                            : () {
                                if (_messageController.text.trim().isEmpty) {
                                  _sendQuickActionText('👍');
                                } else {
                                  _sendText();
                                }
                              },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBody(BuildContext context, Message msg, bool isMe) {
    final bubbleTextColor =
        isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color;
    final fullMediaUrl = msg.mediaUrl == null || msg.mediaUrl!.isEmpty
        ? null
        : _resolveMediaUrl(msg.mediaUrl!);

    if (msg.messageType == 'deleted') {
      return Text(
        msg.text,
        style: TextStyle(
          color: bubbleTextColor?.withAlpha(179),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final body = msg.messageType == 'audio'
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.text.isNotEmpty) ...[
                Text(msg.text, style: TextStyle(color: bubbleTextColor)),
                const SizedBox(height: 8),
              ],
              if (fullMediaUrl != null)
                _AudioMessageBubble(
                  mediaUrl: fullMediaUrl,
                  isMe: isMe,
                ),
            ],
          )
        : msg.messageType == 'image' || msg.messageType == 'video'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.text.isNotEmpty) ...[
                    Text(msg.text, style: TextStyle(color: bubbleTextColor)),
                    const SizedBox(height: 8),
                  ],
                  if (fullMediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MediaViewerScreen(
                                mediaUrl: msg.mediaUrl!,
                                mediaType: msg.messageType,
                                title: msg.sender,
                              ),
                            ),
                          );
                        },
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72,
                            maxHeight: 240,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (msg.messageType == 'image')
                                Image.network(
                                  fullMediaUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.black,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white70,
                                        size: 36,
                                      ),
                                    );
                                  },
                                )
                              else
                                Container(
                                  color: Colors.black,
                                  child: msg.thumbnailUrl != null &&
                                          msg.thumbnailUrl!.isNotEmpty
                                      ? Image.network(
                                          _resolveMediaUrl(msg.thumbnailUrl!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return _videoPlaceholder();
                                          },
                                        )
                                      : _videoPlaceholder(),
                                ),
                              if (msg.messageType == 'video')
                                Container(
                                  color: Colors.black.withAlpha(51),
                                  child: const Center(
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.play_arrow,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Text(
                msg.text.isNotEmpty ? msg.text : '(empty message)',
                style: TextStyle(color: bubbleTextColor),
              );

    String? statusLabel;
    if (isMe) {
      switch (msg.status) {
        case 'seen':
          statusLabel = 'Seen';
          break;
        case 'delivered':
          statusLabel = 'Delivered';
          break;
        default:
          statusLabel = 'Sent';
      }
    }

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        if (msg.allReactionEmojis.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: msg.allReactionEmojis
                .map(
                  (emoji) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(31),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(emoji),
                  ),
                )
                .toList(),
          ),
        ],
        if (statusLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withAlpha(217),
            ),
          ),
        ],
      ],
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, color: Colors.white, size: 34),
          SizedBox(height: 8),
          Text(
            'Tap to open video',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _AudioMessageBubble extends StatefulWidget {
  final String mediaUrl;
  final bool isMe;

  const _AudioMessageBubble({required this.mediaUrl, required this.isMe});

  @override
  State<_AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<_AudioMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      if (!mounted) return;
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _player.stop();
      await _player.play(UrlSource(widget.mediaUrl));
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
        _isLoading = false;
      });
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() => _isPlaying = false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 18,
              backgroundColor:
                  widget.isMe ? Colors.white : MessengerColors.messengerBlue,
              child: _isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isMe
                            ? MessengerColors.messengerBlue
                            : Colors.white,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: widget.isMe ? Colors.black : Colors.white,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Voice note',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
