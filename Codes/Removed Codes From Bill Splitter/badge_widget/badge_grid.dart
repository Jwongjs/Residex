import 'package:flutter/material.dart';
  import '../../../features/gamification/domain/entities/badge_enums.dart';
  import 'badge_widget.dart';
  import 'badge_showcase.dart';

  class BadgeGridItem {
    final BadgeType type;
    final TrophyTier tier;
    final String title;
    final String description;
    final double? rarityPercent;
    final bool isUnlocked;

    const BadgeGridItem({
      required this.type,
      required this.tier,
      required this.title,
      required this.description,
      this.rarityPercent,
      this.isUnlocked = true,
    });
  }

  class BadgeGrid extends StatelessWidget {
    final List<BadgeGridItem> badges;
    final int crossAxisCount;
    final double spacing;

    const BadgeGrid({
      Key? key,
      required this.badges,
      this.crossAxisCount = 3,
      this.spacing = 16.0,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 0.85,
        ),
        itemCount: badges.length,
        itemBuilder: (context, index) {
          final badge = badges[index];

          return RepaintBoundary(
            child: GestureDetector(
              onTap: () {
                if (badge.isUnlocked) {
                  showBadgeShowcase(
                    context: context,
                    type: badge.type,
                    tier: badge.tier,
                    title: badge.title,
                    description: badge.description,
                    rarityPercent: badge.rarityPercent,
                  );
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: badge.isUnlocked ? 1.0 : 0.3,
                    child: BadgeWidget(
                      type: badge.type,
                      tier: badge.tier,
                      size: BadgeSize.md,
                      enableAnimations: badge.isUnlocked,
                      rarityPercent: badge.rarityPercent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badge.isUnlocked ? Colors.white : Colors.white38,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }