import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/landlord_community_provider.dart';
import '../../widgets/common/community_post_card.dart';

/// Landlord Community Screen - Digital Board
/// 
/// Features:
/// - Feed: Announcements and alerts
/// - Events: Community activities
/// - Marketplace: Buy/sell items
class LandlordCommunityScreen extends ConsumerStatefulWidget {
  const LandlordCommunityScreen({super.key});

  @override
  ConsumerState<LandlordCommunityScreen> createState() =>
      _LandlordCommunityScreenState();
}

class _LandlordCommunityScreenState
    extends ConsumerState<LandlordCommunityScreen> {
  CommunityTab _currentTab = CommunityTab.feed;

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(filteredCommunityPostsProvider(_currentTab));

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
                    AppColors.purple.withOpacity(0.3),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(context),

                // Engagement metrics summary
                _buildEngagementSummary(),

                // Content
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    itemCount: posts.isEmpty ? 1 : posts.length + 1,
                    itemBuilder: (context, index) {
                      if (posts.isEmpty) {
                        return _buildEmptyState();
                      }

                      if (index == posts.length) {
                        return _buildEndOfFeed();
                      }

                      final post = posts[index];
                      return CommunityPostCard(
                        post: post,
                        onLike: () {
                          // TODO: Implement like functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Liked "${post.title}"')),
                          );
                        },
                        onComment: () {
                          // TODO: Navigate to comments
                          _showCommentsSheet(context, post);
                        },
                        onShare: () {
                          // TODO: Implement share
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Share - Coming Soon')),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCreatePostButton(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          // Title
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.purple.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.groups,
                  color: AppColors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community',
                    style: AppTextStyles.heading2.copyWith(
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'DIGITAL BOARD',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.purple.withOpacity(0.8),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tab switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  label: 'Feed',
                  icon: Icons.campaign,
                  tab: CommunityTab.feed,
                ),
                _buildTabButton(
                  label: 'Events',
                  icon: Icons.event,
                  tab: CommunityTab.events,
                ),
                _buildTabButton(
                  label: 'Market',
                  icon: Icons.shopping_bag_outlined,
                  tab: CommunityTab.market,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required CommunityTab tab,
  }) {
    final isActive = _currentTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = tab;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.primaryGradient : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.purple.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  fontSize: 10,
                  color: isActive ? Colors.white : AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_currentTab) {
      case CommunityTab.events:
        message = 'No Active Events';
        icon = Icons.event;
        break;
      case CommunityTab.market:
        message = 'No Market Listings';
        icon = Icons.shopping_bag_outlined;
        break;
      default:
        message = 'No Active Feed Items';
        icon = Icons.campaign;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 24,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndOfFeed() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'End of ${_currentTab.name.toUpperCase()}',
          style: AppTextStyles.label.copyWith(
            color: AppColors.textMuted.withOpacity(0.5),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        // TODO: Navigate to create post
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create Post - Coming Soon')),
        );
      },
      backgroundColor: AppColors.purple,
      icon: const Icon(Icons.add, size: 20),
      label: Text(
        'New Post',
        style: AppTextStyles.label.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context, CommunityPost post) {
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

            // Post title
            Text(
              post.title,
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),

            const SizedBox(height: 8),

            Text(
              '${post.comments} Comments',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 24),

            // Mock comments
            Text(
              'Comments feature coming soon...',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          _buildMetricItem(Icons.visibility, '1.2k', 'Views'),
          _buildMetricItem(Icons.favorite, '84', 'Likes'),
          _buildMetricItem(Icons.comment, '32', 'Comments'),
          _buildMetricItem(Icons.people, '156', 'Active'),
        ],
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.purple,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}