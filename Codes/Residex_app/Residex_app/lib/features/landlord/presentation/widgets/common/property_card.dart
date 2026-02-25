import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Property card for portfolio screen
/// 
/// Displays:
/// - Property name and unit number
/// - Occupancy status (Occupied/Vacant)
/// - Tenant info (if occupied)
/// - Rent payment status
class PropertyCard extends StatelessWidget {
  final String propertyName;
  final String unitNumber;
  final PropertyStatus status;
  final String? tenantName;
  final RentStatus? rentStatus;
  final VoidCallback? onTap;

  const PropertyCard({
    super.key,
    required this.propertyName,
    required this.unitNumber,
    required this.status,
    this.tenantName,
    this.rentStatus,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Icon, name, and status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Property icon
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppColors.slate800,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.apartment,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Property info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              propertyName,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              unitNumber,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: status == PropertyStatus.occupied
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.slate800,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: status == PropertyStatus.occupied
                                ? AppColors.success.withOpacity(0.2)
                                : AppColors.slate700,
                          ),
                        ),
                        child: Text(
                          status == PropertyStatus.occupied ? 'OCCUPIED' : 'VACANT',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 9,
                            color: status == PropertyStatus.occupied
                                ? AppColors.success
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Tenant info (only for occupied properties)
                  if (status == PropertyStatus.occupied && tenantName != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Tenant avatar and name
                          Row(
                            children: [
                              Container(
                                height: 24,
                                width: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.slate700,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.slate600,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitials(tenantName!),
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tenantName!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          // Rent status
                          if (rentStatus != null)
                            Text(
                              'Rent: ${rentStatus == RentStatus.paid ? 'PAID' : 'PENDING'}',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 9,
                                color: rentStatus == RentStatus.paid
                                    ? AppColors.primary
                                    : AppColors.warning,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }
}

/// Property occupancy status
enum PropertyStatus {
  occupied,
  vacant,
  maintenance,
}

/// Rent payment status
enum RentStatus {
  paid,
  pending,
  overdue,
}