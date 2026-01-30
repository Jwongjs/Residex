import 'package:equatable/equatable.dart';
import 'badge_enums.dart';

/// Represents an unlockable achievement/trophy
class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final BadgeType badgeType;
  final TrophyTier tier;
  final double rarityPercent; // 0.1 = 0.1% of users have this
  final int progress;
  final int maxProgress;
  final List<String> rewards;
  final DateTime? unlockedAt;
  final bool isUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.badgeType,
    required this.tier,
    required this.rarityPercent,
    this.progress = 0,
    required this.maxProgress,
    this.rewards = const [],
    this.unlockedAt,
    this.isUnlocked = false,
  });

  Achievement copyWith({
    int? progress,
    DateTime? unlockedAt,
    bool? isUnlocked,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      badgeType: badgeType,
      tier: tier,
      rarityPercent: rarityPercent,
      progress: progress ?? this.progress,
      maxProgress: maxProgress,
      rewards: rewards,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  double get progressPercent => progress / maxProgress;

  String get rarityLabel {
    if (rarityPercent < 1) return 'LEGENDARY';
    if (rarityPercent < 5) return 'EPIC';
    if (rarityPercent < 15) return 'RARE';
    if (rarityPercent < 40) return 'UNCOMMON';
    return 'COMMON';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        progress,
        isUnlocked,
      ];
}

/// Sample achievements for demo purposes
class AchievementsList {
  static final List<Achievement> all = [
    const Achievement(
      id: 'first_split',
      title: 'First Split',
      description: 'Create your first bill split',
      badgeType: BadgeType.star,
      tier: TrophyTier.bronze,
      rarityPercent: 95.0,
      maxProgress: 1,
      rewards: ['+10 Trust Score'],
    ),
    const Achievement(
      id: 'social_butterfly',
      title: 'Social Butterfly',
      description: 'Split bills with 10 different people',
      badgeType: BadgeType.lightning,
      tier: TrophyTier.silver,
      rarityPercent: 35.0,
      maxProgress: 10,
      rewards: ['+50 Trust Score', 'Custom Avatar Border'],
    ),
    const Achievement(
      id: 'group_master',
      title: 'Group Master',
      description: 'Create 5 quick groups',
      badgeType: BadgeType.diamond,
      tier: TrophyTier.gold,
      rarityPercent: 15.0,
      maxProgress: 5,
      rewards: ['+100 Trust Score', 'Exclusive Group Badges'],
    ),
    const Achievement(
      id: 'perfect_payer',
      title: 'Perfect Payer',
      description: 'Pay all your bills within 24 hours for 30 days straight',
      badgeType: BadgeType.trophy,
      tier: TrophyTier.platinum,
      rarityPercent: 2.5,
      maxProgress: 30,
      rewards: ['+500 Trust Score', 'Platinum Status', 'Priority Support'],
    ),
    const Achievement(
      id: 'quick_splitter',
      title: 'Quick Splitter',
      description: 'Split 100 bills',
      badgeType: BadgeType.shield,
      tier: TrophyTier.gold,
      rarityPercent: 8.0,
      maxProgress: 100,
      rewards: ['+200 Trust Score', 'Speed Badge'],
    ),
  ];
}