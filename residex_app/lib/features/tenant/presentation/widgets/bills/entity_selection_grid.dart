import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/avatar_widget.dart';
import '../../../domain/entities/bills/breakdown_item.dart';

class EntitySelectionGrid extends StatelessWidget {
  final List<BreakdownGroup> groups;
  final Function(BreakdownGroup) onEntitySelected;
  final bool isGroupMode;

  const EntitySelectionGrid({
    super.key,
    required this.groups,
    required this.onEntitySelected,
    required this.isGroupMode,
  });

  @override
  Widget build(BuildContext context) {
    if (isGroupMode) {
      return _buildGroupList();
    } else {
      return _buildPersonGrid();
    }
  }

  Widget _buildPersonGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _buildPersonCard(group, index);
        },
      ),
    );
  }

  Widget _buildGroupList() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _buildGroupCard(group, index);
        },
      ),
    );
  }

  Widget _buildPersonCard(BreakdownGroup group, int index) {
    final direction = group.items.isNotEmpty ? group.items.first.direction : 'OUT';
    final user = group.user;

  return GestureDetector(
    onTap: () => onEntitySelected(group),
    child: GlassCard(
      borderRadius: BorderRadius.circular( 20),
      padding: const EdgeInsets.all(16),
      opacity: 0.05,
      child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,  // ADD THIS
    children: [
      if (user != null)
        AvatarWidget.fromUser(
          user: user,
          size: 50,  // REDUCED from 60
        )
      else
        Container(
          width: 50,  // REDUCED from 60
          height: 50,  // REDUCED from 60
          decoration: BoxDecoration(
            color: AppColors.primaryCyan,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              group.entityName.isNotEmpty
                  ? group.entityName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,  // REDUCED from 24
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),  // REDUCED from 12
        Text(
          group.entityName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,  // REDUCED from 14
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),  // REDUCED from 4
        Text(
          '${group.items.length} bill${group.items.length > 1 ? 's' : ''}',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,  // REDUCED from 11
          ),
        ),
        const SizedBox(height: 4),  // REDUCED from 8
        Text(
          'RM ${group.totalAmount.toStringAsFixed(2)}',
          style: TextStyle(
            color: direction == 'OUT' ? Colors.redAccent : Colors.green,
            fontSize: 14,  // REDUCED from 16
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
      ),
    ).animate()
      .fadeIn(duration: 300.ms, delay: (index * 50).ms)
      .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: (index * 50).ms);
  }

  Widget _buildGroupCard(BreakdownGroup group, int index) {
    final direction = group.items.isNotEmpty ? group.items.first.direction : 'OUT';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => onEntitySelected(group),
        child: GlassCard(
          borderRadius: BorderRadius.circular( 20),
          padding: const EdgeInsets.all(16),
          opacity: 0.05,
          child: Row(
            children: [
              // Group icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(group.entityColor ?? 0xFF06B6D4),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    group.entityEmoji ?? '👥',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.entityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.items.length} bill${group.items.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount
  Flexible(
    child: Text(
      'RM ${group.totalAmount.toStringAsFixed(2)}',
      style: TextStyle(
        color: direction == 'OUT' ? Colors.redAccent : Colors.green,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  ),
            ],
          ),
        ),
      ).animate()
        .fadeIn(duration: 300.ms, delay: (index * 50).ms)
        .slideX(begin: 0.05, end: 0, duration: 300.ms, delay: (index * 50).ms),
    );
  }
}
