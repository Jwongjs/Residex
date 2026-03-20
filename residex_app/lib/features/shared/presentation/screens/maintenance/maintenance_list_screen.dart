import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';

// ─────────────────────────────────
// DATA MODELS
// ─────────────────────────────────

enum TicketCategory {
  acHeating,
  plumbing,
  electrical,
  doorsWindows,
  appliances,
  structure,
  pestControl,
  other,
}

enum TicketUrgency { urgent, high, medium, low }

enum TicketStatus { open, acknowledged, scheduled, inProgress, resolved }

class CategoryMeta {
  final String label;
  final String sub;
  final IconData icon;
  final Color color;

  const CategoryMeta(this.label, this.sub, this.icon, this.color);
}

const categoryMeta = <TicketCategory, CategoryMeta>{
  TicketCategory.acHeating: CategoryMeta('AC / Heating', 'CLIMATE CONTROL', LucideIcons.thermometer, Color(0xFF06B6D4)),
  TicketCategory.plumbing: CategoryMeta('Plumbing', 'WATER SYSTEMS', LucideIcons.droplets, Color(0xFF3B82F6)),
  TicketCategory.electrical: CategoryMeta('Electrical', 'POWER SYSTEMS', LucideIcons.zap, Color(0xFFF59E0B)),
  TicketCategory.doorsWindows: CategoryMeta('Doors / Windows', 'ACCESS POINTS', LucideIcons.doorOpen, Color(0xFFA855F7)),
  TicketCategory.appliances: CategoryMeta('Appliances', 'EQUIPMENT', LucideIcons.wrench, Color(0xFFEC4899)),
  TicketCategory.structure: CategoryMeta('Structure', 'WALLS / CEILING', LucideIcons.building, Color(0xFF64748B)),
  TicketCategory.pestControl: CategoryMeta('Pest Control', 'INFESTATION', LucideIcons.bug, Color(0xFFEF4444)),
  TicketCategory.other: CategoryMeta('Other', 'GENERAL', LucideIcons.home, Color(0xFF10B981)),
};

class MockTicket {
  final String id;
  final String title;
  final String description;
  final TicketCategory category;
  final TicketUrgency urgency;
  final TicketStatus status;
  final DateTime created;
  final DateTime? acknowledgedAt;
  final int photoCount;
  final int commentCount;
  final String reportedBy;

  const MockTicket({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.status,
    required this.created,
    this.acknowledgedAt,
    this.photoCount = 0,
    this.commentCount = 0,
    this.reportedBy = 'You',
  });

  static List<MockTicket> mockTickets() {
    final now = DateTime.now();
    return [
      MockTicket(
        id: 'K-2026-0210-001',
        title: 'AC making loud buzzing sound',
        description: 'The air-conditioning unit in the master bedroom is producing a constant loud buzzing noise. Started yesterday evening. Possible electrical issue.',
        category: TicketCategory.acHeating,
        urgency: TicketUrgency.high,
        status: TicketStatus.inProgress,
        created: now.subtract(const Duration(days: 2, hours: 4)),
        acknowledgedAt: now.subtract(const Duration(days: 1, hours: 20)),
        photoCount: 3,
        commentCount: 5,
      ),
      MockTicket(
        id: 'K-2026-0212-002',
        title: 'Kitchen sink leaking',
        description: 'Slow drip from the pipe underneath the kitchen sink. Water pooling on the cabinet floor. Getting worse.',
        category: TicketCategory.plumbing,
        urgency: TicketUrgency.medium,
        status: TicketStatus.acknowledged,
        created: now.subtract(const Duration(hours: 18)),
        acknowledgedAt: now.subtract(const Duration(hours: 6)),
        photoCount: 2,
        commentCount: 2,
      ),
      MockTicket(
        id: 'K-2026-0213-003',
        title: 'Bedroom light switch sparking',
        description: 'The light switch in bedroom 2 produces visible sparks when toggled. Potential fire hazard — avoiding use.',
        category: TicketCategory.electrical,
        urgency: TicketUrgency.urgent,
        status: TicketStatus.open,
        created: now.subtract(const Duration(hours: 3)),
        photoCount: 1,
        commentCount: 0,
      ),
      MockTicket(
        id: 'K-2026-0205-004',
        title: 'Washing machine not draining',
        description: 'Washing machine completes cycle but water remains in drum. Tried clearing filter — no change.',
        category: TicketCategory.appliances,
        urgency: TicketUrgency.medium,
        status: TicketStatus.resolved,
        created: now.subtract(const Duration(days: 9)),
        acknowledgedAt: now.subtract(const Duration(days: 8)),
        photoCount: 2,
        commentCount: 7,
      ),
      MockTicket(
        id: 'K-2026-0201-005',
        title: 'Ceiling crack in living room',
        description: 'Hairline crack appeared on living room ceiling near the air-con unit. Approximately 30cm long. No water staining visible.',
        category: TicketCategory.structure,
        urgency: TicketUrgency.low,
        status: TicketStatus.resolved,
        created: now.subtract(const Duration(days: 13)),
        acknowledgedAt: now.subtract(const Duration(days: 12)),
        photoCount: 4,
        commentCount: 3,
      ),
    ];
  }
}

// ─────────────────────────────────
// HELPERS
// ─────────────────────────────────

Color urgencyColor(TicketUrgency u) {
  switch (u) {
    case TicketUrgency.urgent:
      return AppColors.red500;
    case TicketUrgency.high:
      return AppColors.orange500;
    case TicketUrgency.medium:
      return AppColors.amber500;
    case TicketUrgency.low:
      return AppColors.slate500;
  }
}

String urgencyLabel(TicketUrgency u) {
  switch (u) {
    case TicketUrgency.urgent:
      return 'URGENT';
    case TicketUrgency.high:
      return 'HIGH';
    case TicketUrgency.medium:
      return 'MEDIUM';
    case TicketUrgency.low:
      return 'LOW';
  }
}

String urgencySla(TicketUrgency u) {
  switch (u) {
    case TicketUrgency.urgent:
      return '4h SLA';
    case TicketUrgency.high:
      return '48h SLA';
    case TicketUrgency.medium:
      return '7d SLA';
    case TicketUrgency.low:
      return '14d SLA';
  }
}

Color statusColor(TicketStatus s) {
  switch (s) {
    case TicketStatus.open:
      return AppColors.red500;
    case TicketStatus.acknowledged:
      return AppColors.orange500;
    case TicketStatus.scheduled:
      return AppColors.amber500;
    case TicketStatus.inProgress:
      return AppColors.blue500;
    case TicketStatus.resolved:
      return AppColors.emerald500;
  }
}

String statusLabel(TicketStatus s) {
  switch (s) {
    case TicketStatus.open:
      return 'OPEN';
    case TicketStatus.acknowledged:
      return 'ACKNOWLEDGED';
    case TicketStatus.scheduled:
      return 'SCHEDULED';
    case TicketStatus.inProgress:
      return 'IN PROGRESS';
    case TicketStatus.resolved:
      return 'RESOLVED';
  }
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

// ─────────────────────────────────
// FILTER
// ─────────────────────────────────

enum _FilterOption { all, open, inProgress, resolved }

// ─────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────

class MaintenanceListScreen extends StatefulWidget {
  const MaintenanceListScreen({super.key});

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen>
    with SingleTickerProviderStateMixin {
  _FilterOption _activeFilter = _FilterOption.all;
  final List<MockTicket> _tickets = MockTicket.mockTickets();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<MockTicket> get _filteredTickets {
    switch (_activeFilter) {
      case _FilterOption.all:
        return _tickets;
      case _FilterOption.open:
        return _tickets.where((t) =>
            t.status == TicketStatus.open ||
            t.status == TicketStatus.acknowledged).toList();
      case _FilterOption.inProgress:
        return _tickets.where((t) =>
            t.status == TicketStatus.inProgress ||
            t.status == TicketStatus.scheduled).toList();
      case _FilterOption.resolved:
        return _tickets.where((t) => t.status == TicketStatus.resolved).toList();
    }
  }

  int get _openCount => _tickets.where((t) =>
      t.status != TicketStatus.resolved).length;
  int get _resolvedCount => _tickets.where((t) =>
      t.status == TicketStatus.resolved).length;
  int get _urgentCount => _tickets.where((t) =>
      t.urgency == TicketUrgency.urgent &&
      t.status != TicketStatus.resolved).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      body: Stack(
        children: [
          // Radial gradient background
          Container(
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                AppColors.indigo500.withValues(alpha: 0.3),
                AppColors.deepSpace,
                AppColors.deepSpace,
              ],
                stops: const [0.0, 0.5, 1.0],
                
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
                        _buildStatsRow(),
                        const SizedBox(height: 28),
                        _buildFilterChips(),
                        const SizedBox(height: 20),
                        _buildTicketList(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FAB
          _buildReportButton(),
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
              Icon(LucideIcons.wrench, size: 14, color: AppColors.indigo500.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text(
                'MAINTENANCE',
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
  // STATS ROW
  // ─────────────────────────────────
  Widget _buildStatsRow() {
    return Column(
      children: [
        Text(
          'TICKET HQ',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track, report and resolve property issues',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(child: _buildStatCard(
              value: '$_openCount',
              label: 'OPEN',
              color: AppColors.orange500,
              icon: LucideIcons.alertCircle,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              value: _urgentCount > 0 ? '$_urgentCount' : '0',
              label: 'URGENT',
              color: AppColors.red500,
              icon: LucideIcons.alertTriangle,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              value: '$_resolvedCount',
              label: 'RESOLVED',
              color: AppColors.emerald500,
              icon: LucideIcons.checkCircle,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
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
    );
  }

  // ─────────────────────────────────
  // FILTER CHIPS
  // ─────────────────────────────────
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _FilterOption.values.map((filter) {
          final isActive = _activeFilter == filter;
          final label = switch (filter) {
            _FilterOption.all => 'All Tickets',
            _FilterOption.open => 'Open',
            _FilterOption.inProgress => 'In Progress',
            _FilterOption.resolved => 'Resolved',
          };
          final count = switch (filter) {
            _FilterOption.all => _tickets.length,
            _FilterOption.open => _tickets.where((t) =>
                t.status == TicketStatus.open ||
                t.status == TicketStatus.acknowledged).length,
            _FilterOption.inProgress => _tickets.where((t) =>
                t.status == TicketStatus.inProgress ||
                t.status == TicketStatus.scheduled).length,
            _FilterOption.resolved => _resolvedCount,
          };

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = filter),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.indigo500.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppColors.indigo500.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.indigo400 : AppColors.slate400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.indigo500.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.indigo400 : AppColors.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────
  // TICKET LIST
  // ─────────────────────────────────
  Widget _buildTicketList() {
    final tickets = _filteredTickets;

    if (tickets.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.checkCircle, size: 48, color: AppColors.emerald500.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('All Clear', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('No tickets match this filter.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: tickets.map((ticket) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildTicketCard(ticket),
      )).toList(),
    );
  }

  Widget _buildTicketCard(MockTicket ticket) {
    final cat = categoryMeta[ticket.category]!;
    final sColor = statusColor(ticket.status);
    final uColor = urgencyColor(ticket.urgency);
    final isUrgent = ticket.urgency == TicketUrgency.urgent && ticket.status != TicketStatus.resolved;

    return GestureDetector(
      onTap: () => context.push('/maintenance/detail', extra: ticket),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUrgent
                ? AppColors.red500.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: isUrgent
              ? [BoxShadow(color: AppColors.red500.withValues(alpha: 0.08), blurRadius: 20)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: category icon + category label + urgency badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cat.color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(cat.icon, size: 18, color: cat.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: cat.color,
                        ),
                      ),
                      Text(
                        ticket.id,
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: uColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: uColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    urgencyLabel(ticket.urgency),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: uColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              ticket.title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),

            // Description preview
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.slate400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),

            // Bottom row: status + meta
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: sColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: sColor.withValues(alpha: 0.5), blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel(ticket.status),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: sColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (ticket.photoCount > 0) ...[
                  Icon(LucideIcons.camera, size: 12, color: AppColors.slate500),
                  const SizedBox(width: 4),
                  Text('${ticket.photoCount}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500)),
                  const SizedBox(width: 12),
                ],
                if (ticket.commentCount > 0) ...[
                  Icon(LucideIcons.messageCircle, size: 12, color: AppColors.slate500),
                  const SizedBox(width: 4),
                  Text('${ticket.commentCount}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500)),
                  const SizedBox(width: 12),
                ],
                Icon(LucideIcons.clock, size: 12, color: AppColors.slate500),
                const SizedBox(width: 4),
                Text(timeAgo(ticket.created), style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500)),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, size: 14, color: AppColors.slate600),
              ],
            ),

            // SLA warning for urgent open tickets
            if (isUrgent && ticket.status == TicketStatus.open) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.red500.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red500.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.red400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Requires response within ${urgencySla(ticket.urgency)} — Safety hazard',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.red400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // REPORT ISSUE FAB
  // ─────────────────────────────────
  Widget _buildReportButton() {
    return Positioned(
      bottom: 32,
      left: 24,
      right: 24,
      child: GestureDetector(
        onTap: () async {
          final result = await context.push<bool>('/maintenance/create');
          if (result == true && mounted) {
            setState(() {});
          }
        },
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.indigo500,
                    AppColors.indigo500.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo500.withValues(alpha: 0.25 + _pulseController.value * 0.1),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.plus, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'REPORT ISSUE',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
