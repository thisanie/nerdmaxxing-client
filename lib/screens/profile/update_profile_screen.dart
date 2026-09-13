import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../services/api_client.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

class UpdateProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const UpdateProfileScreen({super.key, required this.profile});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  final _imagePicker = ImagePicker();
  XFile? _avatar;
  Uint8List? _avatarBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.profile.username ?? '',
    );
    _nameController = TextEditingController(text: widget.profile.name ?? '');
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final profileService = context.read<ProfileService>();
    try {
      await profileService.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _avatarBytes == null
            ? null
            : MultipartFile.fromBytes(
                _avatarBytes!,
                filename: _avatar!.name,
              ),
      );
      if (username != (widget.profile.username ?? '')) {
        await profileService.updateUsername(username);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatar = image;
      _avatarBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.surfaceAlt,
                  backgroundImage: _avatarBytes != null
                      ? MemoryImage(_avatarBytes!)
                      : widget.profile.avatarUrl != null
                      ? NetworkImage(widget.profile.avatarUrl!)
                      : null,
                  child: _avatarBytes == null && widget.profile.avatarUrl == null
                      ? const Icon(
                          Icons.person_outline,
                          size: 48,
                          color: AppColors.textSecondary,
                        )
                      : null,
                ),
                IconButton.filled(
                  onPressed: _isSaving ? null : _pickAvatar,
                  tooltip: 'Change profile photo',
                  icon: const Icon(Icons.camera_alt_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Username', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            enabled: !_isSaving,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              prefixText: '@ ',
              hintText: 'your_username',
            ),
          ),
          const SizedBox(height: 20),
          Text('Name', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            enabled: !_isSaving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const SizedBox(height: 20),
          Text('Bio', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            enabled: !_isSaving,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Tell people about yourself',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
