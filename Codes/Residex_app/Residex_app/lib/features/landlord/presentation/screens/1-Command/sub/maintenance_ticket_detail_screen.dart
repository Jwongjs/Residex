import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import 'landlord_maintenance_screen.dart';
import 'landlord_rating_modal.dart';

/// Maintenance Ticket Detail Screen
class MaintenanceTicketDetailScreen extends ConsumerStatefulWidget {
  final MaintenanceTicket ticket;

  const MaintenanceTicketDetailScreen({
    super.key,
    required this.ticket,
  });

  @override
  ConsumerState<MaintenanceTicketDetailScreen> createState() =>
      _MaintenanceTicketDetailScreenState();
}

class _MaintenanceTicketDetailScreenState
    extends ConsumerState<MaintenanceTicketDetailScreen> {
  late MaintenanceTicket _ticket;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.95),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _ticket.id,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_ticket.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getStatusColor(_ticket.status).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    _ticket.status.name.toUpperCase().replaceAll('_', ' '),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 8,
                      color: _getStatusColor(_ticket.status),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            children: [
              // Title section
              _buildTitleSection(),

              const SizedBox(height: 32),

              // SLA Monitor
              _buildSLAMonitor(),

              const SizedBox(height: 32),

              // Timeline
              _buildTimeline(),
            ],
          ),

          // Bottom actions
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Urgency indicator
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getUrgencyColor(_ticket.urgency),
                boxShadow: [
                  BoxShadow(
                    color: _getUrgencyColor(_ticket.urgency),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_ticket.urgency.name.toUpperCase()} PRIORITY',
              style: AppTextStyles.label.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
                letterSpacing: 3,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Title
        Text(
          _ticket.title,
          style: AppTextStyles.displayLarge.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 16),

        // Description
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            _ticket.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.slate300,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSLAMonitor() {
    final isCritical = _ticket.urgency == TicketUrgency.urgent ||
        _ticket.urgency == TicketUrgency.high;

    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.slate800,
            AppColors.slate900,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: _ticket.isSLABreached
                    ? AppColors.error.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _ticket.isSLABreached
                      ? AppColors.error.withOpacity(0.2)
                      : AppColors.warning.withOpacity(0.2),
                ),
              ),
              child: Icon(
                Icons.schedule,
                color: _ticket.isSLABreached
                    ? AppColors.error
                    : AppColors.warning,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // SLA info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SLA COUNTDOWN',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    _ticket.slaFormatted,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: _ticket.isSLABreached
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Escalate button (only for critical tickets)
            if (isCritical)
              ElevatedButton(
                onPressed: _handleEscalate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'ESCALATE',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIMELINE',
          style: AppTextStyles.label.copyWith(
            fontSize: 9,
            color: AppColors.textMuted,
            letterSpacing: 3,
          ),
        ),

        const SizedBox(height: 16),

        ...List.generate(_ticket.timeline.length, (index) {
          final event = _ticket.timeline[index];
          final isLast = index == _ticket.timeline.length - 1;

          return _buildTimelineItem(event, isLast);
        }),
      ],
    );
  }

  Widget _buildTimelineItem(TimelineEvent event, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: event.isEscalation ? AppColors.error : AppColors.slate600,
                border: Border.all(
                  color: AppColors.background,
                  width: 4,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: AppColors.slate800,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),

        const SizedBox(width: 16),

        // Event details
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.action,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: event.isEscalation
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 9,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),

                Text(
                  'by ${event.actor}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),

                if (event.details != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Text(
                      event.details!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.slate300,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppColors.background.withOpacity(0.95),
              AppColors.background,
            ],
          ),
        ),
        child: Row(
          children: [
            // Add Evidence button
            Expanded(
              child: OutlinedButton(
                onPressed: _handleAddEvidence,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: AppColors.slate800,
                ),
                child: Text(
                  'Add Evidence',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate300,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Approve Fix button
            Expanded(
              child: ElevatedButton(
                onPressed: _ticket.status != TicketStatus.resolved
                    ? _handleApproveFix
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _ticket.status != TicketStatus.resolved
                      ? AppColors.success
                      : AppColors.slate800,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.slate800,
                  disabledForegroundColor: AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  shadowColor: AppColors.success.withOpacity(0.4),
                ),
                child: Text(
                  _ticket.status != TicketStatus.resolved
                      ? 'Approve Fix'
                      : 'Closed',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEscalate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Escalate Ticket',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will escalate the ticket to the tribunal system and generate a legal report. Continue?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Add escalation event to timeline
              final escalationEvent = TimelineEvent(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                timestamp: DateTime.now(),
                action: 'ESCALATED',
                actor: 'Landlord',
                details: 'SLA Breached. Report sent to Tribunal.',
                isEscalation: true,
              );

              setState(() {
                _ticket = _ticket.copyWith(
                  timeline: [..._ticket.timeline, escalationEvent],
                );
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Escalation protocol initiated'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
  }

  void _handleAddEvidence() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Evidence upload functionality - Coming soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _handleApproveFix() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LandlordRatingModal(
        ticketTitle: _ticket.title,
        onClose: () => Navigator.pop(context),
        onSubmit: (rating, feedback) {
          Navigator.pop(context);
          
          // Update ticket status
          final completionEvent = TimelineEvent(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            action: 'Work Approved',
            actor: 'Landlord',
            details: 'Rating: $rating/5 - $feedback',
          );

          setState(() {
            _ticket = _ticket.copyWith(
              status: TicketStatus.resolved,
              timeline: [..._ticket.timeline, completionEvent],
            );
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ticket marked as resolved'),
              backgroundColor: AppColors.success,
            ),
          );
        },
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
}
