import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Post type categories
enum PostType {
  alert,
  event,
  market,
  announcement,
}

/// Community post model
class CommunityPost {
  final String id;
  final String author;
  final String title;
  final String description;
  final PostType type;
  final String timeAgo;
  final int likes;
  final int comments;
  final String? price;
  final DateTime timestamp;

  CommunityPost({
    required this.id,
    required this.author,
    required this.title,
    required this.description,
    required this.type,
    required this.timeAgo,
    required this.likes,
    required this.comments,
    this.price,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Community tab filter
enum CommunityTab {
  feed,
  events,
  market,
}

/// Provider for community posts (mock data Phase 1)
final communityPostsProvider = Provider<List<CommunityPost>>((ref) {
  return [
    CommunityPost(
      id: '1',
      author: 'Management',
      title: 'Water Disruption Notice: Zone A',
      description:
          'Scheduled maintenance on Oct 25, 10 AM - 2 PM. Please store water accordingly as supply will be cut off for pipe replacement.',
      type: PostType.alert,
      timeAgo: '2h ago',
      likes: 45,
      comments: 12,
    ),
    CommunityPost(
      id: '2',
      author: 'Sarah Tan',
      title: 'Badminton Session tonight! 🏸',
      description:
          'Booking court at 8PM tonight. Looking for 2 more players! Intermediate level preferred but open to all.',
      type: PostType.event,
      timeAgo: '4h ago',
      likes: 18,
      comments: 5,
    ),
    CommunityPost(
      id: '3',
      author: 'David Wong',
      title: 'IKEA Gaming Chair - Black',
      description:
          'Moving out sale! Used for 6 months. Condition 9/10. Self pick-up at Unit 4-2. Price negotiable for fast deal.',
      type: PostType.market,
      timeAgo: '30m ago',
      likes: 8,
      comments: 4,
      price: 'RM 150',
    ),
    CommunityPost(
      id: '4',
      author: 'Raj Kumar',
      title: 'PS5 Digital Edition + 2 Controllers',
      description:
          'Rarely used. Comes with box and receipt. Meet up at lobby only.',
      type: PostType.market,
      timeAgo: '1d ago',
      likes: 24,
      comments: 15,
      price: 'RM 1,200',
    ),
    CommunityPost(
      id: '5',
      author: 'Management',
      title: 'Lift Maintenance Schedule',
      description:
          'Lift A will be under maintenance on Oct 28, 9 AM - 12 PM. Please use Lift B during this period.',
      type: PostType.announcement,
      timeAgo: '1d ago',
      likes: 32,
      comments: 8,
    ),
    CommunityPost(
      id: '6',
      author: 'Lisa Chen',
      title: 'Yoga Class - Sunday Morning',
      description:
          'Free community yoga session at the rooftop garden. Bring your own mat! All levels welcome. 7 AM - 8 AM.',
      type: PostType.event,
      timeAgo: '2d ago',
      likes: 41,
      comments: 19,
    ),
  ];
});

/// Filtered posts by tab
final filteredCommunityPostsProvider =
    Provider.family<List<CommunityPost>, CommunityTab>((ref, tab) {
  final allPosts = ref.watch(communityPostsProvider);

  switch (tab) {
    case CommunityTab.feed:
      return allPosts.where((p) => p.type == PostType.alert || p.type == PostType.announcement).toList();
    case CommunityTab.events:
      return allPosts.where((p) => p.type == PostType.event).toList();
    case CommunityTab.market:
      return allPosts.where((p) => p.type == PostType.market).toList();
  }
});

/// Community statistics
class CommunityStats {
  final int totalPosts;
  final int activeEvents;
  final int marketListings;
  final int totalMembers;

  CommunityStats({
    required this.totalPosts,
    required this.activeEvents,
    required this.marketListings,
    required this.totalMembers,
  });
}

final communityStatsProvider = Provider<CommunityStats>((ref) {
  final posts = ref.watch(communityPostsProvider);

  return CommunityStats(
    totalPosts: posts.length,
    activeEvents: posts.where((p) => p.type == PostType.event).length,
    marketListings: posts.where((p) => p.type == PostType.market).length,
    totalMembers: 42, // Mock data
  );
});