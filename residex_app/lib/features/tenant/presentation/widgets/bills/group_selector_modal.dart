import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../landlord/domain/entities/property.dart';
import '../../../../shared/domain/entities/groups/app_group.dart';

class GroupSelectorModal extends StatefulWidget {
  final List<AppGroup> groups;
  final Function(AppGroup) onGroupSelected;

  const GroupSelectorModal({
    super.key,
    required this.groups,
    required this.onGroupSelected,
  });

  @override
  State<GroupSelectorModal> createState() => _GroupSelectorModalState();
}

class _GroupSelectorModalState extends State<GroupSelectorModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _close() {
    _animController.reverse().then((_) => Navigator.pop(context));
  }

  void _selectGroup(AppGroup group) {
    _animController.reverse().then((_) {
      Navigator.pop(context);
      widget.onGroupSelected(group);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                    0, MediaQuery.of(context).size.height * _slideAnimation.value),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.65,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(
                            top: Radius.circular(32)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHandle(),
                            _buildHeader(),
                            if (widget.groups.isEmpty)
                              _buildEmptyState()
                            else
                              Expanded(
                                child: _buildGroupsGrid(),
                              ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),
                );
            },
          ),
        ),
      ),
    );
  }



  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12), // REDUCED vertical padding
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Group',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20, // REDUCED from 24
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 2), // REDUCED from 4
            Text(
              '${widget.groups.length} ${widget.groups.length == 1 ? 'group' : 'groups'} available',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11, // REDUCED from 13
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _close,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.close,
              color: Colors.white70,
              size: 20,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildGroupsGrid() {
  return GridView.builder(
    padding: const EdgeInsets.fromLTRB(20, 3, 20, 8), // REMOVE bottom padding completely
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.03, // INCREASED from 0.95 to 1.0 (even shorter cards)
    ),
    itemCount: widget.groups.length,
    itemBuilder: (context, index) {
      final group = widget.groups[index];
      return _buildGroupCard(group, index);
    },
  );
}


  Widget _buildGroupCard(AppGroup group, int index) {
  return GestureDetector(
    onTap: () => _selectGroup(group),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 4), // ADD internal padding
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // ADD this
        children: [
          // Circular group icon with emoji
          Container(
            width: 56, // REDUCED from 64
            height: 56, // REDUCED from 64
            decoration: BoxDecoration(
              color: Color(group.colorValue),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(group.colorValue).withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                group.emoji,
                style: const TextStyle(
                  fontSize: 28, // REDUCED from 32
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4), // REDUCED from 8

          // Group name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              group.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                height: 1.0, // REDUCED from 1.2
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2), // REDUCED from 4

          // Member count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), // REDUCED vertical from 3
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryCyan.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${group.tenantIds.length} ${group.tenantIds.length == 1 ? 'person' : 'people'}',
              style: const TextStyle(
                color: AppColors.primaryCyan,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: (index * 50).ms)
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
  );
}



  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Groups Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a group in "My Groups" section to organize your bills',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              decoration: TextDecoration.none,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the group selector modal
Future<void> showGroupSelectorModal({
  required BuildContext context,
  required List<AppGroup> groups,
  required Function(AppGroup) onGroupSelected,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Group Selector',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, anim1, anim2) {
      return GroupSelectorModal(
        groups: groups,
        onGroupSelected: onGroupSelected,
      );
    },
  );
}
