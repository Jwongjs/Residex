import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/property_providers.dart';
import '../../../domain/entities/property.dart';

class LandlordDashboardScreen extends ConsumerWidget {
  final VoidCallback onOpenDocumind;
  final VoidCallback onOpenPortfolio;

  const LandlordDashboardScreen({
    super.key,
    required this.onOpenDocumind,
    required this.onOpenPortfolio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('ResiDex', style: AppTextStyles.headlineMedium),
      ),
      body: propertiesAsync.when(
        data: (properties) => _buildContent(context, properties),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brass)),
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

  Widget _buildContent(BuildContext context, List<Property> properties) {
    if (properties.isEmpty) {
      return _buildEmptyState(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good day', style: AppTextStyles.displayMedium),
          const SizedBox(height: 4),
          Text(
            '${properties.length} propert${properties.length == 1 ? 'y' : 'ies'} on file',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildDocumindEntryCard(context),
          const SizedBox(height: 24),
          Text('Your properties', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          ...properties.map((p) => _buildPropertyRow(context, p)),
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
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brass.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, color: AppColors.brass, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask Documind', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 2),
                  Text('Get answers from your leases, warranties, and bills.', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
            const Icon(Icons.home_work_outlined, color: AppColors.brass, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(property.name, style: AppTextStyles.titleMedium),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
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
            const Icon(Icons.home_work_outlined, size: 48, color: AppColors.textMuted),
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
