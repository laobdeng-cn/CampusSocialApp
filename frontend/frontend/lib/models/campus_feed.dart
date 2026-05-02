import 'campus_models.dart';

class CampusFeed {
  const CampusFeed({
    required this.users,
    required this.posts,
    required this.activities,
    required this.groups,
    required this.topics,
  });

  final List<CampusUser> users;
  final List<CampusPost> posts;
  final List<CampusActivity> activities;
  final List<CampusGroup> groups;
  final List<CampusTopic> topics;

  factory CampusFeed.fromJson(Map<String, dynamic> json) {
    return CampusFeed(
      users: _readTypedList(json, 'users', CampusUser.fromJson),
      posts: _readTypedList(json, 'posts', CampusPost.fromJson),
      activities: _readTypedList(json, 'activities', CampusActivity.fromJson),
      groups: _readTypedList(json, 'groups', CampusGroup.fromJson),
      topics: _readTypedList(json, 'topics', CampusTopic.fromJson),
    );
  }
}

class CampusDiscover {
  const CampusDiscover({
    required this.hotSearches,
    required this.trendingPosts,
    required this.upcomingActivities,
    required this.recommendedGroups,
    required this.featuredTopics,
  });

  final List<String> hotSearches;
  final List<CampusPost> trendingPosts;
  final List<CampusActivity> upcomingActivities;
  final List<CampusGroup> recommendedGroups;
  final List<CampusTopic> featuredTopics;

  factory CampusDiscover.fromJson(Map<String, dynamic> json) {
    return CampusDiscover(
      hotSearches: _readStringList(json, 'hotSearches'),
      trendingPosts: _readTypedList(json, 'trendingPosts', CampusPost.fromJson),
      upcomingActivities: _readTypedList(
        json,
        'upcomingActivities',
        CampusActivity.fromJson,
      ),
      recommendedGroups: _readTypedList(
        json,
        'recommendedGroups',
        CampusGroup.fromJson,
      ),
      featuredTopics: _readTypedList(
        json,
        'featuredTopics',
        CampusTopic.fromJson,
      ),
    );
  }

  factory CampusDiscover.fromFeed(CampusFeed feed) {
    return CampusDiscover(
      hotSearches: [
        ...feed.topics.map((topic) => topic.name),
        ...feed.activities.map((activity) => activity.category),
        ...feed.groups.expand((group) => group.tags),
      ].where((item) => item.trim().isNotEmpty).toSet().take(8).toList(),
      trendingPosts: feed.posts.take(6).toList(growable: false),
      upcomingActivities: feed.activities.take(6).toList(growable: false),
      recommendedGroups: feed.groups.take(6).toList(growable: false),
      featuredTopics: feed.topics.take(6).toList(growable: false),
    );
  }
}

class CampusSearchResult {
  const CampusSearchResult({
    required this.users,
    required this.posts,
    required this.activities,
    required this.groups,
    required this.topics,
  });

  final List<CampusUser> users;
  final List<CampusPost> posts;
  final List<CampusActivity> activities;
  final List<CampusGroup> groups;
  final List<CampusTopic> topics;

  factory CampusSearchResult.empty() {
    return const CampusSearchResult(
      users: [],
      posts: [],
      activities: [],
      groups: [],
      topics: [],
    );
  }

  factory CampusSearchResult.fromJson(Map<String, dynamic> json) {
    return CampusSearchResult(
      users: _readTypedList(json, 'users', CampusUser.fromJson),
      posts: _readTypedList(json, 'posts', CampusPost.fromJson),
      activities: _readTypedList(json, 'activities', CampusActivity.fromJson),
      groups: _readTypedList(json, 'groups', CampusGroup.fromJson),
      topics: _readTypedList(json, 'topics', CampusTopic.fromJson),
    );
  }
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

List<T> _readTypedList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final value = json[key];
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => fromJson(item.cast<String, dynamic>()))
      .toList(growable: false);
}
