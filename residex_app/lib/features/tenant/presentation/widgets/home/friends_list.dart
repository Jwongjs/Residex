import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/avatar_widget.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../shared/domain/entities/users/app_user.dart';

class FriendsList extends StatelessWidget {
  final List<AppUser> friends;
  final Function(AppUser)? onFriendTap;

  const FriendsList({
    super.key,
    required this.friends,
    this.onFriendTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOUSEMATES',
            style: AppTextStyles.sectionLabel,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final friend = friends[index];
                return _FriendTile(
                  user: friend,
                  onTap: () => onFriendTap?.call(friend),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onTap;

  const _FriendTile({
    required this.user,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.only(bottom: 10),
            child: AvatarWidget(
              initials: user.avatarInitials,
              size: 56,
              gradientIndex: user.id.hashCode % 6,
              honorLevel: user.honorLevel,
              showHonorBadge: true,
            )),
            const SizedBox(height: 8),
            Text(
              user.name.split(' ')[0],
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
