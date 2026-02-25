import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../widgets/common/hero_financial_card.dart';
import '../../widgets/common/stats_summary_card.dart';
import '../../widgets/common/revenue_chart.dart';
import '../../widgets/common/expense_progress_item.dart';

/// Landlord Finance Screen - Income & Expense Analytics
/// 
/// Displays:
/// - Net income overview (Hero card)
/// - Collected vs Pending stats
/// - 6-month revenue trend chart
/// - Expense breakdown by category

class LandlordFinanceScreen extends ConsumerWidget {
  const LandlordFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// TODO Phase 2: Replace with ref.watch(financeStatsProvider)
    final mockNetIncome = 14250.0;
    final mockCollected = 13800.0;
    final mockPending = 450.0;
    final mockRevenueChange = 12.5;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient background gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 600,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.3),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Net Income Hero Card
                      HeroFinancialCard(
                        amount: mockNetIncome,
                        currency: 'RM',
                        changePercentage: mockRevenueChange,
                        period: 'this month',
                        title: 'Net Income',
                        subtitle: 'OCTOBER 2024',
                      ),

                      const SizedBox(height: 24),

                      // Collected vs Pending Stats
                      StatsSummaryCard(
                        leftLabel: 'Collected',
                        leftValue: 'RM ${(mockCollected / 1000).toStringAsFixed(1)}k',
                        leftIcon: Icons.trending_up,
                        leftColor: AppColors.success,
                        rightLabel: 'Pending',
                        rightValue: 'RM ${mockPending.toStringAsFixed(0)}',
                        rightIcon: Icons.trending_down,
                        rightColor: AppColors.error,
                      ),

                      const SizedBox(height: 24),

                      // Revenue Trend Chart
                      const RevenueChart(
                        monthlyData: [65, 78, 45, 92, 85, 100],
                        months: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
                      ),

                      const SizedBox(height: 24),

                      // Expense Breakdown Section
                      _buildExpenseBreakdown(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryCyan.withOpacity(0.3),
              ),
            ),
            child: Icon(
              Icons.trending_up,
              color: AppColors.primaryCyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finance Hub',
                style: AppTextStyles.heading2.copyWith(
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'INCOME & EXPENSES',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primaryCyan.withOpacity(0.8),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseBreakdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 16,
                color: AppColors.purple,
              ),
              const SizedBox(width: 8),
              Text(
                'EXPENSE BREAKDOWN',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Expense items
          const ExpenseProgressItem(
            label: 'Maintenance',
            amount: 2400,
            percentage: 45,
            color: AppColors.error,
          ),

          const SizedBox(height: 20),

          const ExpenseProgressItem(
            label: 'Utilities',
            amount: 1600,
            percentage: 30,
            color: AppColors.primaryCyan,
          ),

          const SizedBox(height: 20),

          const ExpenseProgressItem(
            label: 'Insurance',
            amount: 800,
            percentage: 15,
            color: AppColors.primary,
          ),

          const SizedBox(height: 20),

          const ExpenseProgressItem(
            label: 'Services',
            amount: 530,
            percentage: 10,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}