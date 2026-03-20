import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';
import 'maintenance_list_screen.dart';

class TicketDetailScreen extends StatelessWidget {
  final MockTicket ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final cat = categoryMeta[ticket.category]!;
    final sColor = statusColor(ticket.status);
    final uColor = urgencyColor(ticket.urgency);

    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Background gradient tinted by category color
          Container(
            height: 500,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  cat.color.withValues(alpha: 0.10),
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
                        // Hero card
                        _buildHeroCard(cat, sColor, uColor),
                        const SizedBox(height: 20),

                        // Status timeline
                        _buildTimeline(sColor),
                        const SizedBox(height: 24),

                        // Description
                        _buildSection('DESCRIPTION', ticket.description),
                        const SizedBox(height: 24),

                        // Photos
                        if (ticket.photoCount > 0) ...[
                          _buildPhotosSection(),
                          const SizedBox(height: 24),
                        ],

                        // SLA info
                        _buildSlaCard(uColor),
                        const SizedBox(height: 24),

                        // Comments
                        _buildCommentsSection(),
                        const SizedBox(height: 24),

                        // Actions
                        _buildActions(context),
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
          Text(
            ticket.id,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate400,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // HERO CARD
  // ─────────────────────────────────
  Widget _buildHeroCard(CategoryMeta cat, Color sColor, Color uColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cat.color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: cat.color.withValues(alpha: 0.06), blurRadius: 30),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category + status row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cat.color.withValues(alpha: 0.25)),
                ),
                child: Icon(cat.icon, size: 20, color: cat.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: cat.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reported by ${ticket.reportedBy}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sColor.withValues(alpha: 0.25)),
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
                        boxShadow: [BoxShadow(color: sColor.withValues(alpha: 0.5), blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel(ticket.status),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: sColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            ticket.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // Meta row
          Row(
            children: [
              // Priority
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: uColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: uColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.alertTriangle, size: 12, color: uColor),
                    const SizedBox(width: 4),
                    Text(
                      urgencyLabel(ticket.urgency),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: uColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(LucideIcons.clock, size: 12, color: AppColors.slate500),
              const SizedBox(width: 4),
              Text(
                timeAgo(ticket.created),
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500),
              ),
              if (ticket.photoCount > 0) ...[
                const SizedBox(width: 14),
                Icon(LucideIcons.camera, size: 12, color: AppColors.slate500),
                const SizedBox(width: 4),
                Text('${ticket.photoCount} photos', style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // TIMELINE
  // ─────────────────────────────────
  Widget _buildTimeline(Color sColor) {
    final steps = <_TimelineStep>[
      _TimelineStep('Reported', ticket.created, true),
      if (ticket.acknowledgedAt != null)
        _TimelineStep('Acknowledged', ticket.acknowledgedAt!, true),
      if (ticket.status == TicketStatus.scheduled || ticket.status == TicketStatus.inProgress || ticket.status == TicketStatus.resolved)
        _TimelineStep('Scheduled', ticket.created.add(const Duration(hours: 12)), true),
      if (ticket.status == TicketStatus.inProgress || ticket.status == TicketStatus.resolved)
        _TimelineStep('In Progress', ticket.created.add(const Duration(days: 1)), true),
      if (ticket.status == TicketStatus.resolved)
        _TimelineStep('Resolved', ticket.created.add(const Duration(days: 3)), true),
    ];

    // Add next pending step if not resolved
    if (ticket.status != TicketStatus.resolved) {
      final nextLabel = switch (ticket.status) {
        TicketStatus.open => 'Awaiting Response',
        TicketStatus.acknowledged => 'Pending Schedule',
        TicketStatus.scheduled => 'Work Pending',
        TicketStatus.inProgress => 'Pending Resolution',
        TicketStatus.resolved => '',
      };
      steps.add(_TimelineStep(nextLabel, null, false));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATUS TIMELINE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final isLast = i == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dot and line
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: step.completed ? sColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: step.completed ? sColor : AppColors.slate600,
                          width: 2,
                        ),
                        boxShadow: step.completed
                            ? [BoxShadow(color: sColor.withValues(alpha: 0.4), blurRadius: 6)]
                            : null,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 32,
                        color: step.completed
                            ? sColor.withValues(alpha: 0.3)
                            : AppColors.slate700,
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          step.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: step.completed ? FontWeight.w700 : FontWeight.w500,
                            color: step.completed ? Colors.white : AppColors.slate500,
                          ),
                        ),
                        if (step.time != null)
                          Text(
                            _formatDate(step.time!),
                            style: GoogleFonts.robotoMono(fontSize: 10, color: AppColors.slate500),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.amber500.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PENDING',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.amber500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────
  // DESCRIPTION
  // ─────────────────────────────────
  Widget _buildSection(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // PHOTOS
  // ─────────────────────────────────
  Widget _buildPhotosSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EVIDENCE PHOTOS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.slate500,
                ),
              ),
              Text(
                '${ticket.photoCount} attached',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ticket.photoCount,
              itemBuilder: (context, i) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.slate800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.image, size: 24, color: AppColors.slate500),
                      const SizedBox(height: 4),
                      Text(
                        'Photo ${i + 1}',
                        style: GoogleFonts.inter(fontSize: 9, color: AppColors.slate500),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // SLA CARD
  // ─────────────────────────────────
  Widget _buildSlaCard(Color uColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: uColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: uColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shield, size: 16, color: uColor),
              const SizedBox(width: 8),
              Text(
                'SLA PROTECTION',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: uColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSlaRow('Required response', urgencySla(ticket.urgency), uColor),
          const SizedBox(height: 8),
          _buildSlaRow('Auto-escalation', ticket.status == TicketStatus.open ? 'Active' : 'Not needed', uColor),
          const SizedBox(height: 8),
          _buildSlaRow('Legal timeline', 'Preserved', uColor),
        ],
      ),
    );
  }

  Widget _buildSlaRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  // ─────────────────────────────────
  // COMMENTS
  // ─────────────────────────────────
  Widget _buildCommentsSection() {
    if (ticket.commentCount == 0) return const SizedBox.shrink();

    final mockComments = [
      _MockComment('Landlord', 'I\'ve received your report. Will arrange for a technician to check.', 'L', const Duration(hours: 6)),
      _MockComment('You', 'Thank you. Is there an estimated time for the visit?', 'Y', const Duration(hours: 4)),
      if (ticket.commentCount > 2)
        _MockComment('Landlord', 'Technician confirmed for tomorrow between 2-4 PM. Please ensure someone is home.', 'L', const Duration(hours: 2)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COMMUNICATION',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.slate500,
                ),
              ),
              Text(
                '${ticket.commentCount} messages',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mockComments.map((c) {
            final isUser = c.initial == 'Y';
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.cyan500.withValues(alpha: 0.15)
                          : AppColors.purple500.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isUser
                            ? AppColors.cyan500.withValues(alpha: 0.3)
                            : AppColors.purple500.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        c.initial,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isUser ? AppColors.cyan500 : AppColors.purple500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              c.name,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            Text(
                              '${c.ago.inHours}h ago',
                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.text,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────
  Widget _buildActions(BuildContext context) {
    if (ticket.status == TicketStatus.resolved) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.emerald500.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 32, color: AppColors.emerald500),
            const SizedBox(height: 8),
            Text(
              'ISSUE RESOLVED',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AppColors.emerald500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rate your landlord\'s response',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < 4 ? Icons.star : Icons.star_border,
                    size: 28,
                    color: AppColors.amber500,
                  ),
                );
              }),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.push('/rex-interface', extra: 'maintenance');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cyan500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.bot, size: 16, color: AppColors.cyan500),
                  const SizedBox(width: 8),
                  Text(
                    'ASK REX',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.cyan500,
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
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.orange500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.orange500.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.messageCircle, size: 16, color: AppColors.orange500),
                  const SizedBox(width: 8),
                  Text(
                    'MESSAGE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.orange500,
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

// ─────────────────────────────────
// INTERNAL MODELS
// ─────────────────────────────────

class _TimelineStep {
  final String label;
  final DateTime? time;
  final bool completed;

  const _TimelineStep(this.label, this.time, this.completed);
}

class _MockComment {
  final String name;
  final String text;
  final String initial;
  final Duration ago;

  const _MockComment(this.name, this.text, this.initial, this.ago);
}
