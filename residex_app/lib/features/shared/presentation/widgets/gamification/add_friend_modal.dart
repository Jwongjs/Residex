import 'dart:ui';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../../../core/theme/app_theme.dart';
  import '../../../../../core/di/injection.dart';
  import '../../../domain/entities/users/app_user.dart';
  import '../../../../shared/presentation/providers/users_provider.dart';
  import '../../../../shared/presentation/providers/friends_provider.dart';

  class AddFriendModal extends StatefulWidget {
    final WidgetRef ref;

    const AddFriendModal({super.key, required this.ref});

    @override
    State<AddFriendModal> createState() => _AddFriendModalState();
  }

  class _AddFriendModalState extends State<AddFriendModal>
      with SingleTickerProviderStateMixin {
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();
    late AnimationController _animController;
    late Animation<double> _slideAnimation;
    late Animation<double> _fadeAnimation;
    bool _isSubmitting = false;

    final List<List<Color>> _avatarGradients = [
      [const Color(0xFF22D3EE), const Color(0xFF2563EB)], // Cyan to Blue
      [const Color(0xFFA855F7), const Color(0xFF6366F1)], // Purple to Indigo
      [const Color(0xFFF59E0B), const Color(0xFFF97316)], // Amber to Orange
      [const Color(0xFF10B981), const Color(0xFF14B8A6)], // Emerald to Teal
      [const Color(0xFFF43F5E), const Color(0xFFEF4444)], // Rose to Red
      [const Color(0xFFD946EF), const Color(0xFFEC4899)], // Fuchsia to Pink
    ];

    @override
    void initState() {
      super.initState();
      _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _slideAnimation = Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ));
      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ));
      _animController.forward();
    }

    @override
    void dispose() {
      _animController.dispose();
      _nameController.dispose();
      _phoneController.dispose();
      super.dispose();
    }

    void _close() {
      _animController.reverse().then((_) => Navigator.pop(context));
    }

    String _generateInitials(String name) {
      return name
          .trim()
          .split(' ')
          .map((n) => n[0])
          .take(2)
          .join()
          .toUpperCase();
    }

    List<int> _randomGradient() {
      final gradient = _avatarGradients[
          DateTime.now().millisecondsSinceEpoch % _avatarGradients.length];
      return [gradient[0].value, gradient[1].value];
    }

    Future<void> _saveFriend() async {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter a name'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      final newFriend = AppUser(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        avatarInitials: _generateInitials(_nameController.text),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : '+60${_phoneController.text.trim().replaceAll(RegExp(r'^0+'), '')}',
        gradientColorValues: _randomGradient(),
        trustScore: 700,
        rank: 'SILVER',
        isGuest: false,
      );

      try {
    // Save to database
    final repository = widget.ref.read(userRepositoryProvider);
    final result = await repository.addUser(newFriend);

    result.fold(
      (failure) {
        // Handle error from Either
        throw Exception(failure.message);
      },
      (_) {
        // Success - refresh providers
        widget.ref.invalidate(usersProvider);
        widget.ref.invalidate(friendsProvider);

        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newFriend.name} added to friends!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
          _close();
        }
      },
    );
  } catch (e) {
    setState(() => _isSubmitting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
  }

    @override
    Widget build(BuildContext context) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    MediaQuery.of(context).size.height * _slideAnimation.value,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.65,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHandle(),
                              _buildHeader(),
                              Flexible(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildNameField(),
                                      const SizedBox(height: 20),
                                      _buildPhoneField(),
                                    ],
                                  ),
                                ),
                              ),
                              _buildSaveButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    Widget _buildHandle() {
      return Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    Widget _buildHeader() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Friend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Save contact to your vault',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _close,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildNameField() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FRIEND\'S NAME',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Raj Kumar',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildPhoneField() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PHONE NUMBER',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '🇲🇾',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+60',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              decoration: TextDecoration.none,
                            ),
                            decoration: InputDecoration(
                              hintText: '12 345 6789',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 18),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget _buildSaveButton() {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _saveFriend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.transparent,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22D3EE), Color(0xFF2563EB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save Friend',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }