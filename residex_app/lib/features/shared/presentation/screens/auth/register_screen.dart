import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/router/app_router.dart';
import '../../../domain/entities/users/app_user.dart';
import '../../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showError('Fill in every field to create your account.');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords don\'t match.');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError('Use a password with at least 6 characters.');
      return;
    }
    _performRegistration();
  }

  void _performRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider).signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
            role: UserRole.landlord,
            phoneNumber: '+60${_phoneController.text.trim()}',
          );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
        _showError(_errorMessage!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.sealRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToLogin() => context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        if (user != null && mounted) context.go(AppRoutes.landlordDashboard);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildRegisterCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text('Create your account', style: AppTextStyles.displayMedium),
        const SizedBox(height: 6),
        Text('Set up ResiDex for your properties.', style: AppTextStyles.bodyMedium),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: CardDecoration.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(label: 'Full name', controller: _nameController, placeholder: 'e.g. Ali Rahman'),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Email address',
            controller: _emailController,
            placeholder: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildPhoneField(),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: 'Password',
            controller: _passwordController,
            obscure: _obscurePassword,
            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: 'Confirm password',
            controller: _confirmPasswordController,
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          const SizedBox(height: 20),
          _buildRegisterButton(),
          const SizedBox(height: 16),
          _buildLoginLink(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text(label, style: AppTextStyles.labelSmall)),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(hintText: placeholder),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text(label, style: AppTextStyles.labelSmall)),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'At least 6 characters',
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onToggle,
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
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text('Phone number', style: AppTextStyles.labelSmall)),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text('+60', style: AppTextStyles.bodyLarge),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: AppTextStyles.bodyLarge,
                decoration: const InputDecoration(hintText: '12 345 6789'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Create account'),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text('Already have an account? ', style: AppTextStyles.bodySmall),
          GestureDetector(
            onTap: _navigateToLogin,
            child: Text(
              'Sign in',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.brass, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
