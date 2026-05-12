import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';

class ProfileScreen extends StatefulWidget {
  final ChatUser?
  user; // If null, editing current user; if provided, viewing other user

  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _bioController;
  XFile? _selectedImage;
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _bioController = TextEditingController();

    if (widget.user != null) {
      _firstNameController.text = widget.user!.firstName;
      _lastNameController.text = widget.user!.lastName;
      _bioController.text = widget.user!.bio;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  Future<void> _saveProfile() async {
    final messageService = context.read<MessageService>();
    final authService = context.read<AuthService>();

    if (authService.accessToken == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not authenticated')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? profileImageBase64;

      // Convert image to base64 if selected
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        profileImageBase64 = base64Encode(bytes);
      }

      final success = await messageService.updateProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        bio: _bioController.text,
        profileImage: profileImageBase64,
        accessToken: authService.accessToken!,
      );

      if (success) {
        setState(() => _isEditing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileImage() {
    final user = widget.user;

    if (_selectedImage != null) {
      return Image.file(
        File(_selectedImage!.path),
        width: 150,
        height: 150,
        fit: BoxFit.cover,
      );
    }

    if (user?.profileImage != null) {
      try {
        return Image.memory(
          base64Decode(user!.profileImage!),
          width: 150,
          height: 150,
          fit: BoxFit.cover,
        );
      } catch (_) {
        // Fallback to avatar
      }
    }

    return Text(
      user?.initials ?? 'U',
      style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isCurrentUser = user == null;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Theme.of(context).appBarTheme.backgroundColor == null
            ? Container(
                decoration: const BoxDecoration(
                  gradient: MessengerColors.messengerGradient,
                ),
              )
            : null,
        title: Text(
          isCurrentUser ? 'My Profile' : '${user!.displayName}\'s Profile',
          style:
              Theme.of(context).appBarTheme.titleTextStyle ??
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: Theme.of(context).iconTheme,
        actions: [
          if (isCurrentUser)
            IconButton(
              onPressed: () => setState(() => _isEditing = !_isEditing),
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
            ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Picture
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: MessengerColors.messengerGradient,
                            boxShadow: [
                              BoxShadow(
                                color: MessengerColors.messengerBlue
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 75,
                            backgroundColor: MessengerColors.messengerBlue
                                .withOpacity(0.1),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(75),
                              child: _buildProfileImage(),
                            ),
                          ),
                        ),
                        if (isCurrentUser && _isEditing)
                          Container(
                            decoration: BoxDecoration(
                              gradient: MessengerColors.messengerGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: MessengerColors.messengerBlue
                                      .withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _pickImage,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Username (non-editable)
                  TextField(
                    controller: TextEditingController(
                      text: user?.username ?? '',
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(
                        color: Color(0xFF8A8D91),
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).inputDecorationTheme.fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      prefixIcon: const Icon(Icons.person),
                      prefixIconColor: MessengerColors.messengerBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // First Name
                  TextField(
                    controller: _firstNameController,
                    readOnly: !isCurrentUser || !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      labelStyle: const TextStyle(
                        color: Color(0xFF8A8D91),
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).inputDecorationTheme.fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      prefixIcon: const Icon(Icons.badge),
                      prefixIconColor: MessengerColors.messengerBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Last Name
                  TextField(
                    controller: _lastNameController,
                    readOnly: !isCurrentUser || !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      labelStyle: const TextStyle(
                        color: Color(0xFF8A8D91),
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).inputDecorationTheme.fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      prefixIcon: const Icon(Icons.badge),
                      prefixIconColor: MessengerColors.messengerBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email (non-editable)
                  TextField(
                    controller: TextEditingController(text: user?.email ?? ''),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(
                        color: Color(0xFF8A8D91),
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).inputDecorationTheme.fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      prefixIcon: const Icon(Icons.email),
                      prefixIconColor: MessengerColors.messengerBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bio
                  TextField(
                    controller: _bioController,
                    readOnly: !isCurrentUser || !_isEditing,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      labelStyle: const TextStyle(
                        color: Color(0xFF8A8D91),
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).inputDecorationTheme.fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                      prefixIcon: const Icon(Icons.info),
                      prefixIconColor: MessengerColors.messengerBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Online Status
                  if (!isCurrentUser)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: user!.isOnline
                            ? MessengerColors.messengerBlue.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: user.isOnline
                              ? MessengerColors.messengerBlue
                              : Colors.grey,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: user.isOnline
                                  ? MessengerColors.onlineGreen
                                  : MessengerColors.offlineGray,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            user.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: user.isOnline
                                  ? MessengerColors.onlineGreen
                                  : MessengerColors.offlineGray,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (!user.isOnline && user.lastSeen != null)
                            Expanded(
                              child: Text(
                                ' • Last seen ${_formatLastSeen(user.lastSeen!)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Color(0xFF8A8D91),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Save Button (only for current user editing)
                  if (isCurrentUser && _isEditing)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: MessengerColors.messengerGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: MessengerColors.messengerBlue.withOpacity(
                              0.3,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _saveProfile,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.save, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Save Profile',
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
                ],
              ),
            ),
    );
  }

  String _formatLastSeen(String timestamp) {
    try {
      final lastSeen = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 1) {
        return 'just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return lastSeen.toString().split(' ')[0];
      }
    } catch (_) {
      return 'unknown';
    }
  }
}
