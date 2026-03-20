import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/users/app_user.dart';

// ─────────────────────────────────
// HONOR TIER HELPERS
// ─────────────────────────────────
class _TierInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _TierInfo(this.label, this.color, this.icon);
}

const _tierMap = <HonorLevel, _TierInfo>{
  HonorLevel.restricted: _TierInfo('RESTRICTED', AppColors.rose500, Icons.dangerous),
  HonorLevel.rehabilitation: _TierInfo('REHABILITATION', AppColors.slate400, Icons.warning_amber),
  HonorLevel.neutral: _TierInfo('NEUTRAL', Colors.white, Icons.shield),
  HonorLevel.trusted: _TierInfo('TRUSTED', AppColors.blue400, Icons.shield),
  HonorLevel.exemplary: _TierInfo('HONORABLE', AppColors.purple500, Icons.workspace_premium),
  HonorLevel.paragon: _TierInfo('PARAGON', AppColors.amber500, Icons.workspace_premium),
};

String _scoreTier(int score) {
  if (score >= 900) return 'PERFECT';
  if (score >= 800) return 'EXCELLENT';
  if (score >= 700) return 'GOOD';
  if (score >= 600) return 'FAIR';
  return 'POOR';
}

Color _scoreTierColor(int score) {
  if (score >= 900) return AppColors.emerald500;
  if (score >= 800) return AppColors.cyan500;
  if (score >= 700) return AppColors.blue400;
  if (score >= 600) return AppColors.amber500;
  return AppColors.rose500;
}

// ─────────────────────────────────
// PROFILE SCREEN
// ─────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final AppUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Privacy settings
  String _visibility = 'HOUSE';
  bool _anonymousReviews = true;

  _TierInfo get _honorInfo => _tierMap[widget.user.honorLevel] ?? _tierMap[HonorLevel.neutral]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  AppColors.cyan500.withValues(alpha: 0.10),
                  const Color(0xFF02040A),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatarHero(),
                        const SizedBox(height: 28),
                        _buildScoreCards(),
                        const SizedBox(height: 24),
                        _buildStatsGrid(),
                        const SizedBox(height: 32),
                        _buildQuickActions(),
                        const SizedBox(height: 32),
                        _buildPrivacySettings(),
                        const SizedBox(height: 32),
                        _buildSignOut(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // HEADER
  // ─────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 20),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.slate500),
              const SizedBox(width: 8),
              Text(
                'IDENTITY MATRIX',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // AVATAR HERO
  // ─────────────────────────────────
  Widget _buildAvatarHero() {
    return Center(
      child: Column(
        children: [
          // Avatar with glow
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.cyan500, AppColors.purple500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan500.withValues(alpha: 0.25),
                  blurRadius: 40,
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                widget.user.avatarInitials,
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            widget.user.name,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Badges row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Honor badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: _honorInfo.color.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_honorInfo.icon, size: 12, color: _honorInfo.color),
                    const SizedBox(width: 4),
                    Text(
                      _honorInfo.label,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: _honorInfo.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyan500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.user.role == UserRole.landlord ? 'LANDLORD' : 'TENANT',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppColors.cyan500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // SCORE CARDS
  // ─────────────────────────────────
  Widget _buildScoreCards() {
    final fiscalScore = widget.user.fiscalScore;
    final harmonyScore = 750; // Mock harmony score

    return Row(
      children: [
        Expanded(
          child: _buildScoreCard(
            label: 'FISCAL SCORE',
            score: fiscalScore,
            tier: _scoreTier(fiscalScore),
            color: AppColors.cyan500,
            icon: Icons.trending_up,
            onTap: () => context.push('/score-detail', extra: {
              'fiscalScore': fiscalScore,
              'harmonyScore': harmonyScore,
              'tab': 'fiscal',
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildScoreCard(
            label: 'HARMONY SCORE',
            score: harmonyScore,
            tier: _scoreTier(harmonyScore),
            color: AppColors.purple500,
            icon: Icons.shield_outlined,
            onTap: () => context.push('/score-detail', extra: {
              'fiscalScore': fiscalScore,
              'harmonyScore': harmonyScore,
              'tab': 'harmony',
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard({
    required String label,
    required int score,
    required String tier,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.slate600),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$score',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tier,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: _scoreTierColor(score),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // STATS GRID
  // ─────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = widget.user.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERFORMANCE METRICS',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMetricTile(
              'TRUST FACTOR',
              'k=${widget.user.trustFactor.toStringAsFixed(2)}',
              Icons.verified_user,
              AppColors.cyan500,
            ),
            const SizedBox(width: 12),
            _buildMetricTile(
              'PAY STREAK',
              '${stats?.streak ?? 12} mo',
              Icons.local_fire_department,
              AppColors.orange500,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMetricTile(
              'GLOBAL RANK',
              '#${stats?.ranking ?? 247}',
              Icons.leaderboard,
              AppColors.amber500,
            ),
            const SizedBox(width: 12),
            _buildMetricTile(
              'TOTAL PAID',
              '${stats?.totalPayments ?? 48}',
              Icons.receipt_long,
              AppColors.emerald500,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.robotoMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.edit,
          iconColor: AppColors.cyan500,
          title: 'Edit Profile',
          subtitle: 'AVATAR, NAME, THEME',
          onTap: () {
            // Navigate to profile editor (push without route since it uses Navigator)
            context.push('/profile-editor', extra: widget.user);
          },
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          icon: Icons.description_outlined,
          iconColor: AppColors.emerald500,
          title: 'Rental Resume',
          subtitle: 'PORTABLE TENANT CV',
          onTap: () => context.push('/rental-resume', extra: widget.user),
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          icon: Icons.history_rounded,
          iconColor: AppColors.purple500,
          title: 'Honor Chronicle',
          subtitle: 'ACTIVITY LOG & TIER PROGRESS',
          onTap: () => context.push('/honor-history', extra: {
            'honorLevel': widget.user.honorLevel.index,
            'trustFactor': widget.user.trustFactor,
          }),
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          icon: Icons.visibility_off,
          iconColor: AppColors.slate400,
          title: 'Ghost Mode',
          subtitle: 'STEALTH CONFIGURATION',
          onTap: () => context.push('/ghost-mode'),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.slate600),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // PRIVACY SETTINGS
  // ─────────────────────────────────
  Widget _buildPrivacySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 14, color: AppColors.slate500),
            const SizedBox(width: 8),
            Text(
              'PRIVACY & VISIBILITY',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Score Visibility
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _visibility == 'PUBLIC'
                      ? Icons.public
                      : _visibility == 'HOUSE'
                          ? Icons.groups
                          : Icons.visibility_off,
                  size: 18,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score Visibility',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _visibility,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _visibility = _visibility == 'PUBLIC'
                        ? 'HOUSE'
                        : _visibility == 'HOUSE'
                            ? 'PRIVATE'
                            : 'PUBLIC';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CHANGE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Anonymous Reviews
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline, size: 18, color: AppColors.slate400),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anonymous Reviews',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _anonymousReviews ? 'ENABLED' : 'DISABLED',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _anonymousReviews = !_anonymousReviews),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: _anonymousReviews ? AppColors.emerald500 : AppColors.slate700,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: _anonymousReviews ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Info text
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your Fiscal Score is portable and can be used for future rental applications. Harmony Score remains private to your household unless shared.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.slate600,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────
  Widget _buildSignOut() {
    return GestureDetector(
      onTap: () {
        // Show confirmation dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            content: Text(
              'Are you sure you want to sign out?',
              style: GoogleFonts.inter(color: AppColors.slate400),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate400,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/login');
                },
                child: Text(
                  'Sign Out',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.rose500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.rose500.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.rose500.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 16, color: AppColors.rose500),
            const SizedBox(width: 8),
            Text(
              'SIGN OUT',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.rose500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
