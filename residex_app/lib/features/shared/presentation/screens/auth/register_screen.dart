import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/animations.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
    UserRole _selectedRole = UserRole.tenant; // Default to tenant
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

    /// Validate form and register user
    void _handleRegister() {
      // Validation
      if (_nameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        _showError('Please fill in all fields');
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Passwords do not match');
        return;
      }

      if (_passwordController.text.length < 6) {
        _showError('Password must be at least 6 characters');
        return;
      }

      _performRegistration();
    }

    void _performRegistration() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authControllerProvider).signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        role: _selectedRole,
        phoneNumber: '+60${_phoneController.text.trim()}',
      );
      // Navigation handled by ref.listen in build()
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
        _showError(_errorMessage!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authControllerProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

    void _showError(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    void _navigateToLogin() {
      context.go('/login');
    }

    
  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Header
                    _buildHeader(),

                    const SizedBox(height: 20),

                    // Register Form Card
                    _buildRegisterCard(),

                    const SizedBox(height: 32),
                  ],
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
          // Logo with glow
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                // Logo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'R',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Title
          Text(
            'Create Account',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle
          Text(
            'Join Residex today',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      );
    }

    Widget _buildRegisterCard() {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Role Selection Toggle
            _buildRoleSelector(),
            const SizedBox(height: 20),

            // Full Name
            _buildTextField(
              label: 'FULL NAME',
              icon: LucideIcons.user,
              controller: _nameController,
              placeholder: 'e.g. Ali Rahman',
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 12),

            // Email
            _buildTextField(
              label: 'EMAIL ADDRESS',
              icon: LucideIcons.mail,
              controller: _emailController,
              placeholder: 'ali@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Phone
            _buildPhoneField(),
            const SizedBox(height: 12),

            // Password
            _buildPasswordField(
              label: 'PASSWORD',
              controller: _passwordController,
              obscure: _obscurePassword,
              onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 12),

            // Confirm Password
            _buildPasswordField(
              label: 'CONFIRM PASSWORD',
              controller: _confirmPasswordController,
              obscure: _obscureConfirmPassword,
              onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            const SizedBox(height: 24),

            // Register Button
            _buildRegisterButton(),
            const SizedBox(height: 20),

            // Divider
            _buildDivider(),
            const SizedBox(height: 16),

            // Social Buttons
            _buildSocialButtons(),
            const SizedBox(height: 16),

            // Login Link
            _buildLoginLink(),
          ],
        ),
      );
    }

    /// Role selection toggle - Tenant / Landlord
    Widget _buildRoleSelector() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'I AM A',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                // Tenant Option
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRole = UserRole.tenant),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: _selectedRole == UserRole.tenant
                            ? const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.user,
                            size: 14,
                            color: _selectedRole == UserRole.tenant
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tenant',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedRole == UserRole.tenant
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Landlord Option
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRole = UserRole.landlord),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: _selectedRole == UserRole.landlord
                            ? const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFEAB308)],
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.building2,
                            size: 14,
                            color: _selectedRole == UserRole.landlord
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Landlord',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedRole == UserRole.landlord
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget _buildTextField({
      required String label,
      required IconData icon,
      required TextEditingController controller,
      required String placeholder,
      TextInputType keyboardType = TextInputType.text,
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

    Widget _buildPasswordField({
      required String label,
      required TextEditingController controller,
      required bool obscure,
      required VoidCallback onToggle,
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
              obscureText: obscure,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.lock, color: Color(0xFF64748B), size: 16),
                suffixIcon: GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                    color: const Color(0xFF64748B),
                    size: 16,
                  ),
                ),
                hintText: '••••••••',
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
              // Country Code (+60)
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
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        LucideIcons.phone,
                        color: Color(0xFF64748B),
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

    Widget _buildRegisterButton() {
      return GestureDetector(
        onTap: _isLoading ? null : _handleRegister,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _selectedRole == UserRole.landlord
                  ? [const Color(0xFFF59E0B), const Color(0xFFEAB308)]
                  : [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (_selectedRole == UserRole.landlord
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF7C3AED))
                    .withValues(alpha: 0.3),
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
                        'Create Account',
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

    Widget _buildDivider() {
      return Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR SIGN UP WITH',
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
          // Google
          _buildSocialButton(
            child: const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
            onTap: () {
              // TODO: Implement Google Sign Up
            },
          ),
          const SizedBox(width: 12),

          // Facebook
          _buildSocialButton(
            child: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 20),
            onTap: () {
              // TODO: Implement Facebook Sign Up
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

    Widget _buildLoginLink() {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
            ),
            GestureDetector(
              onTap: _navigateToLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Log In',
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