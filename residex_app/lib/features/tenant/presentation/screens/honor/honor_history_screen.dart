import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

// ─────────────────────────────────
// HONOR TIER DATA
// ─────────────────────────────────
class _HonorTier {
  final String label;
  final Color color;
  final IconData icon;
  final String perk;

  const _HonorTier(this.label, this.color, this.icon, this.perk);
}

const _honorTiers = <int, _HonorTier>{
  0: _HonorTier('RESTRICTED', AppColors.rose500, Icons.dangerous, 'Penalty: Double Deposit'),
  1: _HonorTier('REHABILITATION', AppColors.slate400, Icons.warning_amber, 'No Premium Listings'),
  2: _HonorTier('NEUTRAL', Colors.white, Icons.shield, 'Standard Access'),
  3: _HonorTier('TRUSTED', AppColors.blue400, Icons.shield, '+10% Trust Factor'),
  4: _HonorTier('HONORABLE', AppColors.purple500, Icons.workspace_premium, 'Priority Support'),
  5: _HonorTier('PARAGON', AppColors.amber500, Icons.workspace_premium, 'Zero Deposit Unlock'),
};

// ─────────────────────────────────
// HONOR EVENT MODEL
// ─────────────────────────────────
enum HonorEventType {
  promotion,
  demotion,
  tribunalVerdict,
  reportFiled,
  reportReceived,
  streakMilestone,
  trustFactorChange,
}

class MockHonorEvent {
  final String id;
  final HonorEventType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final double? trustFactorDelta;
  final Color accentColor;
  final IconData icon;

  const MockHonorEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.trustFactorDelta,
    required this.accentColor,
    required this.icon,
  });

  static List<MockHonorEvent> mockEvents() {
    final now = DateTime.now();
    return [
      MockHonorEvent(
        id: 'HE-001',
        type: HonorEventType.streakMilestone,
        title: 'Clean Streak: 3 Weeks',
        description: 'No violations reported for 21 consecutive days. Keep it up!',
        timestamp: now.subtract(const Duration(hours: 2)),
        trustFactorDelta: 0.02,
        accentColor: AppColors.emerald500,
        icon: Icons.local_fire_department,
      ),
      MockHonorEvent(
        id: 'HE-002',
        type: HonorEventType.tribunalVerdict,
        title: 'Tribunal Verdict: INNOCENT',
        description: 'You reviewed case #TC-0847. Your verdict matched the consensus.',
        timestamp: now.subtract(const Duration(days: 1)),
        trustFactorDelta: 0.05,
        accentColor: AppColors.amber500,
        icon: Icons.gavel,
      ),
      MockHonorEvent(
        id: 'HE-003',
        type: HonorEventType.promotion,
        title: 'Honor Level Promoted',
        description: 'Congratulations! You advanced from REHABILITATION to NEUTRAL.',
        timestamp: now.subtract(const Duration(days: 3)),
        trustFactorDelta: null,
        accentColor: AppColors.purple500,
        icon: Icons.arrow_upward_rounded,
      ),
      MockHonorEvent(
        id: 'HE-004',
        type: HonorEventType.reportFiled,
        title: 'Report Filed: NUISANCE',
        description: 'Your report against Unit B-12-03 was submitted for Tribunal review.',
        timestamp: now.subtract(const Duration(days: 5)),
        trustFactorDelta: null,
        accentColor: AppColors.orange500,
        icon: Icons.warning_amber,
      ),
      MockHonorEvent(
        id: 'HE-005',
        type: HonorEventType.tribunalVerdict,
        title: 'Tribunal Verdict: GUILTY',
        description: 'You reviewed case #TC-0831. Your verdict matched the consensus.',
        timestamp: now.subtract(const Duration(days: 7)),
        trustFactorDelta: 0.05,
        accentColor: AppColors.amber500,
        icon: Icons.gavel,
      ),
      MockHonorEvent(
        id: 'HE-006',
        type: HonorEventType.trustFactorChange,
        title: 'Trust Factor Calibrated',
        description: 'Monthly recalibration based on recent activity and report accuracy.',
        timestamp: now.subtract(const Duration(days: 14)),
        trustFactorDelta: -0.03,
        accentColor: AppColors.cyan500,
        icon: Icons.tune,
      ),
      MockHonorEvent(
        id: 'HE-007',
        type: HonorEventType.reportReceived,
        title: 'Report Dismissed',
        description: 'A GRIEFING report against you was reviewed and dismissed by Tribunal.',
        timestamp: now.subtract(const Duration(days: 21)),
        trustFactorDelta: null,
        accentColor: AppColors.emerald500,
        icon: Icons.check_circle_outline,
      ),
      MockHonorEvent(
        id: 'HE-008',
        type: HonorEventType.streakMilestone,
        title: 'Clean Streak: 2 Weeks',
        description: 'No violations reported for 14 consecutive days.',
        timestamp: now.subtract(const Duration(days: 28)),
        trustFactorDelta: 0.01,
        accentColor: AppColors.emerald500,
        icon: Icons.local_fire_department,
      ),
    ];
  }
}

// ─────────────────────────────────
// HONOR HISTORY SCREEN
// ─────────────────────────────────
class HonorHistoryScreen extends StatelessWidget {
  final int honorLevel;
  final double trustFactor;

  const HonorHistoryScreen({
    super.key,
    this.honorLevel = 2,
    this.trustFactor = 0.85,
  });

  _HonorTier get _tier => _honorTiers[honorLevel] ?? _honorTiers[2]!;

  @override
  Widget build(BuildContext context) {
    final events = MockHonorEvent.mockEvents();

    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Dynamic gradient background
          Container(
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  AppColors.purple500.withValues(alpha: 0.12),
                  const Color(0xFF02040A),
                ],
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
                        _buildHeroSection(),
                        const SizedBox(height: 24),
                        _buildStatsRow(),
                        const SizedBox(height: 32),
                        _buildTierLadder(),
                        const SizedBox(height: 32),
                        _buildActivityTimeline(events),
                        const SizedBox(height: 32),
                        _buildActionButtons(context),
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
  Widget _buildHeader(BuildContext context) {
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
              const Icon(Icons.history_rounded, size: 16, color: AppColors.slate500),
              const SizedBox(width: 8),
              Text(
                'HONOR CHRONICLE',
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
  // HERO SECTION
  // ─────────────────────────────────
  Widget _buildHeroSection() {
    return Center(
      child: Column(
        children: [
          // Tier glow ring
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _tier.color.withValues(alpha: 0.25),
                  blurRadius: 50,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F172A),
                border: Border.all(
                  color: _tier.color.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _tier.icon,
                    size: 32,
                    color: _tier.color,
                    shadows: [
                      Shadow(color: _tier.color.withValues(alpha: 0.5), blurRadius: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LV $honorLevel',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tier label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _tier.color.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _tier.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: _tier.color,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Trust Factor
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TRUST FACTOR',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'k=${trustFactor.toStringAsFixed(2)}',
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cyan500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _tier.perk,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _tier.color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // STATS ROW
  // ─────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('REPORTS\nFILED', '3', AppColors.orange500),
        const SizedBox(width: 12),
        _buildStatCard('TRIBUNAL\nVERDICTS', '7', AppColors.amber500),
        const SizedBox(width: 12),
        _buildStatCard('VIOLATIONS\nRECEIVED', '0', AppColors.emerald500),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.slate500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // TIER LADDER
  // ─────────────────────────────────
  Widget _buildTierLadder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIER PROGRESSION',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: List.generate(6, (index) {
              final tierIndex = 5 - index; // Reverse: 5 at top, 0 at bottom
              final tier = _honorTiers[tierIndex]!;
              final isCurrent = tierIndex == honorLevel;
              final isAchieved = tierIndex <= honorLevel;

              return Column(
                children: [
                  Row(
                    children: [
                      // Tier indicator
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? tier.color.withValues(alpha: 0.2)
                              : isAchieved
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? tier.color
                                : isAchieved
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                            width: isCurrent ? 2 : 1,
                          ),
                          boxShadow: isCurrent
                              ? [BoxShadow(color: tier.color.withValues(alpha: 0.3), blurRadius: 12)]
                              : null,
                        ),
                        child: Icon(
                          tier.icon,
                          size: 16,
                          color: isCurrent
                              ? tier.color
                              : isAchieved
                                  ? AppColors.slate400
                                  : AppColors.slate700,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tier info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  tier.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: isCurrent ? tier.color : isAchieved ? Colors.white : AppColors.slate600,
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tier.color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'CURRENT',
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: tier.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              tier.perk,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isCurrent ? AppColors.slate400 : AppColors.slate600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Level number
                      Text(
                        '$tierIndex',
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? tier.color : AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                  if (index < 5) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 17),
                      child: Container(
                        width: 2,
                        height: 20,
                        color: tierIndex <= honorLevel && tierIndex > 0
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────
  // ACTIVITY TIMELINE
  // ─────────────────────────────────
  Widget _buildActivityTimeline(List<MockHonorEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVITY LOG',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.slate500,
              ),
            ),
            Text(
              '${events.length} EVENTS',
              style: GoogleFonts.robotoMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.slate600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == events.length - 1;
          return _buildEventCard(event, isLast);
        }),
      ],
    );
  }

  Widget _buildEventCard(MockHonorEvent event, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline connector
        SizedBox(
          width: 32,
          child: Column(
            children: [
              // Dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: event.accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: event.accentColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: event.accentColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              // Line
              if (!isLast)
                Container(
                  width: 2,
                  height: 80,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Event card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: event.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(event.icon, size: 14, color: event.accentColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (event.trustFactorDelta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: event.trustFactorDelta! > 0
                              ? AppColors.emerald500.withValues(alpha: 0.15)
                              : AppColors.rose500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${event.trustFactorDelta! > 0 ? '+' : ''}${event.trustFactorDelta!.toStringAsFixed(2)}',
                          style: GoogleFonts.robotoMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: event.trustFactorDelta! > 0
                                ? AppColors.emerald400
                                : AppColors.rose500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  event.description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.slate400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),

                // Timestamp
                Text(
                  _timeAgo(event.timestamp),
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  // ─────────────────────────────────
  // ACTION BUTTONS
  // ─────────────────────────────────
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/harmony-hub', extra: honorLevel),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.amber500,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber500.withValues(alpha: 0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel, size: 16, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    'TRIBUNAL',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/harmony-hub', extra: honorLevel),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber, size: 16, color: AppColors.rose500),
                  const SizedBox(width: 8),
                  Text(
                    'FILE REPORT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
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
      ],
    );
  }
}
