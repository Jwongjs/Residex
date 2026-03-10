import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import 'tenant_list_screen.dart';

/// Score Category
class ScoreCategory {
  final String name;
  final int score;
  final int maxScore;
  final String description;
  final IconData icon;

  ScoreCategory({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.description,
    required this.icon,
  });

  double get percentage => (score / maxScore) * 100;

  Color get color {
    final percent = percentage;
    if (percent >= 80) return AppColors.success;
    if (percent >= 60) return AppColors.primary;
    if (percent >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

/// Tenant Score Detail Screen
class TenantScoreDetailScreen extends ConsumerWidget {
  final Tenant tenant;

  const TenantScoreDetailScreen({
    super.key,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = _getScoreCategories();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TENANT SCORE',
          style: AppTextStyles.heading2.copyWith(
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 500,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    tenant.scoreColor.withOpacity(0.3),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Content
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Tenant header
              _buildTenantHeader(),

              const SizedBox(height: 32),

              // Main score card
              _buildMainScoreCard(),

              const SizedBox(height: 32),

              // Score breakdown section
              Text(
                'SCORE BREAKDOWN',
                style: AppTextStyles.label.copyWith(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 16),

              // Category cards
              ...categories.map((category) => _buildCategoryCard(category)),

              const SizedBox(height: 32),

              // Tenant details
              _buildTenantDetails(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTenantHeader() {
    return Row(
      children: [
        // Avatar
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: tenant.scoreColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tenant.scoreColor.withOpacity(0.3),
              width: 3,
            ),
          ),
          child: Center(
            child: Text(
              tenant.avatarInitials,
              style: AppTextStyles.displayLarge.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: tenant.scoreColor,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tenant.name,
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tenant.propertyName,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                tenant.unitNumber,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainScoreCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tenant.scoreColor.withOpacity(0.2),
            AppColors.background,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: tenant.scoreColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: tenant.scoreColor.withOpacity(0.2),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        children: [
          // Score circle
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: tenant.scoreColor.withOpacity(0.3),
                width: 4,
              ),
              color: Colors.black.withOpacity(0.4),
            ),
            child: Text(
              '${tenant.score}',
              style: AppTextStyles.displayLarge.copyWith(
                fontSize: 64,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            tenant.scoreBadge.toUpperCase(),
            style: AppTextStyles.label.copyWith(
              fontSize: 14,
              color: tenant.scoreColor,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Tenant Performance Rating',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(ScoreCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: category.color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  size: 20,
                  color: category.color,
                ),
              ),

              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Text(
                  category.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Score
              Text(
                '${category.score}/${category.maxScore}',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: category.color,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            category.description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: category.score / category.maxScore,
              backgroundColor: AppColors.slate800,
              valueColor: AlwaysStoppedAnimation<Color>(category.color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TENANT DETAILS',
            style: AppTextStyles.label.copyWith(
              fontSize: 9,
              color: AppColors.textMuted,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(height: 16),

          _buildDetailRow('Email', tenant.email, Icons.email_outlined),
          _buildDetailRow('Phone', tenant.phone, Icons.phone_outlined),
          _buildDetailRow(
            'Monthly Rent',
            'RM ${tenant.monthlyRent.toStringAsFixed(2)}',
            Icons.payments_outlined,
          ),
          _buildDetailRow(
            'Lease Period',
            '${_formatDate(tenant.leaseStartDate)} - ${_formatDate(tenant.leaseEndDate)}',
            Icons.calendar_today_outlined,
          ),
          _buildDetailRow(
            'Tenancy Duration',
            tenant.tenancyDuration,
            Icons.schedule_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ScoreCategory> _getScoreCategories() {
    return [
      ScoreCategory(
        name: 'Payment History',
        score: 30,
        maxScore: 30,
        description: 'Perfect on-time payment record for ${tenant.paymentStreak} consecutive months',
        icon: Icons.account_balance_wallet,
      ),
      ScoreCategory(
        name: 'Property Care',
        score: 25,
        maxScore: 30,
        description: 'Maintains property well with minimal maintenance requests',
        icon: Icons.home_repair_service,
      ),
      ScoreCategory(
        name: 'Communication',
        score: 20,
        maxScore: 20,
        description: 'Responsive and professional in all communications',
        icon: Icons.chat_bubble_outline,
      ),
      ScoreCategory(
        name: 'Lease Compliance',
        score: 20,
        maxScore: 20,
        description: 'Adheres to all lease terms and property rules',
        icon: Icons.gavel,
      ),
    ];
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
