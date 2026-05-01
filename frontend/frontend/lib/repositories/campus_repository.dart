import '../data/sample_data.dart';
import '../models/campus_feed.dart';
import '../models/campus_models.dart';
import '../services/campus_api_client.dart';
import 'auth_session.dart';

class CampusRepository {
  CampusRepository({CampusApiClient? apiClient})
    : _apiClient = apiClient ?? CampusApiClient();

  static final CampusRepository instance = CampusRepository();

  final CampusApiClient _apiClient;

  CampusFeed _cachedFeed = fallbackFeed;

  CampusFeed get cachedFeed => _cachedFeed;

  Future<CampusFeed> fetchFeed() async {
    try {
      final remoteFeed = await _apiClient.fetchFeed();
      _cachedFeed = _normalizeFeed(remoteFeed);
      return _cachedFeed;
    } catch (_) {
      _cachedFeed = fallbackFeed;
      return _cachedFeed;
    }
  }

  Future<CampusSearchResult> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return CampusSearchResult.empty();

    try {
      final result = await _apiClient.search(trimmedQuery);
      final normalized = _normalizeSearchResult(result);
      if (_hasAnyResult(normalized)) return normalized;
    } catch (_) {
      // Search falls back to the current feed so the UI stays useful offline.
    }

    return _localSearch(trimmedQuery, _cachedFeed);
  }

  Future<CampusUser> login({
    required String username,
    required String password,
  }) async {
    final result = await _apiClient.login(
      username: username,
      password: password,
    );
    AuthSession.set(result.token, result.user);
    return result.user;
  }

  Future<CampusUser> register({
    required String username,
    required String password,
    required String name,
  }) async {
    final result = await _apiClient.register(
      username: username,
      password: password,
      name: name,
    );
    AuthSession.set(result.token, result.user);
    return result.user;
  }

  Future<CampusUser> verifyCampus({
    required String realName,
    required String campusName,
    required String studentId,
    required String major,
    required String enrollmentYear,
    required String campusRole,
  }) async {
    final token = AuthSession.token;
    if (token?.isNotEmpty != true) {
      throw const CampusApiException('请先登录或注册后再进行校园认证');
    }

    final user = await _apiClient.verifyCampus(
      token: token!,
      realName: realName,
      campusName: campusName,
      studentId: studentId,
      major: major,
      enrollmentYear: enrollmentYear,
      campusRole: campusRole,
    );
    AuthSession.updateUser(user);
    return user;
  }

  Future<CampusPost> createPost({
    required String title,
    required String body,
    required String topic,
    required String location,
    required List<String> images,
  }) async {
    final token = _requireToken();
    final post = await _apiClient.createPost(
      token: token,
      title: title,
      body: body,
      topic: topic,
      location: location,
      images: images,
    );
    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: [post, ..._cachedFeed.posts],
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups,
      topics: _cachedFeed.topics,
    );
    return post;
  }

  Future<List<CampusPost>> fetchMyPosts() {
    return _apiClient.fetchMyPosts(token: _requireToken());
  }

  Future<void> deletePost(CampusPost post) async {
    final id = _requirePostId(post);
    await _apiClient.deletePost(token: _requireToken(), postId: id);
    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts
          .where((cachedPost) => cachedPost.id != id)
          .toList(growable: false),
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups
          .map(
            (group) => group.copyWith(
              discussions: group.discussions
                  .where((cachedPost) => cachedPost.id != id)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      topics: _cachedFeed.topics
          .map(
            (topic) => topic.copyWith(
              posts: topic.posts
                  .where((cachedPost) => cachedPost.id != id)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<CampusPost> togglePostLike(CampusPost post) async {
    final id = _requirePostId(post);
    return _replaceCachedPost(
      await _apiClient.togglePostLike(token: _requireToken(), postId: id),
    );
  }

  Future<CampusPost> togglePostFavorite(CampusPost post) async {
    final id = _requirePostId(post);
    return _replaceCachedPost(
      await _apiClient.togglePostFavorite(token: _requireToken(), postId: id),
    );
  }

  Future<({CampusComment comment, CampusPost post})> createComment({
    required CampusPost post,
    required String text,
  }) async {
    final id = _requirePostId(post);
    final result = await _apiClient.createComment(
      token: _requireToken(),
      postId: id,
      text: text,
    );
    _replaceCachedPost(result.post);
    return result;
  }

  Future<List<CampusComment>> fetchComments(CampusPost post) async {
    final id = _requirePostId(post);
    return _apiClient.fetchComments(id);
  }

  Future<List<CampusMyCommentRecord>> fetchMyComments() {
    return _apiClient.fetchMyComments(token: _requireToken());
  }

  Future<void> deleteComment(CampusMyCommentRecord comment) {
    if (comment.id.isEmpty) {
      throw const CampusApiException('这条评论暂未同步到后端');
    }
    return _apiClient.deleteComment(
      token: _requireToken(),
      commentId: comment.id,
    );
  }

  Future<CampusActivity> joinActivity(CampusActivity activity) async {
    final id = _requireActivityId(activity);
    return _replaceCachedActivity(
      await _apiClient.joinActivity(token: _requireToken(), activityId: id),
    );
  }

  Future<CampusActivity> cancelActivityJoin(CampusActivity activity) async {
    final id = _requireActivityId(activity);
    return _replaceCachedActivity(
      await _apiClient.cancelActivityJoin(
        token: _requireToken(),
        activityId: id,
      ),
    );
  }

  Future<List<CampusActivity>> fetchMyActivities() async {
    final activities = await _apiClient.fetchMyActivities(
      token: _requireToken(),
    );
    return activities
        .map((activity) => _enrichActivity(activity, _cachedFeed.users))
        .toList(growable: false);
  }

  Future<CampusCheckInRecord> checkInWithCode({
    CampusActivity? activity,
    required String code,
  }) async {
    final targetActivity = activity ?? _firstSyncedActivity();
    final id = _requireActivityId(targetActivity);
    return _apiClient.checkInActivity(
      token: _requireToken(),
      activityId: id,
      code: code,
    );
  }

  Future<List<CampusCheckInRecord>> fetchCheckInRecords() {
    return _apiClient.fetchCheckInRecords(token: _requireToken());
  }

  Future<CampusUser> updateProfile({
    required String name,
    required String school,
    required String major,
    required String grade,
    required String bio,
    required String avatarUrl,
  }) async {
    final user = await _apiClient.updateProfile(
      token: _requireToken(),
      name: name,
      school: school,
      major: major,
      grade: grade,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    AuthSession.updateUser(user);
    return user;
  }

  Future<CampusUserSettings> fetchSettings() {
    return _apiClient.fetchSettings(token: _requireToken());
  }

  Future<CampusUserSettings> updateSettings(CampusUserSettings settings) {
    return _apiClient.updateSettings(
      token: _requireToken(),
      settings: settings,
    );
  }

  Future<List<CampusFavoriteRecord>> fetchFavorites() {
    return _apiClient.fetchFavorites(token: _requireToken());
  }

  Future<List<CampusHistoryRecord>> fetchHistory() {
    return _apiClient.fetchHistory(token: _requireToken());
  }

  Future<void> recordHistory({
    required String kind,
    required String title,
    String refId = '',
    String subtitle = '',
    String imageUrl = '',
  }) {
    return _apiClient.recordHistory(
      token: _requireToken(),
      kind: kind,
      title: title,
      refId: refId,
      subtitle: subtitle,
      imageUrl: imageUrl,
    );
  }

  Future<void> clearHistory() {
    return _apiClient.clearHistory(token: _requireToken());
  }

  Future<List<CampusDraft>> fetchDrafts() {
    return _apiClient.fetchDrafts(token: _requireToken());
  }

  Future<CampusDraft> saveDraft({
    required String title,
    required String body,
    required String topic,
    required String location,
    required List<String> images,
  }) {
    return _apiClient.saveDraft(
      token: _requireToken(),
      title: title,
      body: body,
      topic: topic,
      location: location,
      images: images,
    );
  }

  Future<void> deleteDraft(CampusDraft draft) {
    if (draft.id.isEmpty) {
      throw const CampusApiException('这条草稿暂未同步到后端');
    }
    return _apiClient.deleteDraft(token: _requireToken(), draftId: draft.id);
  }

  Future<List<CampusUser>> fetchFollowing() {
    return _apiClient.fetchFollowing(token: _requireToken());
  }

  Future<List<CampusUser>> fetchFollowers() {
    return _apiClient.fetchFollowers(token: _requireToken());
  }

  Future<CampusUser> followUser(CampusUser user) {
    final id = _requireUserId(user);
    return _apiClient.followUser(token: _requireToken(), userId: id);
  }

  Future<CampusUser> unfollowUser(CampusUser user) {
    final id = _requireUserId(user);
    return _apiClient.unfollowUser(token: _requireToken(), userId: id);
  }

  Future<List<CampusLikeRecord>> fetchLikesReceived() {
    return _apiClient.fetchLikesReceived(token: _requireToken());
  }

  Future<List<CampusNotificationRecord>> fetchNotifications({
    String? category,
  }) {
    return _apiClient.fetchNotifications(
      token: _requireToken(),
      category: category,
    );
  }

  Future<void> markNotificationsRead() {
    return _apiClient.markNotificationsRead(token: _requireToken());
  }

  Future<List<CampusConversation>> fetchConversations() {
    return _apiClient.fetchConversations(token: _requireToken());
  }

  Future<List<CampusChatMessage>> fetchConversationMessages(
    String conversationId,
  ) {
    if (conversationId.isEmpty) {
      throw const CampusApiException('会话暂未同步到后端');
    }
    return _apiClient.fetchConversationMessages(
      token: _requireToken(),
      conversationId: conversationId,
    );
  }

  Future<CampusChatMessage> sendConversationMessage({
    required String conversationId,
    required String text,
  }) {
    if (conversationId.isEmpty) {
      throw const CampusApiException('会话暂未同步到后端');
    }
    return _apiClient.sendConversationMessage(
      token: _requireToken(),
      conversationId: conversationId,
      text: text,
    );
  }

  Future<CampusGroup> joinGroup(CampusGroup group) async {
    final id = _requireGroupId(group);
    return _replaceCachedGroup(
      await _apiClient.joinGroup(token: _requireToken(), groupId: id),
    );
  }

  Future<CampusGroup> leaveGroup(CampusGroup group) async {
    final id = _requireGroupId(group);
    return _replaceCachedGroup(
      await _apiClient.leaveGroup(token: _requireToken(), groupId: id),
    );
  }

  Future<List<CampusGroup>> fetchMyGroups() async {
    final groups = await _apiClient.fetchMyGroups(token: _requireToken());
    return groups.map(_enrichGroup).toList(growable: false);
  }

  Future<CampusGroup> fetchGroupDetail(CampusGroup group) async {
    final id = _requireGroupId(group);
    return _enrichGroup(await _apiClient.fetchGroupDetail(id));
  }

  Future<CampusTopic> fetchTopicDetail(CampusTopic topic) async {
    final id = _requireTopicId(topic);
    return _enrichTopic(await _apiClient.fetchTopicDetail(id));
  }

  CampusFeed _normalizeFeed(CampusFeed feed) {
    final users = feed.users.isEmpty ? fallbackFeed.users : feed.users;
    final posts = feed.posts.isEmpty ? fallbackFeed.posts : feed.posts;
    final activities = feed.activities.isEmpty
        ? fallbackFeed.activities
        : feed.activities;
    final groups = feed.groups.isEmpty ? fallbackFeed.groups : feed.groups;
    final topics = feed.topics.isEmpty ? fallbackFeed.topics : feed.topics;

    final enrichedActivities = activities
        .map((activity) => _enrichActivity(activity, users))
        .toList(growable: false);
    final enrichedGroups = groups
        .map(
          (group) => _enrichGroup(group).copyWith(
            activities: group.activities.isEmpty
                ? enrichedActivities.take(2).toList(growable: false)
                : group.activities
                      .map((item) => _enrichActivity(item, users))
                      .toList(),
            discussions: group.discussions.isEmpty
                ? posts.take(3).toList(growable: false)
                : group.discussions,
          ),
        )
        .toList(growable: false);
    final enrichedTopics = topics
        .map(
          (topic) => _enrichTopic(topic).copyWith(
            posts: topic.posts.isEmpty
                ? posts.take(3).toList(growable: false)
                : topic.posts,
            contributors: topic.contributors.isEmpty
                ? users.take(5).toList(growable: false)
                : topic.contributors,
          ),
        )
        .toList(growable: false);

    return CampusFeed(
      users: users,
      posts: posts,
      activities: enrichedActivities,
      groups: enrichedGroups,
      topics: enrichedTopics,
    );
  }

  CampusSearchResult _normalizeSearchResult(CampusSearchResult result) {
    return CampusSearchResult(
      users: result.users,
      posts: result.posts,
      activities: result.activities
          .map((activity) => _enrichActivity(activity, _cachedFeed.users))
          .toList(growable: false),
      groups: result.groups,
      topics: result.topics,
    );
  }

  CampusActivity _enrichActivity(
    CampusActivity activity,
    List<CampusUser> users,
  ) {
    final presentation = _activityPresentationByTitle[activity.title];

    return activity.copyWith(
      posterUrl: presentation?.posterUrl,
      date: presentation?.date,
      location: presentation?.location,
      highlights: activity.highlights.isEmpty
          ? const ['精彩内容', '同好交流', '现场互动']
          : activity.highlights,
      guests: activity.guests.isEmpty
          ? users.take(3).toList(growable: false)
          : activity.guests,
    );
  }

  CampusGroup _enrichGroup(CampusGroup group) {
    return group.copyWith(
      activities: group.activities
          .map((activity) => _enrichActivity(activity, _cachedFeed.users))
          .toList(growable: false),
      discussions: group.discussions,
    );
  }

  CampusTopic _enrichTopic(CampusTopic topic) {
    return topic.copyWith(
      posts: topic.posts,
      contributors: topic.contributors.isEmpty
          ? _cachedFeed.users.take(5).toList(growable: false)
          : topic.contributors,
    );
  }

  CampusSearchResult _localSearch(String query, CampusFeed feed) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    bool contains(String value) {
      final lowerValue = value.toLowerCase();
      return tokens.any(lowerValue.contains);
    }

    return CampusSearchResult(
      users: feed.users
          .where(
            (user) =>
                contains(user.name) ||
                contains(user.school) ||
                contains(user.major) ||
                contains(user.bio),
          )
          .toList(growable: false),
      posts: feed.posts
          .where(
            (post) =>
                contains(post.title) ||
                contains(post.body) ||
                contains(post.topic) ||
                contains(post.location),
          )
          .toList(growable: false),
      activities: feed.activities
          .where(
            (activity) =>
                contains(activity.title) ||
                contains(activity.category) ||
                contains(activity.location) ||
                contains(activity.host),
          )
          .toList(growable: false),
      groups: feed.groups
          .where(
            (group) =>
                contains(group.name) ||
                contains(group.description) ||
                group.tags.any(contains),
          )
          .toList(growable: false),
      topics: feed.topics
          .where(
            (topic) =>
                contains(topic.name) ||
                contains(topic.description) ||
                topic.relatedTopics.any(contains),
          )
          .toList(growable: false),
    );
  }

  bool _hasAnyResult(CampusSearchResult result) {
    return result.users.isNotEmpty ||
        result.posts.isNotEmpty ||
        result.activities.isNotEmpty ||
        result.groups.isNotEmpty ||
        result.topics.isNotEmpty;
  }

  CampusPost _replaceCachedPost(CampusPost nextPost) {
    List<CampusPost> replace(List<CampusPost> posts) {
      return posts
          .map((post) => post.id == nextPost.id ? nextPost : post)
          .toList(growable: false);
    }

    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: replace(_cachedFeed.posts),
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups,
      topics: _cachedFeed.topics
          .map((topic) => topic.copyWith(posts: replace(topic.posts)))
          .toList(growable: false),
    );
    return nextPost;
  }

  CampusActivity _replaceCachedActivity(CampusActivity nextActivity) {
    final enriched = _enrichActivity(nextActivity, _cachedFeed.users);

    List<CampusActivity> replace(List<CampusActivity> activities) {
      return activities
          .map((activity) => activity.id == enriched.id ? enriched : activity)
          .toList(growable: false);
    }

    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: replace(_cachedFeed.activities),
      groups: _cachedFeed.groups
          .map((group) => group.copyWith(activities: replace(group.activities)))
          .toList(growable: false),
      topics: _cachedFeed.topics,
    );
    return enriched;
  }

  CampusGroup _replaceCachedGroup(CampusGroup nextGroup) {
    final enriched = _enrichGroup(nextGroup);
    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups
          .map((group) => group.id == enriched.id ? enriched : group)
          .toList(growable: false),
      topics: _cachedFeed.topics,
    );
    return enriched;
  }

  String _requireToken() {
    final token = AuthSession.token;
    if (token?.isNotEmpty == true) return token!;
    throw const CampusApiException('请先登录后再操作');
  }

  String _requirePostId(CampusPost post) {
    if (post.id.isNotEmpty) return post.id;
    throw const CampusApiException('这条帖子暂未同步到后端');
  }

  CampusActivity _firstSyncedActivity() {
    for (final activity in _cachedFeed.activities) {
      if (activity.id.isNotEmpty) return activity;
    }
    throw const CampusApiException('请先从活动详情报名后再签到');
  }

  String _requireActivityId(CampusActivity activity) {
    if (activity.id.isNotEmpty) return activity.id;
    throw const CampusApiException('这场活动暂未同步到后端');
  }

  String _requireGroupId(CampusGroup group) {
    if (group.id.isNotEmpty) return group.id;
    throw const CampusApiException('这个社群暂未同步到后端');
  }

  String _requireTopicId(CampusTopic topic) {
    if (topic.id.isNotEmpty) return topic.id;
    throw const CampusApiException('这个话题暂未同步到后端');
  }

  String _requireUserId(CampusUser user) {
    if (user.id.isNotEmpty) return user.id;
    throw const CampusApiException('这个同学暂未同步到后端');
  }
}

class _ActivityPresentation {
  const _ActivityPresentation({
    required this.posterUrl,
    this.date,
    this.location,
  });

  final String posterUrl;
  final String? date;
  final String? location;
}

const _activityPresentationByTitle = {
  '校园音乐之夜': _ActivityPresentation(
    posterUrl: 'asset:assets/images/activity_music_thumb.png',
  ),
  'AI 未来发展趋势讲座': _ActivityPresentation(
    posterUrl: 'asset:assets/images/activity_ai_thumb.png',
  ),
  '校园篮球友谊赛': _ActivityPresentation(
    posterUrl: 'asset:assets/images/activity_basketball_thumb.png',
  ),
  '摄影社团采风活动': _ActivityPresentation(
    posterUrl: 'asset:assets/images/activity_photo_thumb.png',
    date: '6月1日（周六）',
    location: '东湖公园',
  ),
};
