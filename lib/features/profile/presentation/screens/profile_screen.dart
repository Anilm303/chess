import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../theme/colors.dart';
import '../../../../models/message_model.dart';
import '../../../../services/auth_service.dart';
import '../../../chat/data/services/message_service.dart';

class ProfileScreen extends StatefulWidget {
  final ChatUser? user;

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
    if (pickedFile != null) setState(() => _selectedImage = pickedFile);
  }

  Future<void> _saveProfile() async {
    final messageService = context.read<MessageService>();
    final authService = context.read<AuthService>();

    if (authService.accessToken == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? profileImageBase64;
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

      if (success && mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatLastSeen(String? timestamp) {
    final dt = timestamp == null ? null : DateTime.tryParse(timestamp);
    if (dt == null) return 'Unknown';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildProfileImage(ChatUser? user) {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(75),
        child: Image.file(File(_selectedImage!.path),
            width: 150, height: 150, fit: BoxFit.cover),
      );
    }

    if (user?.profileImage != null) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(75),
          child: Image.memory(base64Decode(user!.profileImage!),
              width: 150, height: 150, fit: BoxFit.cover),
        );
      } catch (_) {}
    }

    return CircleAvatar(
        radius: 75,
        child:
            Text(user?.initials ?? 'U', style: const TextStyle(fontSize: 40)));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isCurrentUser = user == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCurrentUser ? 'My Profile' : user.displayName),
        actions: [
          if (isCurrentUser)
            IconButton(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(_isEditing ? Icons.check : Icons.edit)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Center(child: _buildProfileImage(user)),
                const SizedBox(height: 16),
                if (isCurrentUser && _isEditing)
                  TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Change Photo')),
                const SizedBox(height: 12),
                TextField(
                    controller:
                        TextEditingController(text: user?.username ?? ''),
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 12),
                TextField(
                    controller: _firstNameController,
                    readOnly: !isCurrentUser || !_isEditing,
                    decoration: const InputDecoration(labelText: 'First name')),
                const SizedBox(height: 12),
                TextField(
                    controller: _lastNameController,
                    readOnly: !isCurrentUser || !_isEditing,
                    decoration: const InputDecoration(labelText: 'Last name')),
                const SizedBox(height: 12),
                TextField(
                    controller: _bioController,
                    readOnly: !isCurrentUser || !_isEditing,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Bio')),
                const SizedBox(height: 20),
                if (isCurrentUser && _isEditing)
                  ElevatedButton(
                      onPressed: _saveProfile, child: const Text('Save')),
                const SizedBox(height: 20),
                if (!isCurrentUser)
                  Text(
                      'Status: ${user.isOnline ? 'Online' : 'Offline'} ${!user.isOnline && user.lastSeen != null ? '• Last seen ${_formatLastSeen(user.lastSeen)}' : ''}'),
              ]),
            ),
    );
  }
}
