import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/router/app_router.dart';
import '../../../domain/entities/users/app_user.dart';
import '../../providers/auth_providers.dart';
import '../../../../../core/widgets/residex_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password to continue.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleDevSignIn() {
    ref.read(devBypassProvider.notifier).bypass(UserRole.landlord);
    context.go(AppRoutes.landlordDashboard);
  }

  void _navigateToRegister() => context.go(AppRoutes.register);

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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildLoginCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const ResidexLogo(size: 64, animate: false),
        const SizedBox(height: 16),
        Text(
          'ResiDex',
          style: AppTextStyles.displayLarge.copyWith(fontSize: 36),
        ),
        const SizedBox(height: 6),
        Text(
          "Your properties' paperwork, answered.",
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: CardDecoration.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            label: 'Email address',
            controller: _emailController,
            placeholder: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Password',
            controller: _passwordController,
            placeholder: 'Enter your password',
            isPassword: true,
          ),
          const SizedBox(height: 4),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.sealRed),
              ),
            ),
          const SizedBox(height: 16),
          _buildLoginButton(),
          const SizedBox(height: 12),
          _buildDevSignInButton(),
          const SizedBox(height: 20),
          _buildSignUpLink(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label, style: AppTextStyles.labelSmall),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: placeholder,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Sign in'),
      ),
    );
  }

  Widget _buildDevSignInButton() {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: _handleDevSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.hairline),
          foregroundColor: AppColors.textSecondary,
        ),
        child: Text('Dev sign-in', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text("Don't have an account? ", style: AppTextStyles.bodySmall),
          GestureDetector(
            onTap: _navigateToRegister,
            child: Text(
              'Create one',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.registry,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
