import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/animations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../domain/entities/users/app_user.dart';
import '../../../../../core/widgets/residex_logo.dart';
import '../../providers/auth_providers.dart';

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

  /// Handle form submission - logs in as Tenant by default
    void _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authControllerProvider).signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Navigation is handled by ref.listen in build()
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authControllerProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Dev bypass buttons — skip Firebase entirely
  void _handleTenantSimulate() {
    ref.read(devBypassProvider.notifier).bypass(UserRole.tenant);
    context.go('/sync-hub');
  }

  void _handleLandlordSimulate() {
    ref.read(devBypassProvider.notifier).bypass(UserRole.landlord);
    context.go('/landlord-dashboard');
  }

    
    void _showValidationError() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    void _navigateToRegister() {
      context.go('/register');
    }

   @override
  Widget build(BuildContext context) {
    // Auto-route when Firebase auth state resolves
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        if (user != null && mounted) {
          user.role == UserRole.landlord
              ? context.go('/landlord-dashboard')
              : context.go('/sync-hub');
        }
      });
    });
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient background
          const AmbientBackground(),

          SafeArea(
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

                    // ==================
                    // LOGO & BRANDING
                    // ==================
                    _buildHeader(),

                    const SizedBox(height: 24),

                    // ==================
                    // LOGIN FORM CARD
                    // ==================
                    _buildLoginCard(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo with glow effect
  Container(
    margin: const EdgeInsets.only(bottom: 16),
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Glow behind logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 15,
              ),
            ],
          ),
        ),
        // Residex Logo (arch + diamond)
        const ResidexLogo(
          size: 80,
          syncState: SyncState.synced,
          animate: true,
        ),
      ],
    ),
  ),

        // App Name
        Text(
          'Residex',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),

        // Tagline
        Text(
          'The residential super app.',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient glow inside card (top-right)
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              ),
            ),
          ),

          // Form content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Field
            _buildTextField(
              label: 'EMAIL ADDRESS',
              icon: LucideIcons.mail,
              controller: _emailController,
              placeholder: 'ali@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Password Field
            _buildTextField(
              label: 'PASSWORD',
              icon: LucideIcons.lock,
              controller: _passwordController,
              placeholder: '••••••••',
              isPassword: true,
            ),
            const SizedBox(height: 4),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(color: Colors.red.shade400, fontSize: 12),
                ),
              ),

              // Login Button
              _buildLoginButton(),
              const SizedBox(height: 12),

              // Dev Buttons Row
              _buildDevButtonsRow(),
              const SizedBox(height: 20),

              // Divider
              _buildDivider(),
              const SizedBox(height: 16),

              // Social Login Buttons
              _buildSocialButtons(),
              const SizedBox(height: 16),

              // Sign Up Link
              _buildSignUpLink(),
            ],
          ),
        ],
      ),
    );
  }

 Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 16),
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'PHONE NUMBER',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Row(
          children: [
            // Country Code Box (+60)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇲🇾', style: TextStyle(fontSize: 16)),                                                                                                                                                                                                        

                  const SizedBox(width: 6),
                  Text(
                    '+60',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFCBD5E1),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Phone Input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      LucideIcons.phone,
                      color: const Color(0xFF64748B),
                      size: 16,
                    ),
                    hintText: '12 345 6789',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF475569),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Log In',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowRight, color: Colors.white, size: 16),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDevButtonsRow() {
    return Row(
      children: [
        // Tenant Dev Button (Blue)
        Expanded(
          child: GestureDetector(
            onTap: _handleTenantSimulate,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.play,
                    color: const Color(0xFF60A5FA),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tenant Dev',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF60A5FA),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Landlord Dev Button (Amber)
        Expanded(
          child: GestureDetector(
            onTap: _handleLandlordSimulate,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.building2,
                    color: const Color(0xFFFBBF24),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Landlord Dev',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFBBF24),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

   Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR LOGIN WITH',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Google Button
        _buildSocialButton(
          child: Image.network(
            'https://www.svgrepo.com/show/475656/google-color.svg',
            width: 18,
            height: 18,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.g_mobiledata,
              color: Colors.white,
              size: 24,
            ),
          ),
          onTap: _handleGoogleSignIn,
        ),
        const SizedBox(width: 12),

        // Facebook Button
        _buildSocialButton(
          child: Icon(
            Icons.facebook,
            color: const Color(0xFF1877F2),
            size: 20,
          ),
          onTap: () {
            // TODO: Implement Facebook Sign In
          },
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          GestureDetector(
            onTap: _navigateToRegister,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sign Up',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFA78BFA),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the Residex "A" logo icon
  class _ResidexLogoPainter extends CustomPainter {
    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final path = Path();

      // Draw an "A" shape (simplified Residex logo)
      // Triangle with horizontal bar
      final centerX = size.width / 2;
      final topY = size.height * 0.1;
      final bottomY = size.height * 0.9;
      final barY = size.height * 0.6;

      // Left leg
      path.moveTo(centerX, topY);
      path.lineTo(size.width * 0.15, bottomY);
      path.lineTo(size.width * 0.3, bottomY);
      path.lineTo(centerX, topY + size.height * 0.25);

      // Right leg
      path.moveTo(centerX, topY);
      path.lineTo(size.width * 0.85, bottomY);
      path.lineTo(size.width * 0.7, bottomY);
      path.lineTo(centerX, topY + size.height * 0.25);

      // Horizontal bar
      path.moveTo(size.width * 0.25, barY);
      path.lineTo(size.width * 0.75, barY);
      path.lineTo(size.width * 0.7, barY + size.height * 0.1);
      path.lineTo(size.width * 0.3, barY + size.height * 0.1);
      path.close();

      canvas.drawPath(path, paint);
    }

    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  }
