import 'package:flutter/material.dart';
import 'core/widgets/badge_widget/badge_widget_exports.dart';

  class TestBadgeScreen extends StatelessWidget {
    const TestBadgeScreen({Key? key}) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Badge Widget Test'),
          backgroundColor: Colors.grey[900],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTierSection('Bronze Tier', TrophyTier.bronze),
              const SizedBox(height: 40),
              _buildTierSection('Silver Tier', TrophyTier.silver),
              const SizedBox(height: 40),
              _buildTierSection('Gold Tier (with sparkles)', TrophyTier.gold),
              const SizedBox(height: 40),
              _buildTierSection('Platinum Tier (with sparkles)', TrophyTier.platinum),
              const SizedBox(height: 40),
              _buildSizeSection(),
            ],
          ),
        ),
      );
    }

    Widget _buildTierSection(String title, TrophyTier tier) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildBadgeColumn('Shield', BadgeType.shield, tier),
              _buildBadgeColumn('Lightning', BadgeType.lightning, tier),
              _buildBadgeColumn('Diamond', BadgeType.diamond, tier),
              _buildBadgeColumn('Star', BadgeType.star, tier),
              _buildBadgeColumn('Trophy', BadgeType.trophy, tier),
            ],
          ),
        ],
      );
    }

    Widget _buildBadgeColumn(String label, BadgeType type, TrophyTier tier) {
      return Column(
        children: [
          BadgeWidget(
            type: type,
            tier: tier,
            size: BadgeSize.lg,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      );
    }

    Widget _buildSizeSection() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Size Variations (Gold Star)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildSizeColumn('Small', BadgeSize.sm),
              _buildSizeColumn('Medium', BadgeSize.md),
              _buildSizeColumn('Large', BadgeSize.lg),
              _buildSizeColumn('XL', BadgeSize.xl),
            ],
          ),
        ],
      );
    }

    Widget _buildSizeColumn(String label, BadgeSize size) {
      return Column(
        children: [
          BadgeWidget(
            type: BadgeType.star,
            tier: TrophyTier.gold,
            size: size,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      );
    }
  }