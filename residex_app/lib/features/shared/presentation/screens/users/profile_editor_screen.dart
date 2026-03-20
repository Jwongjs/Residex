import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/entities/users/app_user.dart';
import '../../providers/users_provider.dart';  // For currentUserProvider
import '../../../../../core/di/injection.dart';  // For userRepositoryProvider

class ProfileEditorScreen extends ConsumerStatefulWidget {
  final AppUser appUser;

  const ProfileEditorScreen({
    super.key,
    required this.appUser,
  });

  @override
  ConsumerState<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  late TextEditingController _nameController;
  String? _imagePath;
  int _selectedGradientIndex = 0;
  final ImagePicker _picker = ImagePicker();

  final List<List<Color>> _gradients = [
    [const Color(0xFF22D3EE), const Color(0xFF2563EB)], // Cyan to Blue
    [const Color(0xFF10B981), const Color(0xFF059669)], // Emerald to Teal
    [const Color(0xFFA855F7), const Color(0xFF6366F1)], // Purple to Indigo
    [const Color(0xFFFB7185), const Color(0xFFEF4444)], // Rose to Red
    [const Color(0xFFFBBF24), const Color(0xFFF97316)], // Amber to Orange
    [const Color(0xFF94A3B8), const Color(0xFF475569)], // Slate to Slate
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appUser.name);
    _imagePath = widget.appUser.profileImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        HapticFeedback.mediumImpact();
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Choose Photo Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Camera option
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22D3EE).withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF22D3EE),
                  ),
                ),
                title: const Text(
                  'Camera',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                subtitle: const Text(
                  'Take a new photo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),

              const SizedBox(height: 12),

              // Gallery option
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Color(0xFFA855F7),
                  ),
                ),
                title: const Text(
                  'Gallery',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                subtitle: const Text(
                  'Choose from gallery',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),

              if (_imagePath != null) ...[
                const SizedBox(height: 12),

                // Remove photo option
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imagePath = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();

    // Create updated user with new values
    final updatedUser = widget.appUser.copyWith(
      name: _nameController.text.trim(),
      profileImage: _imagePath,
      gradientColorValues: [
        _gradients[_selectedGradientIndex][0].value,
        _gradients[_selectedGradientIndex][1].value,
      ],
    );

    try {
      // Save to database via repository
      await ref.read(userRepositoryProvider).updateUser(updatedUser);

      // Invalidate provider to refresh all screens showing user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Photo Preview
            Center(
              child: Stack(
                children: [
                  // Avatar
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _gradients[_selectedGradientIndex],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha:0.2),
                        width: 2,
                      ),
                    ),
                    child: _imagePath != null
                        ? ClipOval(
                            child: _imagePath!.startsWith('http')
                                ? Image.network(
                                    _imagePath!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_imagePath!),
                                    fit: BoxFit.cover,
                                  ),
                          )
                        : Center(
                            child: Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text
                                      .split(' ')
                                      .map((word) => word[0])
                                      .take(2)
                                      .join()
                                      .toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),

                  // Camera button
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22D3EE),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Name field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISPLAY NAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha:0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha:0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha:0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF22D3EE),
                        width: 2,
                      ),
                    ),
                    hintText: 'Enter your name',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha:0.3),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {}); // Rebuild to update avatar initials
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Color picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THEME COLOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(
                    _gradients.length,
                    (index) => GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedGradientIndex = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _gradients[index],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedGradientIndex == index
                                ? Colors.white
                                : Colors.white.withValues(alpha:0.2),
                            width: _selectedGradientIndex == index ? 3 : 2,
                          ),
                        ),
                        child: _selectedGradientIndex == index
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 28,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Save button
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}