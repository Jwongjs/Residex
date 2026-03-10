import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../widgets/layouts/ambient_background.dart';

/// System health metrics
class HealthMetric {
  final String category;
  final String status;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  HealthMetric({
    required this.category,
    required this.status,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// System Health Detail Screen
class LandlordSystemHealthScreen extends ConsumerWidget {
  final int healthScore;

  const LandlordSystemHealthScreen({
    super.key,
    required this.healthScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = _getHealthMetrics();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'PROPERTY PULSE',
          style: AppTextStyles.heading2.copyWith(
            fontSize: 18,
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
                    AppColors.primary.withOpacity(0.3),
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
              // Main health score card
              _buildHealthScoreCard(healthScore),

              const SizedBox(height: 32),

              // Vitals check section
              Text(
                'VITALS CHECK',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textDisabled,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 16),

              // Metrics grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: metrics
                    .take(4)
                    .map((metric) => _buildMetricCard(metric))
                    .toList(),
              ),

              const SizedBox(height: 32),

              // AI Insights section
              Text(
                'AI INSIGHTS',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textDisabled,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 16),

              // Insight cards
              ..._getAIInsights().map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildInsightCard(insight),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard(int score) {
    final scoreColor = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.primary
            : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scoreColor.withOpacity(0.2),
            AppColors.background,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: scoreColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.2),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: scoreColor.withOpacity(0.3),
                width: 4,
              ),
              color: Colors.black.withOpacity(0.4),
            ),
            child: Text(
              '$score',
              style: AppTextStyles.displayLarge.copyWith(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getHealthLabel(score),
            style: AppTextStyles.label.copyWith(
              color: scoreColor,
              fontSize: 12,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(HealthMetric metric) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            metric.category,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textMuted,
              fontSize: 9,
            ),
          ),
          Row(
            children: [
              Icon(
                metric.icon,
                size: 14,
                color: metric.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  metric.value,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    color: metric.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> insight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (insight['color'] as Color).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (insight['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              insight['icon'] as IconData,
              size: 20,
              color: insight['color'] as Color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      insight['title'] as String,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (insight['alert'] == true)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ALERT',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 8,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight['description'] as String,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHealthLabel(int score) {
    if (score >= 80) return 'EXCELLENT CONDITION';
    if (score >= 60) return 'GOOD CONDITION';
    if (score >= 40) return 'NEEDS ATTENTION';
    return 'CRITICAL';
  }

  List<HealthMetric> _getHealthMetrics() {
    return [
      HealthMetric(
        category: 'BILLS',
        status: 'Paid',
        value: 'All Paid',
        description: 'All utilities current',
        icon: Icons.check_circle,
        color: AppColors.success,
      ),
      HealthMetric(
        category: 'TICKETS',
        status: 'Open',
        value: '2 Open',
        description: 'Action required',
        icon: Icons.warning,
        color: AppColors.warning,
      ),
      HealthMetric(
        category: 'OCCUPANCY',
        status: 'High',
        value: '92%',
        description: 'Well occupied',
        icon: Icons.home,
        color: AppColors.primary,
      ),
      HealthMetric(
        category: 'RENT',
        status: 'Due',
        value: 'In 5d',
        description: 'Payment upcoming',
        icon: Icons.schedule,
        color: AppColors.textPrimary,
      ),
    ];
  }

  List<Map<String, dynamic>> _getAIInsights() {
    return [
      {
        'title': 'Water Usage Normal',
        'description':
            'Usage matches monthly average. No leaks detected.',
        'icon': Icons.water_drop,
        'color': AppColors.primary,
        'alert': false,
      },
      {
        'title': 'Electricity Spike',
        'description':
            'Usage up 40% vs last month. Suggest AC servicing for Unit 4-2.',
        'icon': Icons.bolt,
        'color': AppColors.warning,
        'alert': true,
      },
      {
        'title': 'Waste Management',
        'description':
            'Tenants marked recycling complete 4 weeks in a row.',
        'icon': Icons.recycling,
        'color': AppColors.success,
        'alert': false,
      },
    ];
  }
}