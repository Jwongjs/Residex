import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../shared/presentation/providers/auth_providers.dart';
import '../../providers/property_providers.dart';
import '../../providers/documind_provider.dart';
import '../../providers/upcoming_expiries.dart';
import '../../../domain/entities/property.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/widgets/residex_logo.dart';

class LandlordDashboardScreen extends ConsumerWidget {
  final VoidCallback onOpenDocumind;
  final VoidCallback onOpenPortfolio;

  const LandlordDashboardScreen({
    super.key,
    required this.onOpenDocumind,
    required this.onOpenPortfolio,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ResidexLogo(size: 30, animate: false),
            const SizedBox(width: 10),
            Text('ResiDex', style: AppTextStyles.headlineMedium),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout_outlined, color: AppColors.ink),
            tooltip: 'Sign out',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: propertiesAsync.when(
        data: (properties) => _buildContent(context, ref, properties),
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.registry)),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Couldn't load your properties. Check your connection and try again.",
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Sign out?', style: AppTextStyles.headlineMedium),
        content: Text(
          'You can sign back in anytime.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    AppTextStyles.labelLarge.copyWith(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sealRed),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Clear the dev bypass first so the router redirect doesn't short-circuit,
    // then sign out of Firebase (harmless no-op for bypass-only sessions).
    ref.read(devBypassProvider.notifier).clear();
    try {
      await ref.read(authControllerProvider).signOut();
    } catch (_) {
      // Firebase sign-out can fail offline; local session is cleared either way.
    }
    if (context.mounted) context.go(AppRoutes.login);
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<Property> properties) {
    if (properties.isEmpty) {
      return _buildEmptyState(context);
    }

    final statsAsync = ref.watch(portfolioStatsProvider);
    final visibleProperties = properties.take(3).toList();

    return statsAsync.when(
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(), style: AppTextStyles.displayMedium),
            const SizedBox(height: 4),
            Text(
              '${properties.length} propert${properties.length == 1 ? 'y' : 'ies'} on file',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 20),
            _buildStatTileRow(stats),
            _buildExpiryTile(context, ref),
            const SizedBox(height: 20),
            _buildDocumindEntryCard(context),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child:
                      Text('Your properties', style: AppTextStyles.titleLarge),
                ),
                TextButton(
                  onPressed: onOpenPortfolio,
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.registry),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...visibleProperties.map((p) => _buildPropertyRow(context, p)),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Failed to load portfolio stats')),
    );
  }

  Widget _buildStatTileRow(PortfolioStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            label: 'PROPERTIES',
            value: stats.totalProperties.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatTile(
            label: 'OCCUPANCY',
            value: '${stats.averageOccupancyRate.toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.displayMedium),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryTile(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(upcomingExpiriesProvider).value ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();
    final today = DateTime.now();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPCOMING EXPIRIES',
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          ...entries.take(3).map((entry) {
            final days = daysUntil(entry.date, today);
            final urgency = days <= 30
                ? AppColors.error
                : days <= 60
                    ? AppColors.catUpkeep
                    : AppColors.ink;
            final scope = entry.unitLabel ?? 'Property-wide';
            return InkWell(
              onTap: () {
                ref.read(documindNavTargetProvider.notifier).state =
                    entry.propertyId;
                onOpenDocumind();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      entry.category == 'lease'
                          ? Icons.description_outlined
                          : Icons.security_outlined,
                      size: 18,
                      color: urgency,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$scope · ${entry.kind} ${formatExpiryDate(entry.date)}',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      days == 0 ? 'today' : 'in $days days',
                      style:
                          AppTextStyles.labelSmall.copyWith(color: urgency),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumindEntryCard(BuildContext context) {
    return GestureDetector(
      onTap: onOpenDocumind,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.registry,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask Documind',
                    style:
                        AppTextStyles.titleLarge.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Get answers from your leases, warranties, and bills.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyRow(BuildContext context, Property property) {
    return GestureDetector(
      onTap: onOpenPortfolio,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: CardDecoration.flat,
        child: Row(
          children: [
            const Icon(Icons.home_work_outlined,
                color: AppColors.registry, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(property.name, style: AppTextStyles.titleMedium),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No properties yet', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your first property to start filing its documents.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onOpenPortfolio,
              child: const Text('Add a property'),
            ),
          ],
        ),
      ),
    );
  }
}
