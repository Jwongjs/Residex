import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import '../../../../shared/presentation/providers/friends_provider.dart';
import '../../../../shared/presentation/widgets/gamification/add_friend_modal.dart';

class FriendsListWidget extends ConsumerWidget {
  const FriendsListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);

    return friendsAsync.when(
      data: (friends) {
        return GlassCard(
          opacity: 0.05,
          borderRadius: BorderRadius.circular( 40),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('Saved Friends', style: AppTextStyles.titleLarge),
                    ],
                  ),
                  GestureDetector(
                    onTap: () async {
                      await showAddFriendModal(context, ref);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add,
                            color: AppColors.primaryCyan,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'New',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.primaryCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Friends horizontal scroll
              SizedBox(
                height: 130,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                  // Friend cards
                  ...friends.map((friend) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _FriendCard(friend: friend),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final AppUser friend;

  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and trust score
          Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: friend.gradientColorValues != null &&
                          friend.gradientColorValues!.length >= 2
                      ? LinearGradient(
                          colors: [
                            Color(friend.gradientColorValues![0]),
                            Color(friend.gradientColorValues![1]),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: friend.gradientColorValues == null
                      ? AppColors.slate700
                      : null,
                  borderRadius: BorderRadius.circular( 12),
                ),
                child: Center(
                  child: Text(
                    friend.avatarInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Trust score badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 8,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${friend.trustScore ?? 0}',
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            friend.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Rank
          Text(
            friend.rank ?? 'BRONZE',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAddFriendModal(BuildContext context, WidgetRef ref) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add Friend',
    barrierColor: Colors.black.withValues(alpha: 0.8),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, anim1, anim2) {
      return AddFriendModal(ref: ref);
    },
  );
}
