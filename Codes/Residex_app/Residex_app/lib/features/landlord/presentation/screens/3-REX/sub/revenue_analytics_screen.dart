import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../../../../../core/theme/app_theme.dart';

/// Revenue Analytics Screen - AI-powered financial insights and predictions
class RevenueAnalyticsScreen extends ConsumerStatefulWidget {
  const RevenueAnalyticsScreen({super.key});

  @override
  ConsumerState<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends ConsumerState<RevenueAnalyticsScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  int _selectedTimeframe = 0; // 0: Month, 1: Quarter, 2: Year

  final List<String> _timeframes = ['Month', 'Quarter', 'Year'];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.success.withOpacity(0.3), AppColors.primaryBlue.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.trending_up, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Revenue Analytics', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 24),
            _buildTimeframeSelector(),
            const SizedBox(height: 24),
            _buildRevenueChart(),
            const SizedBox(height: 24),
            _buildPredictionsSection(),
            const SizedBox(height: 24),
            _buildInsightsSection(),
            const SizedBox(height: 24),
            _buildPropertyBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withOpacity(0.2),
            AppColors.primaryCyan.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Projected Revenue',
                    style: TextStyle(color: AppColors.slate400, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RM 14,580',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_upward, color: AppColors.success, size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      '+8.4%',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat('Current Month', 'RM 12,300', AppColors.primaryCyan),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMiniStat('Growth Rate', '+12.5%', AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(_timeframes.length, (index) {
          final isSelected = _selectedTimeframe == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTimeframe = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppColors.primaryCyan.withOpacity(0.3),
                            AppColors.primaryBlue.withOpacity(0.3),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _timeframes[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.slate400,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue Trend',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.primaryCyan, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'AI Prediction',
                      style: TextStyle(color: AppColors.primaryCyan, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 3000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.slate700,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'RM ${(value / 1000).toStringAsFixed(0)}k',
                          style: TextStyle(color: AppColors.slate400, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[value.toInt()],
                              style: TextStyle(color: AppColors.slate400, fontSize: 12),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 5,
                minY: 8000,
                maxY: 16000,
                lineBarsData: [
                  // Actual revenue line
                  LineChartBarData(
                    spots: [
                      FlSpot(0, 10200),
                      FlSpot(1, 11500),
                      FlSpot(2, 10800),
                      FlSpot(3, 12300),
                      FlSpot(4, 13500),
                    ],
                    isCurved: true,
                    color: AppColors.success,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.success.withOpacity(0.1),
                    ),
                  ),
                  // Predicted revenue line
                  LineChartBarData(
                    spots: [
                      FlSpot(4, 13500),
                      FlSpot(5, 14580),
                    ],
                    isCurved: true,
                    color: AppColors.primaryCyan,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dashArray: [5, 5],
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Predictions',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildPredictionCard(
          title: 'Rent Collection Rate',
          prediction: '94.2%',
          confidence: 'High Confidence',
          trend: '+2.1%',
          icon: Icons.account_balance_wallet,
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        _buildPredictionCard(
          title: 'Expected Vacancies',
          prediction: '2 Units',
          confidence: 'Medium Confidence',
          trend: '-1 unit',
          icon: Icons.home_outlined,
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        _buildPredictionCard(
          title: 'Maintenance Costs',
          prediction: 'RM 2,340',
          confidence: 'High Confidence',
          trend: '+5.2%',
          icon: Icons.build,
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _buildPredictionCard({
    required String title,
    required String prediction,
    required String confidence,
    required String trend,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  prediction,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                confidence,
                style: TextStyle(color: AppColors.primaryCyan, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                trend,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Insights',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          icon: Icons.lightbulb_outline,
          title: 'Optimization Opportunity',
          description: 'Consider increasing rent by 3-5% for properties in high-demand areas. Market analysis shows room for growth.',
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: Icons.trending_up,
          title: 'Revenue Growth',
          description: 'Your revenue is growing 12.5% faster than the market average. Keep up the excellent property management!',
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: Icons.schedule,
          title: 'Payment Patterns',
          description: 'Tenants in Units 204 and 301 typically pay late. Consider automated reminders 3 days before due date.',
          color: AppColors.primaryCyan,
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(color: AppColors.slate400, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Revenue by Property',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildPropertyRevenueItem('Sunset Apartments', 'RM 8,200', 0.56, AppColors.primaryCyan),
        const SizedBox(height: 12),
        _buildPropertyRevenueItem('Downtown Loft', 'RM 4,300', 0.30, AppColors.success),
        const SizedBox(height: 12),
        _buildPropertyRevenueItem('Riverside House', 'RM 2,080', 0.14, AppColors.purple),
      ],
    );
  }

  Widget _buildPropertyRevenueItem(String name, String revenue, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text(
              revenue,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppColors.slate700,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
