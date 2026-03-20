// lib/features/landlord/domain/entities/maintenance_request.dart

/// Maintenance request priority level
enum MaintenancePriority {
  low,
  medium,
  high,
  urgent,
}

/// Maintenance request status
enum MaintenanceStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

/// Maintenance request category
enum MaintenanceCategory {
  plumbing,
  electrical,
  hvac,
  appliance,
  structural,
  pest,
  other,
}

/// Pure business object - Maintenance Request entity
class MaintenanceRequest {
  final String id;
  final String propertyId;
  final String tenantId;
  final String title;
  final String description;
  final MaintenanceCategory category;
  final MaintenancePriority priority;
  final MaintenanceStatus status;
  final double? estimatedCost;
  final double? actualCost;
  final DateTime requestedAt;
  final DateTime? completedAt;

  MaintenanceRequest({
    required this.id,
    required this.propertyId,
    required this.tenantId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.estimatedCost,
    this.actualCost,
    required this.requestedAt,
    this.completedAt,
  });

  /// Check if request is overdue (pending for more than 7 days)
  bool get isOverdue {
    if (status != MaintenanceStatus.pending) return false;
    final daysSinceRequest = DateTime.now().difference(requestedAt).inDays;
    return daysSinceRequest > 7;
  }

  /// Check if urgent
  bool get isUrgent => priority == MaintenancePriority.urgent;

  /// Check if completed
  bool get isCompleted => status == MaintenanceStatus.completed;

  /// Days since request was made
  int get daysSinceRequest {
    return DateTime.now().difference(requestedAt).inDays;
  }

  MaintenanceRequest copyWith({
    String? id,
    String? propertyId,
    String? tenantId,
    String? title,
    String? description,
    MaintenanceCategory? category,
    MaintenancePriority? priority,
    MaintenanceStatus? status,
    double? estimatedCost,
    double? actualCost,
    DateTime? requestedAt,
    DateTime? completedAt,
  }) {
    return MaintenanceRequest(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      requestedAt: requestedAt ?? this.requestedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}