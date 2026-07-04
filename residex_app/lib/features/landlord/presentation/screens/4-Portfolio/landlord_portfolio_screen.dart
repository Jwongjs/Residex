import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../providers/property_providers.dart';
import '../../widgets/common/property_card.dart';
import '../../widgets/common/add_property_dialog.dart';

class LandlordPortfolioScreen extends ConsumerStatefulWidget {
  const LandlordPortfolioScreen({super.key});

  @override
  ConsumerState<LandlordPortfolioScreen> createState() =>
      _LandlordPortfolioScreenState();
}

class _LandlordPortfolioScreenState
    extends ConsumerState<LandlordPortfolioScreen> {
  
  bool _isFilterExpanded = false;

  Future<void> _showAddPropertyDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddPropertyDialog(),
    );

    if (result == true && mounted) {
      // Property was added successfully, stream will auto-update
    }
  }

  Future<void> _showEditPropertyDialog(Property property) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddPropertyDialog(property: property),
    );

    if (result == true && mounted) {
      // Property was updated successfully, stream will auto-update
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(filteredPropertiesProvider);
    final portfolioStats = ref.watch(portfolioStatsProvider);
    final currentFilter = ref.watch(propertyFilterProvider);

    // Filter button labels
    String filterLabel = switch (currentFilter) {
      PropertyFilter.all => 'All Properties',
      PropertyFilter.fullyOccupied => 'Fully Occupied',
      PropertyFilter.hasVacancy => 'Has Vacancy',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient background gradient (FIXED: Now stays in place)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.8),
                radius: 1.2,
                colors: [
                  AppColors.primaryCyan.withOpacity(0.15),
                  AppColors.background,
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  snap: true,
                  automaticallyImplyLeading: false,
                  expandedHeight: 88,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      // Prevent overflow during collapse animation
                      final showSubtitle = constraints.maxHeight >= 44;

                      return FlexibleSpaceBar(
                        background: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 38, 24, 8),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MY PORTFOLIO',
                                  style: AppTextStyles.displayMedium.copyWith(
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (showSubtitle) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${portfolioStats.totalProperties} PROPERTIES • ${portfolioStats.averageOccupancyRate.toStringAsFixed(0)}% OCCUPIED',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textMuted,
                                      letterSpacing: 1.5,
                                      fontSize: 9,
                                      height: 1.0,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Portfolio stats cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildStatsCards(portfolioStats),
                  ),
                ),

                // Filter chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'PROPERTIES',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.textMuted,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            // Filter dropdown button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isFilterExpanded = !_isFilterExpanded;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.filter_list,
                                      size: 16,
                                      color: AppColors.primaryCyan,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      filterLabel,
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _isFilterExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Filter options (expandable)
                        if (_isFilterExpanded) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterChip(
                                'All',
                                PropertyFilter.all,
                                currentFilter,
                              ),
                              _buildFilterChip(
                                'Fully Occupied',
                                PropertyFilter.fullyOccupied,
                                currentFilter,
                              ),
                              _buildFilterChip(
                                'Has Vacancy',
                                PropertyFilter.hasVacancy,
                                currentFilter,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Properties grid
                propertiesAsync.when(
                  data: (properties) {
                    if (properties.isEmpty) {
                      return SliverFillRemaining(
                        child: _buildEmptyState(),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: PropertyCard(
                                key: ValueKey('property_${properties[index].id}'),
                                property: properties[index],
                                onEdit: () => _showEditPropertyDialog(properties[index]),
                              ),
                            );
                          },
                          childCount: properties.length,
                        ),
                      ),
                    );
                  },
                  loading: () => SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primaryCyan,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading properties...',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  error: (error, stack) {
                    final errorMessage = error.toString();
                    final isIndexError = errorMessage.contains('index') || 
                                       errorMessage.contains('FAILED_PRECONDITION');
                    
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isIndexError ? Icons.cloud_sync : Icons.error_outline,
                                size: 48,
                                color: isIndexError ? AppColors.warning : AppColors.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isIndexError 
                                    ? 'Database Index Required'
                                    : 'Error loading properties',
                                style: AppTextStyles.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              if (isIndexError) ...[
                                Text(
                                  'Firestore needs a composite index to query properties.',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 20,
                                            color: AppColors.info,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Quick Fix:',
                                            style: AppTextStyles.titleMedium,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildStepItem('1', 'Look for the Firebase Console link in your terminal/debug console'),
                                      _buildStepItem('2', 'Click the link to create the index'),
                                      _buildStepItem('3', 'Wait 2-3 minutes for index to build'),
                                      _buildStepItem('4', 'Refresh this page'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    ref.invalidate(propertiesStreamProvider);
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryCyan,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  errorMessage,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.error,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    ref.invalidate(propertiesStreamProvider);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Add Property FAB
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: _showAddPropertyDialog,
              backgroundColor: AppColors.primaryCyan,
              heroTag: 'add_property_fab',
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add Property',
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryCyan),
            ),
            child: Center(
              child: Text(
                number,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(PortfolioStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.maps_home_work_outlined,
            label: 'TOTAL UNITS',
            value: stats.totalUnits.toString(),
            subtitle: '${stats.occupiedUnits} occupied',
            gradient: LinearGradient(
              colors: [
                AppColors.primaryCyan.withOpacity(0.2),
                AppColors.primaryBlue.withOpacity(0.1),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            label: 'OCCUPANCY',
            value: '${stats.averageOccupancyRate.toStringAsFixed(0)}%',
            subtitle: stats.fullyOccupiedProperties > 0
                ? '${stats.fullyOccupiedProperties} full'
                : '${stats.vacantProperties} vacant',
            gradient: LinearGradient(
              colors: [
                AppColors.success.withOpacity(0.2),
                AppColors.emerald.withOpacity(0.1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.displayMedium.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    PropertyFilter filter,
    PropertyFilter currentFilter,
  ) {
    final isSelected = filter == currentFilter;
    return GestureDetector(
      onTap: () {
        ref.read(propertyFilterProvider.notifier).setFilter(filter);
        setState(() {
          _isFilterExpanded = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryCyan.withOpacity(0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryCyan
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? AppColors.primaryCyan : AppColors.textMuted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Icon(
              Icons.business_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Properties Yet',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first property to get started',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}