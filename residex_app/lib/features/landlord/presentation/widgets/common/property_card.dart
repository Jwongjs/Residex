import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';

/// Property card for portfolio screen
/// 
/// Displays:
/// - Property name and address
/// - Property type
/// - Occupancy rate and unit counts
/// - Current value
class PropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onEdit,
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
                  // Header: Icon, name, and occupancy badge
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
                          _getPropertyIcon(property.type),
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
                              property.name,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${property.address.city}, ${property.address.state}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Occupancy badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: property.isFullyOccupied
                              ? AppColors.success.withOpacity(0.1)
                              : property.hasVacancy
                                  ? AppColors.warning.withOpacity(0.1)
                                  : AppColors.slate800,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: property.isFullyOccupied
                                ? AppColors.success.withOpacity(0.2)
                                : property.hasVacancy
                                    ? AppColors.warning.withOpacity(0.2)
                                    : AppColors.slate700,
                          ),
                        ),
                        child: Text(
                          '${property.occupancyRate.toStringAsFixed(0)}%',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10,
                            color: property.isFullyOccupied
                                ? AppColors.success
                                : property.hasVacancy
                                    ? AppColors.warning
                                    : AppColors.textMuted,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      if (onEdit != null) ...[
                        const SizedBox(width: 8),
                        // Edit property affordance
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Property details
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
                        // Units info
                        _buildInfoChip(
                          icon: Icons.home_work_outlined,
                          label: '${property.occupiedUnits}/${property.totalUnits} Units',
                          color: AppColors.primary,
                        ),

                        // Property type
                        _buildInfoChip(
                          icon: Icons.category_outlined,
                          label: property.type.displayName,
                          color: AppColors.cyan400,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  IconData _getPropertyIcon(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return Icons.apartment;
      case PropertyType.house:
        return Icons.house_outlined;
      case PropertyType.condo:
        return Icons.domain;
      case PropertyType.commercial:
        return Icons.business;
    }
  }
}