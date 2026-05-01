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
