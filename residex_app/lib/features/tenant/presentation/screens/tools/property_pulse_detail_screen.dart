import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

class PropertyPulseDetailScreen extends StatelessWidget {
  const PropertyPulseDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Blue ambient glow
          Positioned(
            top: 0, left: 0, right: 0, height: 500,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [AppColors.blue500.withValues(alpha: 0.25), const Color(0xFF02040A)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildMainScoreCard(),
                        const SizedBox(height: 32),
                        _buildVitalsSection(),
                        const SizedBox(height: 32),
                        _buildAIInsightsSection(),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.blue500.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: AppColors.blue400),
            ),
          ),
          const SizedBox(width: 16),
          Text('PROPERTY PULSE',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildMainScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue500.withValues(alpha: 0.2), AppColors.slate900],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3), width: 4),
              color: Colors.black.withValues(alpha: 0.4),
            ),
            child: Text('87',
                style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -2)),
          ),
          const SizedBox(height: 12),
          Text('EXCELLENT CONDITION',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3, color: AppColors.cyan400)),
        ],
      ),
    );
  }

  Widget _buildVitalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.monitor_heart, size: 16, color: AppColors.blue400),
            const SizedBox(width: 8),
            Text('VITALS CHECK',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            _buildVitalCard('BILLS', 'All Paid', Icons.check_circle, AppColors.cyan400),
            _buildVitalCard('TICKETS', '2 Open', Icons.error_outline, AppColors.amber500),
            _buildVitalCard('CHORES', '92% Done', null, Colors.white),
            _buildVitalCard('RENT', 'Due in 5d', null, Colors.white),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalCard(String label, String value, IconData? icon, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.slate500)),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: valueColor),
                const SizedBox(width: 4),
              ],
              Text(value,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: valueColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, size: 16, color: AppColors.blue400),
            const SizedBox(width: 8),
            Text('AI INSIGHTS',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          icon: Icons.water_drop,
          iconColor: AppColors.blue400,
          borderColor: AppColors.blue500.withValues(alpha: 0.2),
          title: 'Water Usage Normal',
          description: 'Usage matches monthly average. No leaks detected.',
          tag: null,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: Icons.bolt,
          iconColor: AppColors.amber500,
          borderColor: AppColors.amber500.withValues(alpha: 0.2),
          title: 'Electricity Spike',
          description: 'Usage up 40% vs last month. Suggest AC servicing for Unit 4-2.',
          tag: 'Alert',
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: Icons.recycling,
          iconColor: AppColors.cyan400,
          borderColor: AppColors.cyan500.withValues(alpha: 0.2),
          title: 'Waste Management',
          description: 'Tenants marked \'Recycling Run\' complete 4 weeks in a row.',
          tag: null,
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required String title,
    required String description,
    String? tag,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (tag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tag.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.amber500)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(description, style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
