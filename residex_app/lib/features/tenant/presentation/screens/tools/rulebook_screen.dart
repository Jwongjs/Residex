import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

class _Rule {
  final String title;
  final IconData icon;
  final String desc;
  final String category;
  _Rule(this.title, this.icon, this.desc, this.category);
}

class RulebookScreen extends StatefulWidget {
  const RulebookScreen({super.key});

  @override
  State<RulebookScreen> createState() => _RulebookScreenState();
}

class _RulebookScreenState extends State<RulebookScreen> {
  String _searchQuery = '';

  final _rules = [
    _Rule('Quiet Hours Protocol', Icons.volume_off, 'Strict silence between 11:00 PM - 7:00 AM.', 'NOISE'),
    _Rule('Climate Control', Icons.ac_unit, 'AC must be OFF when unit is vacant.', 'ENERGY'),
    _Rule('Refuse Disposal', Icons.delete_outline, 'Halal/Non-Halal separation required in shared fridge.', 'KITCHEN'),
    _Rule('Guest Verification', Icons.verified_user, 'All overnight guests must register via App.', 'SECURITY'),
  ];

  List<_Rule> get _filteredRules {
    if (_searchQuery.isEmpty) return _rules;
    final q = _searchQuery.toLowerCase();
    return _rules.where((r) =>
        r.title.toLowerCase().contains(q) ||
        r.desc.toLowerCase().contains(q) ||
        r.category.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Indigo glow
          Positioned(
            top: 0, left: 0, right: 0, height: 500,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [AppColors.indigo500.withValues(alpha: 0.2), const Color(0xFF02040A)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(child: _buildRulesList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.blue500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blue500.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.auto_awesome, size: 20, color: AppColors.blue400),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('House Protocol',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              Text('AI RULEBOOK',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.indigo300)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 20, color: AppColors.slate400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF050510).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: AppColors.indigo400),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search protocols...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesList() {
    final rules = _filteredRules;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildRuleCard(rules[index]),
    );
  }

  Widget _buildRuleCard(_Rule rule) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A15).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.indigo500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.2)),
            ),
            child: Icon(rule.icon, size: 22, color: AppColors.indigo300),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.title,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text(rule.desc,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400, height: 1.4)),
              ],
            ),
          ),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right, size: 16, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
