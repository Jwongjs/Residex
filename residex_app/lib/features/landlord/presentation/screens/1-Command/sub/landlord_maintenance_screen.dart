import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../widgets/layouts/ambient_background.dart';
import 'maintenance_ticket_detail_screen.dart';

/// Ticket Status Types
enum TicketStatus {
  open,
  acknowledged,
  scheduled,
  inProgress,
  resolved,
  closed,
}

/// Ticket Urgency Levels
enum TicketUrgency {
  urgent,
  high,
  medium,
  low,
}

/// Ticket Category
enum TicketCategory {
  plumbing,
  acHeating,
  electrical,
  appliance,
  structural,
  other,
}

/// Timeline Event
class TimelineEvent {
  final String id;
  final DateTime timestamp;
  final String action;
  final String actor;
  final String? details;
  final bool isEscalation;

  TimelineEvent({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.actor,
    this.details,
    this.isEscalation = false,
  });
}

/// Maintenance Ticket Model
class MaintenanceTicket {
  final String id;
  final String title;
  final String description;
  final TicketCategory category;
  final TicketUrgency urgency;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String tenantId;
  final String unitId;
  final List<String> images;
  final List<TimelineEvent> timeline;
  final DateTime slaDeadline;

  MaintenanceTicket({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.tenantId,
    required this.unitId,
    required this.images,
    required this.timeline,
    required this.slaDeadline,
  });

  MaintenanceTicket copyWith({
    TicketStatus? status,
    List<TimelineEvent>? timeline,
  }) {
    return MaintenanceTicket(
      id: id,
      title: title,
      description: description,
      category: category,
      urgency: urgency,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      tenantId: tenantId,
      unitId: unitId,
      images: images,
      timeline: timeline ?? this.timeline,
      slaDeadline: slaDeadline,
    );
  }

  Duration get timeUntilSLA => slaDeadline.difference(DateTime.now());
  
  bool get isSLABreached => DateTime.now().isAfter(slaDeadline);
  
  String get slaFormatted {
    final duration = timeUntilSLA;
    if (isSLABreached) {
      return 'SLA Breached ${duration.abs().inHours}h ago';
    }
    if (duration.inHours < 24) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m Left';
    }
    return '${duration.inDays}d ${duration.inHours % 24}h Left';
  }
}

/// Mock Tickets Provider
final maintenanceTicketsProvider = Provider<List<MaintenanceTicket>>((ref) {
  return [
    MaintenanceTicket(
      id: 'K-2025-1027-001',
      title: 'Leaking Sink',
      description: 'Water leaking profusely from the u-trap under the master bathroom sink.',
      category: TicketCategory.plumbing,
      urgency: TicketUrgency.high,
      status: TicketStatus.open,
      createdAt: DateTime(2025, 10, 27, 9, 0),
      updatedAt: DateTime(2025, 10, 27, 9, 0),
      tenantId: 'u1',
      unitId: 'Unit 4-2',
      images: [],
      timeline: [
        TimelineEvent(
          id: 'e1',
          timestamp: DateTime(2025, 10, 27, 9, 0),
          action: 'Ticket Created',
          actor: 'Ali Rahman',
          details: 'Evidence uploaded.',
        ),
        TimelineEvent(
          id: 'e2',
          timestamp: DateTime(2025, 10, 27, 9, 5),
          action: 'System Acknowledged',
          actor: 'Rex AI',
          details: 'High urgency detected. Notification sent to Landlord.',
        ),
      ],
      slaDeadline: DateTime(2025, 10, 29, 9, 0),
    ),
    MaintenanceTicket(
      id: 'K-2025-1025-042',
      title: 'AC Not Cooling',
      description: 'Master bedroom AC blowing warm air.',
      category: TicketCategory.acHeating,
      urgency: TicketUrgency.medium,
      status: TicketStatus.scheduled,
      createdAt: DateTime(2025, 10, 25, 14, 30),
      updatedAt: DateTime(2025, 10, 26, 10, 0),
      tenantId: 'u1',
      unitId: 'Unit 4-2',
      images: [],
      timeline: [
        TimelineEvent(
          id: 'e1',
          timestamp: DateTime(2025, 10, 25, 14, 30),
          action: 'Ticket Created',
          actor: 'Ali Rahman',
        ),
        TimelineEvent(
          id: 'e2',
          timestamp: DateTime(2025, 10, 25, 18, 0),
          action: 'Viewed',
          actor: 'Landlord',
        ),
        TimelineEvent(
          id: 'e3',
          timestamp: DateTime(2025, 10, 26, 10, 0),
          action: 'Repair Scheduled',
          actor: 'Landlord',
          details: 'Technician arriving 28 Oct 2pm.',
        ),
      ],
      slaDeadline: DateTime(2025, 11, 1, 14, 30),
    ),
  ];
});

/// Landlord Maintenance Manager Screen - "Escalation Console"
class LandlordMaintenanceScreen extends ConsumerWidget {
  const LandlordMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(maintenanceTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MAINTENANCE',
              style: AppTextStyles.heading2.copyWith(
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            Text(
              'ESCALATION CONSOLE',
              style: AppTextStyles.label.copyWith(
                fontSize: 9,
                color: AppColors.textMuted,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Ambient background
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
                    AppColors.primary.withOpacity(0.4),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Ticket list
          ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return _buildTicketCard(context, ref, ticket);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, WidgetRef ref, MaintenanceTicket ticket) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaintenanceTicketDetailScreen(ticket: ticket),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withOpacity(0.8),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Icon
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: _getStatusColor(ticket.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Icon(
                    Icons.build,
                    color: _getStatusColor(ticket.status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Title & unit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        ticket.unitId,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Urgency badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getUrgencyBadgeColor(ticket.urgency),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getUrgencyColor(ticket.urgency).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    ticket.urgency.name.toUpperCase(),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 9,
                      color: _getUrgencyColor(ticket.urgency),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'STATUS',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  ticket.status.name.toUpperCase().replaceAll('_', ' '),
                  style: AppTextStyles.label.copyWith(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _getStatusProgress(ticket.status),
                backgroundColor: AppColors.slate800,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressBarColor(ticket.urgency),
                ),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 12),

            // Bottom row - SLA & arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: ticket.isSLABreached 
                          ? AppColors.error 
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SLA: ${ticket.slaFormatted}',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 9,
                        color: ticket.isSLABreached 
                            ? AppColors.error 
                            : AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return AppColors.error;
      case TicketStatus.acknowledged:
        return AppColors.warning;
      case TicketStatus.scheduled:
        return AppColors.primary;
      case TicketStatus.inProgress:
        return AppColors.purple;
      case TicketStatus.resolved:
        return AppColors.success;
      case TicketStatus.closed:
        return AppColors.textMuted;
    }
  }

  Color _getUrgencyColor(TicketUrgency urgency) {
    switch (urgency) {
      case TicketUrgency.urgent:
        return AppColors.error;
      case TicketUrgency.high:
        return AppColors.orange;
      case TicketUrgency.medium:
        return AppColors.primary;
      case TicketUrgency.low:
        return AppColors.textMuted;
    }
  }

  Color _getUrgencyBadgeColor(TicketUrgency urgency) {
    switch (urgency) {
      case TicketUrgency.urgent:
      case TicketUrgency.high:
        return AppColors.error.withOpacity(0.2);
      default:
        return AppColors.slate800;
    }
  }

  Color _getProgressBarColor(TicketUrgency urgency) {
    switch (urgency) {
      case TicketUrgency.urgent:
      case TicketUrgency.high:
        return AppColors.orange;
      default:
        return AppColors.primary;
    }
  }

  double _getStatusProgress(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 0.25;
      case TicketStatus.acknowledged:
        return 0.40;
      case TicketStatus.scheduled:
        return 0.50;
      case TicketStatus.inProgress:
        return 0.75;
      case TicketStatus.resolved:
      case TicketStatus.closed:
        return 1.0;
    }
  }
}
