import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/landlord_portfolio_provider.dart';
import '../../widgets/common/property_card.dart';
import '../../widgets/common/stat_card.dart';
import 'sub/tenant_list_screen.dart';

/// Landlord Portfolio Screen - Property Management
/// 
/// Features:
/// - Portfolio statistics overview
/// - Property list with occupancy status
/// - Add property button
/// - Filter by status (All, Occupied, Vacant)
class LandlordPortfolioScreen extends ConsumerStatefulWidget {
  const LandlordPortfolioScreen({super.key});

  @override
  ConsumerState<LandlordPortfolioScreen> createState() => _LandlordPortfolioScreenState();
}

class _LandlordPortfolioScreenState extends ConsumerState<LandlordPortfolioScreen> {
  PropertyFilter _currentFilter = PropertyFilter.all;

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(portfolioPropertiesProvider);
    final stats = ref.watch(portfolioStatsProvider);

    // Filter properties based on selected filter
    final filteredProperties = properties.where((property) {
      switch (_currentFilter) {
        case PropertyFilter.occupied:
          return property.status == PropertyStatus.occupied;
        case PropertyFilter.vacant:
          return property.status == PropertyStatus.vacant;
        case PropertyFilter.all:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient background gradient
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
                    AppColors.primary.withOpacity(0.3),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Stats Grid
                      _buildStatsGrid(stats),

                      const SizedBox(height: 32),

                      // Filter bar and property count
                      _buildFilterBar(filteredProperties.length),

                      const SizedBox(height: 16),

                      // Property list
                      ...filteredProperties.map((property) => PropertyCard(
                        propertyName: property.name,
                        unitNumber: property.unitNumber,
                        status: property.status,
                        tenantName: property.tenantName,
                        rentStatus: property.rentStatus,
                        onTap: () {
                          // TODO: Navigate to property details
                          _showPropertyDetails(context, property);
                        },
                      )),

                      // Empty state
                      if (filteredProperties.isEmpty)
                        _buildEmptyState(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildAddPropertyButton(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Icon(
              Icons.business,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asset Portfolio',
                  style: AppTextStyles.heading2.copyWith(
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'PROPERTY MANAGEMENT',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary.withOpacity(0.8),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          // Tenant Directory button
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TenantListScreen(),
                ),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.people_outline,
                color: AppColors.success,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(PortfolioStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        StatCard(
          title: 'Total Units',
          value: '${stats.totalProperties}',
          badge: 'Properties',
          badgeIcon: Icons.apartment,
          gradientColor: AppColors.primary,
        ),
        StatCard(
          title: 'Occupied',
          value: '${stats.occupiedUnits}',
          badge: '${stats.occupancyRate.toStringAsFixed(0)}%',
          badgeIcon: Icons.check_circle,
          gradientColor: AppColors.success,
        ),
        StatCard(
          title: 'Vacant',
          value: '${stats.vacantUnits}',
          badge: 'Available',
          badgeIcon: Icons.home_outlined,
          gradientColor: AppColors.slate700,
        ),
        StatCard(
          title: 'Revenue',
          value: 'RM ${(stats.totalMonthlyRevenue / 1000).toStringAsFixed(1)}k',
          badge: 'Monthly',
          badgeIcon: Icons.attach_money,
          gradientColor: AppColors.primaryCyan,
        ),
      ],
    );
  }

  Widget _buildFilterBar(int propertyCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Section title with count
        Row(
          children: [
            Text(
              'PROPERTIES',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$propertyCount',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        // Filter chips
        Row(
          children: [
            _buildFilterChip('All', PropertyFilter.all),
            const SizedBox(width: 8),
            _buildFilterChip('Occupied', PropertyFilter.occupied),
            const SizedBox(width: 8),
            _buildFilterChip('Vacant', PropertyFilter.vacant),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, PropertyFilter filter) {
    final isActive = _currentFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            fontSize: 10,
            color: isActive ? AppColors.primary : AppColors.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 64,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Properties Found',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first property to get started',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPropertyButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        // TODO: Navigate to add property form
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add Property - Coming Soon')),
        );
      },
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add, size: 20),
      label: Text(
        'Add Unit',
        style: AppTextStyles.label.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    );
  }

  void _showPropertyDetails(BuildContext context, Property property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Property name
            Text(
              property.name,
              style: AppTextStyles.heading2,
            ),

            const SizedBox(height: 8),

            Text(
              '${property.unitNumber} • ${property.address}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 24),

            // Property details
            _buildDetailRow('Monthly Rent', 'RM ${property.monthlyRent.toStringAsFixed(2)}'),
            if (property.tenantName != null)
              _buildDetailRow('Current Tenant', property.tenantName!),
            if (property.rentStatus != null)
              _buildDetailRow(
                'Payment Status',
                property.rentStatus == RentStatus.paid ? 'Paid' : 'Pending',
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Navigate to property edit
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Navigate to property details
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View Full'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Property filter options
enum PropertyFilter {
  all,
  occupied,
  vacant,
}