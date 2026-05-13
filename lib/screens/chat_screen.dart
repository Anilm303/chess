import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/message_service.dart';
import '../theme/colors.dart';
import 'call_screen.dart';

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
  Timer? _typingTimer;
  bool _showEmojiPicker = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _typingTimer?.cancel();
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
    final callService = context.read<CallService>();
    final target = _callTarget(messageService);
    final token = auth.accessToken;

    if (token == null || target == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No call target available')));
      return;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBackground = isDark ? Colors.black : Colors.white;
    final incomingBubble = isDark
        ? const Color(0xFF1A1A1C)
        : const Color(0xFFF2F3F5);
    final composerBackground = pageBackground;
    final inputBackground = isDark
        ? const Color(0xFF1E1E20)
        : const Color(0xFFF2F3F5);
    final accentIconColor = isDark
        ? const Color(0xFF4C9BFF)
        : MessengerColors.messengerBlue;
    final messages = widget.isGroupChat
        ? messageService.currentGroupConversation
        : messageService.currentConversation;
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
              backgroundColor: MessengerColors.messengerBlue.withOpacity(0.2),
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
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _startCall(false),
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Voice call',
          ),
          IconButton(
            onPressed: () => _startCall(true),
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
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
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
                  bottomActionBarConfig: const BottomActionBarConfig(
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
                    onPressed: _openAttachmentMenu,
                    icon: const Icon(Icons.add_circle_outline),
                    color: accentIconColor,
                    tooltip: 'Attachments',
                  ),
                  IconButton(
                    onPressed: _isUploading
                        ? null
                        : () => _sendMedia(ImageSource.camera, 'image'),
                    icon: const Icon(Icons.camera_alt_outlined),
                    color: accentIconColor,
                    tooltip: 'Camera',
                  ),
                  IconButton(
                    onPressed: _isUploading ? null : _pickFileTypeAndSend,
                    icon: const Icon(Icons.photo_library_outlined),
                    color: accentIconColor,
                    tooltip: 'Gallery',
                  ),
                  IconButton(
                    onPressed: () => _sendQuickActionText('🎤 Voice message'),
                    icon: const Icon(Icons.mic_none_outlined),
                    color: accentIconColor,
                    tooltip: 'Voice note',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: (value) {
                        setState(() {});
                        _handleTypingChanged(value);
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: _isUploading
                            ? 'Sending...'
                            : 'Type a message',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.65)
                              : Colors.black.withOpacity(0.55),
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
                    onPressed: _isUploading
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
    final bubbleTextColor = isMe
        ? Colors.white
        : Theme.of(context).textTheme.bodyLarge?.color;

    if (msg.messageType == 'deleted') {
      return Text(
        msg.text,
        style: TextStyle(
          color: bubbleTextColor?.withOpacity(0.7),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final fullMediaUrl = msg.mediaUrl == null || msg.mediaUrl!.isEmpty
        ? null
        : '${ApiService.baseUrl.replaceAll('/api', '')}${msg.mediaUrl}';
    final body = msg.messageType == 'image' || msg.messageType == 'video'
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Keep media previews reasonable in chat bubbles
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                      maxHeight: 240,
                    ),
                    child: Container(
                      color: Colors.black,
                      child: msg.messageType == 'image'
                          ? Image.network(
                              fullMediaUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Video attachment',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          )
        : Text(msg.text, style: TextStyle(color: bubbleTextColor));

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
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
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
                      color: Colors.black.withOpacity(0.12),
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
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ],
    );
  }
}
