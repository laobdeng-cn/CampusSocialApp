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
  Set<String> _cachedFavoriteActivityIds = <String>{};

  CampusFeed get cachedFeed => _cachedFeed;

  void _cacheFavoriteRecords(List<CampusFavoriteRecord> favorites) {
    _cachedFavoriteActivityIds = favorites
        .where(
          (record) =>
              record.kind == 'activity' && record.activity.id.isNotEmpty,
        )
        .map((record) => record.activity.id)
        .toSet();
  }

  CampusFeed _applyFavoriteStateToFeed(CampusFeed feed) {
    return CampusFeed(
      users: feed.users,
      posts: feed.posts,
      activities: feed.activities
          .map(
            (activity) => activity.copyWith(
              isFavorited: _cachedFavoriteActivityIds.contains(activity.id),
            ),
          )
          .toList(growable: false),
      groups: feed.groups,
      topics: feed.topics,
    );
  }

  Future<void> _syncFavoriteActivityIds() async {
    final token = AuthSession.token;
    if (token?.isNotEmpty != true) {
      _cachedFavoriteActivityIds = <String>{};
      _cachedFeed = _applyFavoriteStateToFeed(_cachedFeed);
      return;
    }

    final favorites = await _apiClient.fetchFavorites(token: token!);
    _cacheFavoriteRecords(favorites);
    _cachedFeed = _applyFavoriteStateToFeed(_cachedFeed);
  }

  void _setCachedActivityFavorite(String id, bool favorited) {
    if (id.isEmpty) return;

    if (favorited) {
      _cachedFavoriteActivityIds = {..._cachedFavoriteActivityIds, id};
    } else {
      _cachedFavoriteActivityIds = _cachedFavoriteActivityIds
          .where((item) => item != id)
          .toSet();
    }

    _cachedFeed = _applyFavoriteStateToFeed(_cachedFeed);
  }

  Future<CampusFeed> fetchFeed() async {
    try {
      final remoteFeed = await _apiClient.fetchFeed();
      _cachedFeed = _normalizeFeed(remoteFeed);

      try {
        await _syncFavoriteActivityIds();
      } catch (_) {
        _cachedFeed = _applyFavoriteStateToFeed(_cachedFeed);
      }

      return _cachedFeed;
    } catch (_) {
      _cachedFeed = _applyFavoriteStateToFeed(fallbackFeed);
      return _cachedFeed;
    }
  }

  Future<CampusDiscover> fetchDiscover() async {
    try {
      final discover = await _apiClient.fetchDiscover();
      return _normalizeDiscover(discover);
    } catch (_) {
      return _normalizeDiscover(CampusDiscover.fromFeed(_cachedFeed));
    }
  }

  Future<CampusSearchResult> search(
    String query, {
    String type = 'all',
    String? category,
    String sort = 'relevance',
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return CampusSearchResult.empty();

    try {
      final result = await _apiClient.search(
        trimmedQuery,
        type: type,
        category: category,
        sort: sort,
      );
      final normalized = _normalizeSearchResult(result);
      if (_hasAnyResult(normalized)) return normalized;
    } catch (_) {
      // Search falls back to the current feed so the UI stays useful offline.
    }

    return _filterSearchResult(
      _sortSearchResult(_localSearch(trimmedQuery, _cachedFeed), sort),
      type,
    );
  }

  Future<String> uploadImage(String filePath, {String purpose = 'general'}) {
    return _apiClient.uploadImage(
      token: _requireToken(),
      filePath: filePath,
      purpose: purpose,
    );
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

  Future<CampusActivity> createActivity({
    required String title,
    required String category,
    required String date,
    required String time,
    required String location,
    required String host,
    required int capacity,
    required String price,
    required String description,
    required List<String> tags,
    required bool allowComments,
    required bool publicDisplay,
    required String posterUrl,
  }) async {
    final activity = await _apiClient.createActivity(
      token: _requireToken(),
      title: title,
      category: category,
      date: date,
      time: time,
      location: location,
      host: host,
      capacity: capacity,
      price: price,
      description: description,
      tags: tags,
      allowComments: allowComments,
      publicDisplay: publicDisplay,
      posterUrl: posterUrl,
    );
    final enriched = _enrichActivity(activity, _cachedFeed.users);
    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: [enriched, ..._cachedFeed.activities],
      groups: _cachedFeed.groups,
      topics: _cachedFeed.topics,
    );
    return enriched;
  }

  Future<CampusActivity> updateActivity({
    required CampusActivity activity,
    required String title,
    required String category,
    required String date,
    required String time,
    required String location,
    required String host,
    required int capacity,
    required String price,
    required String description,
    required List<String> tags,
    required bool allowComments,
    required bool publicDisplay,
    required String posterUrl,
  }) async {
    final id = _requireActivityId(activity);
    return _replaceCachedActivity(
      await _apiClient.updateActivity(
        token: _requireToken(),
        activityId: id,
        title: title,
        category: category,
        date: date,
        time: time,
        location: location,
        host: host,
        capacity: capacity,
        price: price,
        description: description,
        tags: tags,
        allowComments: allowComments,
        publicDisplay: publicDisplay,
        posterUrl: posterUrl,
      ),
    );
  }

  Future<void> deleteActivity(CampusActivity activity) async {
    final id = _requireActivityId(activity);
    await _apiClient.deleteActivity(token: _requireToken(), activityId: id);
    _removeCachedActivity(id);
  }

  Future<({String code, CampusActivity activity})> resetActivityCheckInCode(
    CampusActivity activity,
  ) async {
    final id = _requireActivityId(activity);
    final result = await _apiClient.resetActivityCheckInCode(
      token: _requireToken(),
      activityId: id,
    );
    return (
      code: result.code,
      activity: _replaceCachedActivity(result.activity),
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

  Future<CampusActivity> toggleActivityFavorite(CampusActivity activity) async {
    final id = _requireActivityId(activity);
    final before =
        _cachedFavoriteActivityIds.contains(id) || activity.isFavorited;

    try {
      final remoteActivity = await _apiClient.toggleActivityFavorite(
        token: _requireToken(),
        activityId: id,
      );

      _setCachedActivityFavorite(id, !before);

      try {
        await _syncFavoriteActivityIds();
      } catch (_) {}

      final after = _cachedFavoriteActivityIds.contains(id);
      return _replaceCachedActivity(
        remoteActivity.copyWith(isFavorited: after),
      );
    } catch (error) {
      try {
        await _syncFavoriteActivityIds();
        final after = _cachedFavoriteActivityIds.contains(id);

        // 如果后端其实已经成功变更，只是返回解析异常，不再误提示失败
        if (after != before) {
          return _replaceCachedActivity(activity.copyWith(isFavorited: after));
        }
      } catch (_) {}

      rethrow;
    }
  }

  Future<List<CampusActivity>> fetchMyActivities() async {
    final activities = await _apiClient.fetchMyActivities(
      token: _requireToken(),
    );
    return activities
        .map((activity) => _enrichActivity(activity, _cachedFeed.users))
        .toList(growable: false);
  }

  Future<List<CampusActivity>> fetchCreatedActivities() async {
    final activities = await _apiClient.fetchCreatedActivities(
      token: _requireToken(),
    );
    return activities
        .map((activity) => _enrichActivity(activity, _cachedFeed.users))
        .toList(growable: false);
  }

  Future<List<CampusActivityEnrollment>> fetchActivityEnrollments(
    CampusActivity activity,
  ) {
    final id = _requireActivityId(activity);
    return _apiClient.fetchActivityEnrollments(
      token: _requireToken(),
      activityId: id,
    );
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

  Future<List<CampusFavoriteRecord>> fetchFavorites() async {
    final favorites = await _apiClient.fetchFavorites(token: _requireToken());
    _cacheFavoriteRecords(favorites);
    _cachedFeed = _applyFavoriteStateToFeed(_cachedFeed);
    return favorites;
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

  Future<CampusNotificationRecord> markNotificationRead(String notificationId) {
    if (notificationId.isEmpty) {
      throw const CampusApiException('这条通知暂未同步到后端');
    }
    return _apiClient.markNotificationRead(
      token: _requireToken(),
      notificationId: notificationId,
    );
  }

  Future<void> deleteNotification(String notificationId) {
    if (notificationId.isEmpty) {
      throw const CampusApiException('这条通知暂未同步到后端');
    }
    return _apiClient.deleteNotification(
      token: _requireToken(),
      notificationId: notificationId,
    );
  }

  Future<List<CampusConversation>> fetchConversations() {
    return _apiClient.fetchConversations(token: _requireToken());
  }

  Future<CampusConversation> startConversation(CampusUser user) {
    final id = _requireUserId(user);
    return _apiClient.startConversation(token: _requireToken(), userId: id);
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

  Future<List<CampusGroup>> fetchManagedGroups() async {
    final groups = await _apiClient.fetchManagedGroups(token: _requireToken());
    return groups.map(_enrichGroup).toList(growable: false);
  }

  Future<CampusGroup> fetchGroupDetail(CampusGroup group) async {
    final id = _requireGroupId(group);
    return _enrichGroup(
      await _apiClient.fetchGroupDetail(id, token: AuthSession.token),
    );
  }

  Future<CampusGroup> createGroup({
    required String name,
    required String description,
    required String coverUrl,
    required String iconUrl,
    required List<String> tags,
    required String visibility,
  }) async {
    final group = await _apiClient.createGroup(
      token: _requireToken(),
      name: name,
      description: description,
      coverUrl: coverUrl,
      iconUrl: iconUrl,
      tags: tags,
      visibility: visibility,
    );
    final enriched = _enrichGroup(group);
    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: _cachedFeed.activities,
      groups: [enriched, ..._cachedFeed.groups],
      topics: _cachedFeed.topics,
    );
    return enriched;
  }

  Future<CampusGroup> updateGroup({
    required CampusGroup group,
    required String name,
    required String description,
    required String coverUrl,
    required String iconUrl,
    required List<String> tags,
    required String visibility,
  }) async {
    final id = _requireGroupId(group);
    return _replaceCachedGroup(
      await _apiClient.updateGroup(
        token: _requireToken(),
        groupId: id,
        name: name,
        description: description,
        coverUrl: coverUrl,
        iconUrl: iconUrl,
        tags: tags,
        visibility: visibility,
      ),
    );
  }

  Future<CampusGroup> updateGroupAnnouncement({
    required CampusGroup group,
    required String text,
  }) async {
    final id = _requireGroupId(group);
    return _replaceCachedGroup(
      await _apiClient.updateGroupAnnouncement(
        token: _requireToken(),
        groupId: id,
        text: text,
      ),
    );
  }

  Future<CampusPost> createGroupPost({
    required CampusGroup group,
    required String title,
    required String body,
    required String topic,
    required String location,
    List<String> images = const [],
  }) async {
    final groupId = _requireGroupId(group);
    final post = await _apiClient.createGroupPost(
      token: _requireToken(),
      groupId: groupId,
      title: title,
      body: body,
      topic: topic,
      location: location,
      images: images,
    );
    final nextPost = _replaceCachedPost(post);
    final updatedGroup = group.copyWith(
      discussions: [nextPost, ...group.discussions],
    );
    _replaceCachedGroup(updatedGroup);
    return nextPost;
  }

  Future<CampusGroup> toggleGroupDiscussionPin({
    required CampusGroup group,
    required CampusPost post,
    required bool pinned,
  }) async {
    final groupId = _requireGroupId(group);
    final postId = _requirePostId(post);
    return _replaceCachedGroup(
      await _apiClient.toggleGroupDiscussionPin(
        token: _requireToken(),
        groupId: groupId,
        postId: postId,
        pinned: pinned,
      ),
    );
  }

  Future<CampusActivity> createGroupActivity({
    required CampusGroup group,
    required String title,
    required String category,
    required String date,
    required String time,
    required String location,
    required String host,
    required int capacity,
    required String price,
    required String description,
    required List<String> tags,
    required bool allowComments,
    required bool publicDisplay,
    required String posterUrl,
  }) async {
    final groupId = _requireGroupId(group);
    final activity = await _apiClient.createGroupActivity(
      token: _requireToken(),
      groupId: groupId,
      title: title,
      category: category,
      date: date,
      time: time,
      location: location,
      host: host,
      capacity: capacity,
      price: price,
      description: description,
      tags: tags,
      allowComments: allowComments,
      publicDisplay: publicDisplay,
      posterUrl: posterUrl,
    );
    final enrichedActivity = _replaceCachedActivity(activity);
    final updatedGroup = group.copyWith(
      activities: [enrichedActivity, ...group.activities],
    );
    _replaceCachedGroup(updatedGroup);
    return enrichedActivity;
  }

  Future<void> deleteGroup(CampusGroup group) async {
    final id = _requireGroupId(group);
    await _apiClient.deleteGroup(token: _requireToken(), groupId: id);
    _removeCachedGroup(id);
  }

  Future<List<CampusGroupMember>> fetchGroupMembers(CampusGroup group) {
    final id = _requireGroupId(group);
    return _apiClient.fetchGroupMembers(token: _requireToken(), groupId: id);
  }

  Future<List<CampusGroupMember>> fetchGroupJoinRequests(CampusGroup group) {
    final id = _requireGroupId(group);
    return _apiClient.fetchGroupJoinRequests(
      token: _requireToken(),
      groupId: id,
    );
  }

  Future<CampusGroupMember> reviewGroupJoinRequest({
    required CampusGroup group,
    required CampusGroupMember request,
    required bool approved,
  }) {
    final groupId = _requireGroupId(group);
    if (request.id.isEmpty) {
      throw const CampusApiException('这条申请暂未同步到后端');
    }
    return _apiClient.reviewGroupJoinRequest(
      token: _requireToken(),
      groupId: groupId,
      membershipId: request.id,
      approved: approved,
    );
  }

  Future<CampusGroupMember> updateGroupMemberRole({
    required CampusGroup group,
    required CampusGroupMember member,
    required String role,
  }) {
    final groupId = _requireGroupId(group);
    if (member.id.isEmpty) {
      throw const CampusApiException('这位成员暂未同步到后端');
    }
    return _apiClient.updateGroupMemberRole(
      token: _requireToken(),
      groupId: groupId,
      membershipId: member.id,
      role: role,
    );
  }

  Future<void> removeGroupMember({
    required CampusGroup group,
    required CampusGroupMember member,
  }) {
    final groupId = _requireGroupId(group);
    if (member.id.isEmpty) {
      throw const CampusApiException('这位成员暂未同步到后端');
    }
    return _apiClient.removeGroupMember(
      token: _requireToken(),
      groupId: groupId,
      membershipId: member.id,
    );
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

  CampusSearchResult _filterSearchResult(
    CampusSearchResult result,
    String type,
  ) {
    return switch (type) {
      'users' => CampusSearchResult(
        users: result.users,
        posts: const [],
        activities: const [],
        groups: const [],
        topics: const [],
      ),
      'activities' => CampusSearchResult(
        users: const [],
        posts: const [],
        activities: result.activities,
        groups: const [],
        topics: const [],
      ),
      'posts' => CampusSearchResult(
        users: const [],
        posts: result.posts,
        activities: const [],
        groups: const [],
        topics: const [],
      ),
      'groups' => CampusSearchResult(
        users: const [],
        posts: const [],
        activities: const [],
        groups: result.groups,
        topics: const [],
      ),
      'topics' => CampusSearchResult(
        users: const [],
        posts: const [],
        activities: const [],
        groups: const [],
        topics: result.topics,
      ),
      _ => result,
    };
  }

  CampusSearchResult _sortSearchResult(CampusSearchResult result, String sort) {
    if (sort != 'popular') return result;
    return CampusSearchResult(
      users: [...result.users]
        ..sort((left, right) => right.followers.compareTo(left.followers)),
      posts: [...result.posts]
        ..sort(
          (left, right) => (right.likes + right.comments + right.saves)
              .compareTo(left.likes + left.comments + left.saves),
        ),
      activities: [...result.activities]
        ..sort((left, right) => right.enrolled.compareTo(left.enrolled)),
      groups: [...result.groups]
        ..sort((left, right) => right.members.compareTo(left.members)),
      topics: [...result.topics]
        ..sort((left, right) => right.onlineCount.compareTo(left.onlineCount)),
    );
  }

  CampusDiscover _normalizeDiscover(CampusDiscover discover) {
    return CampusDiscover(
      hotSearches: discover.hotSearches.isEmpty
          ? CampusDiscover.fromFeed(_cachedFeed).hotSearches
          : discover.hotSearches,
      trendingPosts: discover.trendingPosts,
      upcomingActivities: discover.upcomingActivities
          .map((activity) => _enrichActivity(activity, _cachedFeed.users))
          .toList(growable: false),
      recommendedGroups: discover.recommendedGroups
          .map(_enrichGroup)
          .toList(growable: false),
      featuredTopics: discover.featuredTopics
          .map(_enrichTopic)
          .toList(growable: false),
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

  void _removeCachedActivity(String activityId) {
    List<CampusActivity> remove(List<CampusActivity> activities) {
      return activities
          .where((activity) => activity.id != activityId)
          .toList(growable: false);
    }

    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: remove(_cachedFeed.activities),
      groups: _cachedFeed.groups
          .map((group) => group.copyWith(activities: remove(group.activities)))
          .toList(growable: false),
      topics: _cachedFeed.topics,
    );
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

  void _removeCachedGroup(String groupId) {
    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups
          .where((group) => group.id != groupId)
          .toList(growable: false),
      topics: _cachedFeed.topics,
    );
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
