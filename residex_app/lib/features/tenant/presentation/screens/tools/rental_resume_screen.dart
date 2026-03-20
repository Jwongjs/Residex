import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../shared/domain/entities/users/app_user.dart';

class RentalResumeScreen extends StatelessWidget {
  final AppUser user;

  const RentalResumeScreen({super.key, required this.user});

  String get _fiscalTier {
    if (user.fiscalScore >= 800) return 'EXCELLENT';
    if (user.fiscalScore >= 700) return 'GOOD';
    if (user.fiscalScore >= 600) return 'FAIR';
    return 'POOR';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 600,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppColors.indigo500.withValues(alpha: 0.2),
                    AppColors.deepSpace,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(context),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildIDCard(context),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Export button
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: SafeArea(
              child: _buildExportButton(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.deepSpace.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  child: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 20),
                ),
              ),
              Text(
                'RESIDEX ID',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.indigo500.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.share, color: AppColors.indigo400, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIDCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gloss effects
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo500.withValues(alpha: 0.15),
                    blurRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue500.withValues(alpha: 0.08),
                    blurRadius: 80,
                  ),
                ],
              ),
            ),
          ),

          // Card content
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Column(
              children: [
                // Identity section
                _buildIdentitySection(),
                // Fiscal score section
                _buildFiscalSection(),
                // Stewardship section
                _buildStewardshipSection(),
                // Footer
                _buildCardFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.indigo500, AppColors.purple500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.indigo500.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.avatarInitials,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.fingerprint, size: 12, color: AppColors.indigo400),
                      const SizedBox(width: 4),
                      Text(
                        'ID: 8849-2210',
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          color: AppColors.slate400,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Verified badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.emerald500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 12, color: AppColors.emerald400),
                const SizedBox(width: 4),
                Text(
                  'VERIFIED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.emerald400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiscalSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart, size: 14, color: AppColors.indigo400),
                      const SizedBox(width: 8),
                      Text(
                        'FISCAL SCORE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: AppColors.indigo400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        user.fiscalScore.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.indigo500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _fiscalTier,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.indigo300,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Metrics
          _buildMetric(
            label: 'Payment Velocity',
            value: '100%',
            detail: 'On-Time (36/36 Mos)',
            note: 'Zero late fees in 3 years.',
            noteColor: AppColors.emerald400,
            icon: Icons.trending_up,
            iconColor: AppColors.emerald400,
            iconBg: AppColors.emerald500.withValues(alpha: 0.1),
            iconBorder: AppColors.emerald500.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          _buildMetric(
            label: 'Rent Volume',
            value: 'RM 43,200',
            detail: '',
            note: 'Proven capacity to service RM 1.2k/mo.',
            noteColor: AppColors.slate400,
            icon: Icons.attach_money,
            iconColor: AppColors.blue400,
            iconBg: AppColors.blue500.withValues(alpha: 0.1),
            iconBorder: AppColors.blue500.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          _buildMetric(
            label: 'Utility Variance',
            value: '< 5%',
            detail: '',
            note: 'Low financial volatility.',
            noteColor: AppColors.slate400,
            icon: Icons.bolt,
            iconColor: AppColors.purple500,
            iconBg: AppColors.purple500.withValues(alpha: 0.1),
            iconBorder: AppColors.purple500.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required String detail,
    required String note,
    required Color noteColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color iconBorder,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          detail,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: noteColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconBorder),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStewardshipSection() {
    final badges = [
      _Badge(
        title: 'The Asset Guardian',
        icon: Icons.shield,
        color: AppColors.emerald400,
        bg: AppColors.emerald500.withValues(alpha: 0.1),
        border: AppColors.emerald500.withValues(alpha: 0.2),
        proof: 'Returned 3 units with Zero Damages (Verified).',
        impact: 'Eligible for Deposit Waiver.',
      ),
      _Badge(
        title: 'The Peacekeeper',
        icon: Icons.handshake_outlined,
        color: AppColors.blue400,
        bg: AppColors.blue500.withValues(alpha: 0.1),
        border: AppColors.blue500.withValues(alpha: 0.2),
        proof: "Voted 'Fair' in 15 Tribunal Cases.",
        impact: 'High stability. Unlikely to cause conflict.',
      ),
      _Badge(
        title: 'Community Pillar',
        icon: Icons.star,
        color: AppColors.amber500,
        bg: AppColors.amber500.withValues(alpha: 0.1),
        border: AppColors.amber500.withValues(alpha: 0.2),
        proof: 'Zero Noise Complaints in 24 months.',
        impact: 'Ideal neighbor profile.',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: AppColors.blue400),
              const SizedBox(width: 8),
              Text(
                'STEWARDSHIP RECORD',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppColors.blue400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...badges.map((badge) => _buildBadgeCard(badge)),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(_Badge badge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: badge.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badge.border),
            ),
            child: Icon(badge.icon, size: 24, color: badge.color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: badge.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.proof,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.slate500,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          badge.impact,
                          style: GoogleFonts.robotoMono(
                            fontSize: 9,
                            color: AppColors.slate400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Center(
        child: Text(
          'VERIFIED BY RESIDEX PROTOCOL  •  GENERATED ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.slate600,
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cyan500, AppColors.blue600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan500.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Generating Official Residex PDF...')),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.download, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'EXPORT PDF IDENTITY',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge {
  final String title;
  final IconData icon;
  final Color color;
  final Color bg;
  final Color border;
  final String proof;
  final String impact;

  _Badge({
    required this.title,
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
    required this.proof,
    required this.impact,
  });
}
