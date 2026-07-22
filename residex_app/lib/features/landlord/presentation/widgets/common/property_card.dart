import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../domain/entities/property.dart';
import '../../providers/finance_logic.dart';
import '../../providers/finance_providers.dart';
import '../../providers/unit_providers.dart';
import 'registration_document_steps_sheet.dart';

/// Property card for portfolio screen
///
/// Displays:
/// - Property name and address
/// - Property type
/// - Occupancy rate and unit counts (derived from the property's units)
/// - Current value
class PropertyCard extends ConsumerWidget {
  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsForPropertyStreamProvider(property.id));
    final totalUnits = unitsAsync.value?.length ?? 0;
    final occupiedUnits = unitsAsync.value?.where((u) => u.isOccupied).length ?? 0;
    final occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0.0;
    final isFullyOccupied = totalUnits > 0 && occupiedUnits == totalUnits;
    final hasVacancy = occupiedUnits < totalUnits;

    final year = DateTime.now().year;
    final summaryAsync = ref.watch(financeSummaryProvider(year));
    final block = summaryAsync.value?.properties
        .where((p) => p.propertyId == property.id)
        .toList();
    final yearRow = block != null && block.isNotEmpty
        ? yearCoverageFor(block.first.coverage, year)
        : null;
    final completeness = (block != null && block.isNotEmpty && yearRow != null)
        ? yearCompleteness(yearRow, block.first.expectedCategories)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShadows.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
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
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Icon(
                          _getPropertyIcon(property.type),
                          size: 20,
                          color: AppColors.registry,
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
                          color: isFullyOccupied
                              ? AppColors.success.withOpacity(0.1)
                              : hasVacancy
                                  ? AppColors.warning.withOpacity(0.1)
                                  : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFullyOccupied
                                ? AppColors.success.withOpacity(0.2)
                                : hasVacancy
                                    ? AppColors.warning.withOpacity(0.2)
                                    : AppColors.hairline,
                          ),
                        ),
                        child: Text(
                          '${occupancyRate.toStringAsFixed(0)}%',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10,
                            color: isFullyOccupied
                                ? AppColors.success
                                : hasVacancy
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

                      if (onDelete != null) ...[
                        const SizedBox(width: 4),
                        // Delete property affordance
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.error,
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
                        top: BorderSide(color: AppColors.hairline),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Units info
                        _buildInfoChip(
                          icon: Icons.home_work_outlined,
                          label: '$occupiedUnits/$totalUnits Units',
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
                  if (completeness != null && completeness.expect > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      '$year: ${completeness.have} of ${completeness.expect}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                  if (property.nextSetupStep != 0) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showRegistrationDocumentSteps(
                          context,
                          property: property,
                          startAtStep: property.nextSetupStep,
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Continue setup'),
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