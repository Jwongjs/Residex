import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/widgets/grid_overlay.dart';
import '../../../../core/widgets/scanline_effect.dart';
import '../../../../core/widgets/badge_widget/badge_grid.dart';
import '../widgets/checkpoint_card.dart';
import '../../domain/entities/achievement.dart';
import '../../../users/presentation/providers/users_provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

  class GamificationHubScreen extends ConsumerStatefulWidget {
    const GamificationHubScreen({super.key});

    @override
    ConsumerState<GamificationHubScreen> createState() =>
        _GamificationHubScreenState();
  }

  class _GamificationHubScreenState extends ConsumerState<GamificationHubScreen> {
    late PageController _pageController;
    int _currentPage = 0;

    // Demo data - replace with actual providers
    final List<Achievement> _achievements = AchievementsList.all;

    @override
    void initState() {
      super.initState();
      _pageController = PageController();
    }

    @override
    void dispose() {
      _pageController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final userAsync = ref.watch(currentUserProvider);

      return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
              // Dynamic background gradient
              AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _getPageGradient(_currentPage),
                  ),
                ),
              ),

              // Sci-fi background effects
              Positioned.fill(
                child: GridOverlay(opacity: 0.05),
              ),
            Positioned.fill(
              child: ScanlineEffect(),
            ),

            // Content
            userAsync.when(
              data: (user) => _buildContent(user),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),

            Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildHeader(),
              ),
          ],
        ),
      );
    }

    Widget _buildHeader() {
      return Container(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 10,
          20,
          20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.background.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.slate800.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryCyan.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.primaryCyan,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPageTitle(_currentPage),
                  style: TextStyle(
                    color: AppColors.primaryCyan,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  _getPageSubtitle(_currentPage),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
    }

    Widget _buildContent(dynamic user) {
    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 80),

        // PageView Carousel
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              // Slide 1: Profile
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: _buildProfileSection(user),
              ),
              // Slide 2: Armoury
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: _buildArmourySection(),
              ),
              // Slide 3: Leaderboard
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: _buildLeaderboardSection(),
              ),
            ],
          ),
        ),

        // Page Indicators
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: SmoothPageIndicator(
            controller: _pageController,
            count: 3,
            effect: ExpandingDotsEffect(
              dotWidth: 8,
              dotHeight: 8,
              spacing: 6,
              expansionFactor: 3,
              activeDotColor: AppColors.primaryCyan,
              dotColor: Colors.white.withValues(alpha: .3),
            ),
          ),
        ),

        // Bottom carousel selector
        _buildCarouselSelector(),

        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }

    Widget _buildProfileSection(dynamic user) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.primaryCyan.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryCyan.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Protocol label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PROTOCOL: SPLITTER',
                  style: TextStyle(
                    color: AppColors.primaryCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Avatar with glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCyan.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: AvatarWidget(
                  user:user,
                  size: 100,
                ),
              ),

              const SizedBox(height: 16),

              // Name
              Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 8),

              // Trust score
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.diamond,
                    color: AppColors.primaryCyan,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TRUST SCORE: ${user.stats?.trustScore ?? 0}',
                    style: const TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Stats grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'STREAK',
                      value: '${user.stats?.currentStreak ?? 0}d',
                      icon: LucideIcons.flame,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      label: 'BILLS',
                      value: '${user.stats?.totalBillsCreated ?? 0}',
                      icon: LucideIcons.fileText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      label: 'PAID',
                      value: '${user.stats?.totalPaid ?? 0}',
                      icon: LucideIcons.checkCircle2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildStatCard({
      required String label,
      required String value,
      required IconData icon,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.slate800.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildArmourySection() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CHECKPOINT',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Featured Achievement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Checkpoint card (horizontally scrollable)
          SizedBox(
            height: 360,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CheckpointCard(
                    achievement: _achievements[index],
                    isShowcasing: false,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // Badge collection grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Achievements',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                BadgeGrid(
                  badges: _achievements.map((achievement) {
                    return BadgeGridItem(
                      type: achievement.badgeType,
                      tier: achievement.tier,
                      title: achievement.title,
                      description: achievement.description,
                      rarityPercent: achievement.rarityPercent,
                      isUnlocked: achievement.isUnlocked,
      );
    }).toList(),
    ),
              ],
            ),
          ),
        ],   
      );
    }

    Widget _buildLeaderboardSection() {
      // Demo rank - replace with actual data
      const userRank = 1337;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.purple.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Protocol label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PROTOCOL: LEADERBOARD',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Massive rank number
              const Text(
                '#$userRank',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: Colors.purple,
                      blurRadius: 40,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Position change indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      color: Colors.green,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '23 THIS WEEK',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Top 15% of all users',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }
  
   Widget _buildCarouselSelector() {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha:0.1),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCarouselThumb(0, 'Profile', LucideIcons.user, AppColors.primaryCyan),
            const SizedBox(width: 16),
            _buildCarouselThumb(1, 'Armoury', LucideIcons.award, Colors.amber),
            const SizedBox(width: 16),
            _buildCarouselThumb(2, 'Rank', LucideIcons.trophy, Colors.purple),
          ],
        ),
      );
    }

    Widget _buildCarouselThumb(int index, String label, IconData icon, Color color) {
      final bool isActive = _currentPage == index;

      return GestureDetector(
        onTap: () {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha:0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : Colors.white.withValues(alpha:0.1),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isActive ? color : Colors.white70,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }
    String _getPageTitle(int page) {
      switch (page) {
        case 0:
          return 'PROFILE';
        case 1:
          return 'ARMOURY';
        case 2:
          return 'LEADERBOARD';
        default:
          return 'ARMOURY';
      }
    }

    String _getPageSubtitle(int page) {
      switch (page) {
        case 0:
          return 'Your Stats & Achievements';
        case 1:
          return 'Your Achievement Collection';
        case 2:
          return 'Global Rankings';
        default:
          return 'Your Achievement Collection';
      }
    }
    List<Color> _getPageGradient(int page) {
      switch (page) {
        case 0: // Profile - Cyan
          return [
            AppColors.primaryCyan.withValues(alpha:0.15),
            AppColors.background,
          ];
        case 1: // Armoury - Amber
          return [
            Colors.amber.withValues(alpha:0.15),
            AppColors.background,
          ];
        case 2: // Leaderboard - Purple
          return [
            Colors.purple.withValues(alpha:0.15),
            AppColors.background,
          ];
        default:
          return [AppColors.background, AppColors.background];
      }
    }
  }