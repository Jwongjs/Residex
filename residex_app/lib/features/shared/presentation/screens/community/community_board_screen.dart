                                                                                                                                                                                                                                                                             import 'package:flutter/material.dart';                                                                                                                                                                                                                                    
  import 'package:lucide_icons/lucide_icons.dart';                                                                                                                                                                                                                           
  import 'package:google_fonts/google_fonts.dart';
  import '../../../../../core/theme/app_colors.dart';
  import '../../../../../core/widgets/glass_card.dart';
  import '../../../../../core/widgets/residex_bottom_nav.dart';
  import '../../../domain/entities/users/app_user.dart';
  import 'package:go_router/go_router.dart';

  class CommunityBoardScreen extends StatefulWidget {
    const CommunityBoardScreen({super.key});

    @override
    State<CommunityBoardScreen> createState() => _CommunityBoardScreenState();
  }

  class _CommunityBoardScreenState extends State<CommunityBoardScreen> {
    String _activeTab = 'FEED';

    final List<CommunityPost> _posts = [
      CommunityPost(
        id: 1,
        author: 'Management',
        avatar: 'M',
        color: AppColors.indigo500,
        title: 'Water Disruption Notice: Zone A',
        description:
            'Scheduled maintenance on Oct 25, 10 AM - 2 PM. Please store water accordingly as supply will be cut off for pipe replacement.',
        type: 'ALERT',
        typeColor: AppColors.rose500,
        time: '2h ago',
        likes: 45,
        comments: 12,
      ),
      CommunityPost(
        id: 2,
        author: 'Sarah Tan',
        avatar: 'ST',
        color: AppColors.purple500,
        title: 'Badminton Session tonight! 🏸',
        description:
            'Booking court at 8PM tonight. Looking for 2 more players! Intermediate level preferred but open to all.',
        type: 'EVENT',
        typeColor: AppColors.emerald500,
        time: '4h ago',
        likes: 18,
        comments: 5,
      ),
      CommunityPost(
        id: 3,
        author: 'David Wong',
        avatar: 'DW',
        color: AppColors.emerald500,
        title: 'IKEA Gaming Chair - Black',
        description:
            'Moving out sale! Used for 6 months. Condition 9/10. Self pick-up at Unit 4-2. Price negotiable for fast deal.',
        type: 'MARKET',
        typeColor: AppColors.amber500,
        time: '30m ago',
        likes: 8,
        comments: 4,
        price: 'RM 150',
      ),
      CommunityPost(
        id: 4,
        author: 'Raj Kumar',
        avatar: 'RK',
        color: const Color(0xFFEA580C), // orange-600
        title: 'PS5 Digital Edition + 2 Controllers',
        description:
            'Rarely used. Comes with box and receipt. Meet up at lobby only.',
        type: 'MARKET',
        typeColor: AppColors.amber500,
        time: '1d ago',
        likes: 24,
        comments: 15,
        price: 'RM 1,200',
      ),
    ];

    List<CommunityPost> get _filteredPosts {
      if (_activeTab == 'FEED') return _posts.where((p) => p.type == 'ALERT').toList();
      if (_activeTab == 'EVENTS') return _posts.where((p) => p.type == 'EVENT').toList();
      if (_activeTab == 'MARKET') return _posts.where((p) => p.type == 'MARKET').toList();
      return _posts;
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: AppColors.deepSpace,
        body: Stack(
          children: [
            // Sapphire/Amethyst gradient
            Positioned(
              top: 0, left: 0, right: 0, height: 500,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors: [
                      AppColors.indigo500.withValues(alpha: 0.3),
                      AppColors.deepSpace,
                      AppColors.deepSpace,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _filteredPosts.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                            itemCount: _filteredPosts.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(height: 20),
                            itemBuilder: (context, index) {
                              if (index == _filteredPosts.length) {
                                return _buildEndOfFeed();
                              }
                              return _buildPostCard(_filteredPosts[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
      );
    }

    // ---------------------------------------------------------------------------
    // Header + Tabs
    // ---------------------------------------------------------------------------
    Widget _buildHeader() {
      return Padding(
        padding: const EdgeInsets.only(top: 32, bottom: 16, left: 24, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.indigo500.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.indigo500.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigo500.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(LucideIcons.users, size: 20, color: AppColors.indigo300),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Community',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'DIGITAL BOARD',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.indigo400,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Tab pill wrapper
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  _buildTab('FEED', 'Feed', LucideIcons.megaphone),
                  _buildTab('EVENTS', 'Events', LucideIcons.calendar),
                  _buildTab('MARKET', 'Market', LucideIcons.shoppingBag),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildTab(String id, String label, IconData icon) {
      final isActive = _activeTab == id;

      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _activeTab = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AppColors.indigo500 : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.indigo500.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isActive ? Colors.white : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : AppColors.textTertiary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // Post card
    // ---------------------------------------------------------------------------
    Widget _buildPostCard(CommunityPost post) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: post.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: post.color.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          post.avatar,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          post.time,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: post.typeColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (post.type == 'MARKET') ...[
                        Icon(LucideIcons.tag,
                            size: 9, color: post.typeColor),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        post.type,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: post.typeColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Title + price row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ),
                if (post.price != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      post.price!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              post.description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),

            const SizedBox(height: 20),

            // Footer actions
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05), width: 1),
                ),
              ),
              child: Row(
                children: [
                  _buildAction(LucideIcons.heart, post.likes.toString(),
                      AppColors.rose500),
                  const SizedBox(width: 20),
                  _buildAction(LucideIcons.messageSquare,
                      post.comments.toString(), AppColors.indigo500),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {},
                    child: Icon(LucideIcons.share2,
                        size: 18, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildAction(IconData icon, String count, Color color) {
      return GestureDetector(
        onTap: () {},
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              count,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // Empty state
    // ---------------------------------------------------------------------------
    Widget _buildEmptyState() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _activeTab == 'MARKET'
                    ? LucideIcons.shoppingBag
                    : LucideIcons.megaphone,
                size: 24,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active ${_activeTab == 'FEED' ? 'Announcements' : _activeTab == 'EVENTS' ? 'Events' : 'Listings'}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // End of feed
    // ---------------------------------------------------------------------------
    Widget _buildEndOfFeed() {
      final label = _activeTab == 'FEED'
          ? 'End of Feed'
          : _activeTab == 'EVENTS'
              ? 'End of Events'
              : 'End of Listings';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }
  }

  // =============================================================================
  // Post model
  // =============================================================================
  class CommunityPost {
    final int id;
    final String author;
    final String avatar;
    final Color color;
    final String title;
    final String description;
    final String type;
    final Color typeColor;
    final String time;
    final int likes;
    final int comments;
    final String? price; // only for MARKET posts

    CommunityPost({
      required this.id,
      required this.author,
      required this.avatar,
      required this.color,
      required this.title,
      required this.description,
      required this.type,
      required this.typeColor,
      required this.time,
      required this.likes,
      required this.comments,
      this.price,
    });
  }