import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/campus_feed.dart';
import '../models/campus_models.dart';

class CampusApiClient {
  CampusApiClient({String? baseUrl, Duration? timeout})
    : baseUrl = baseUrl ?? _defaultBaseUrl(),
      timeout = timeout ?? const Duration(seconds: 2);

  final String baseUrl;
  final Duration timeout;

  Future<CampusFeed> fetchFeed() async {
    final json = await _getJson('/api/feed');
    return CampusFeed.fromJson(json);
  }

  Future<CampusSearchResult> search(String query) async {
    final json = await _getJson('/api/search', queryParameters: {'q': query});
    return CampusSearchResult.fromJson(json);
  }

  Future<CampusPost> createPost({
    required String token,
    required String title,
    required String body,
    required String topic,
    required String location,
    required List<String> images,
  }) async {
    final json = await _postJson('/api/posts', {
      'title': title,
      'body': body,
      'topic': topic,
      'location': location,
      'images': images,
    }, token: token);
    return _readPostPayload(json);
  }

  Future<List<CampusPost>> fetchMyPosts({required String token}) async {
    final json = await _getJson('/api/me/posts', token: token);
    final value = json['posts'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusPost.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<void> deletePost({
    required String token,
    required String postId,
  }) async {
    await _deleteJson('/api/posts/$postId', token: token);
  }

  Future<CampusPost> togglePostLike({
    required String token,
    required String postId,
  }) async {
    final json = await _postJson('/api/posts/$postId/like', {}, token: token);
    return _readPostPayload(json);
  }

  Future<CampusPost> togglePostFavorite({
    required String token,
    required String postId,
  }) async {
    final json = await _postJson(
      '/api/posts/$postId/favorite',
      {},
      token: token,
    );
    return _readPostPayload(json);
  }

  Future<({CampusComment comment, CampusPost post})> createComment({
    required String token,
    required String postId,
    required String text,
  }) async {
    final json = await _postJson('/api/posts/$postId/comments', {
      'text': text,
    }, token: token);
    return (comment: _readCommentPayload(json), post: _readPostPayload(json));
  }

  Future<List<CampusComment>> fetchComments(String postId) async {
    final json = await _getJson('/api/posts/$postId/comments');
    final value = json['comments'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusComment.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<CampusMyCommentRecord>> fetchMyComments({
    required String token,
  }) async {
    final json = await _getJson('/api/me/comments', token: token);
    final value = json['comments'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) =>
              CampusMyCommentRecord.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<void> deleteComment({
    required String token,
    required String commentId,
  }) async {
    await _deleteJson('/api/comments/$commentId', token: token);
  }

  Future<CampusActivity> joinActivity({
    required String token,
    required String activityId,
  }) async {
    final json = await _postJson(
      '/api/activities/$activityId/join',
      {},
      token: token,
    );
    return _readActivityPayload(json);
  }

  Future<CampusActivity> cancelActivityJoin({
    required String token,
    required String activityId,
  }) async {
    final json = await _deleteJson(
      '/api/activities/$activityId/join',
      token: token,
    );
    return _readActivityPayload(json);
  }

  Future<List<CampusActivity>> fetchMyActivities({
    required String token,
  }) async {
    final json = await _getJson('/api/me/activities', token: token);
    final value = json['activities'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusActivity.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<CampusCheckInRecord> checkInActivity({
    required String token,
    required String activityId,
    required String code,
  }) async {
    final json = await _postJson('/api/activities/$activityId/checkins', {
      'code': code,
    }, token: token);
    return _readCheckInPayload(json);
  }

  Future<List<CampusCheckInRecord>> fetchCheckInRecords({
    required String token,
  }) async {
    final json = await _getJson('/api/me/checkins', token: token);
    final value = json['checkIns'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => CampusCheckInRecord.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<CampusUser> updateProfile({
    required String token,
    required String name,
    required String school,
    required String major,
    required String grade,
    required String bio,
    required String avatarUrl,
  }) async {
    final json = await _patchJson('/api/me/profile', {
      'name': name,
      'school': school,
      'major': major,
      'grade': grade,
      'bio': bio,
      'avatarUrl': avatarUrl,
    }, token: token);
    return _readUserPayload(json);
  }

  Future<CampusUserSettings> fetchSettings({required String token}) async {
    final json = await _getJson('/api/me/settings', token: token);
    return _readSettingsPayload(json);
  }

  Future<CampusUserSettings> updateSettings({
    required String token,
    required CampusUserSettings settings,
  }) async {
    final json = await _patchJson(
      '/api/me/settings',
      settings.toJson(),
      token: token,
    );
    return _readSettingsPayload(json);
  }

  Future<List<CampusFavoriteRecord>> fetchFavorites({
    required String token,
  }) async {
    final json = await _getJson('/api/me/favorites', token: token);
    final value = json['favorites'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => CampusFavoriteRecord.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<List<CampusHistoryRecord>> fetchHistory({
    required String token,
  }) async {
    final json = await _getJson('/api/me/history', token: token);
    final value = json['history'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => CampusHistoryRecord.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<void> recordHistory({
    required String token,
    required String kind,
    required String title,
    String refId = '',
    String subtitle = '',
    String imageUrl = '',
  }) async {
    final body = <String, dynamic>{
      'kind': kind,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
    };
    if (refId.isNotEmpty) body['refId'] = refId;
    await _postJson('/api/me/history', body, token: token);
  }

  Future<void> clearHistory({required String token}) async {
    await _deleteJson('/api/me/history', token: token);
  }

  Future<List<CampusDraft>> fetchDrafts({required String token}) async {
    final json = await _getJson('/api/me/drafts', token: token);
    final value = json['drafts'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusDraft.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<CampusDraft> saveDraft({
    required String token,
    required String title,
    required String body,
    required String topic,
    required String location,
    required List<String> images,
    String kind = 'post',
    String status = 'draft',
  }) async {
    final json = await _postJson('/api/me/drafts', {
      'kind': kind,
      'title': title,
      'body': body,
      'topic': topic,
      'location': location,
      'images': images,
      'status': status,
    }, token: token);
    return _readDraftPayload(json);
  }

  Future<void> deleteDraft({
    required String token,
    required String draftId,
  }) async {
    await _deleteJson('/api/me/drafts/$draftId', token: token);
  }

  Future<List<CampusUser>> fetchFollowing({required String token}) async {
    final json = await _getJson('/api/me/following', token: token);
    return _readUserListPayload(json);
  }

  Future<List<CampusUser>> fetchFollowers({required String token}) async {
    final json = await _getJson('/api/me/followers', token: token);
    return _readUserListPayload(json);
  }

  Future<CampusUser> followUser({
    required String token,
    required String userId,
  }) async {
    final json = await _postJson('/api/users/$userId/follow', {}, token: token);
    return _readUserPayload(json);
  }

  Future<CampusUser> unfollowUser({
    required String token,
    required String userId,
  }) async {
    final json = await _deleteJson('/api/users/$userId/follow', token: token);
    return _readUserPayload(json);
  }

  Future<List<CampusLikeRecord>> fetchLikesReceived({
    required String token,
  }) async {
    final json = await _getJson('/api/me/likes-received', token: token);
    final value = json['records'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusLikeRecord.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<CampusNotificationRecord>> fetchNotifications({
    required String token,
    String? category,
  }) async {
    final json = await _getJson(
      '/api/me/notifications',
      token: token,
      queryParameters: category?.isNotEmpty == true
          ? {'category': category!}
          : null,
    );
    final value = json['notifications'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) =>
              CampusNotificationRecord.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<void> markNotificationsRead({required String token}) async {
    await _postJson('/api/me/notifications/read-all', {}, token: token);
  }

  Future<List<CampusConversation>> fetchConversations({
    required String token,
  }) async {
    final json = await _getJson('/api/me/conversations', token: token);
    final value = json['conversations'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => CampusConversation.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<List<CampusChatMessage>> fetchConversationMessages({
    required String token,
    required String conversationId,
  }) async {
    final json = await _getJson(
      '/api/conversations/$conversationId/messages',
      token: token,
    );
    final value = json['messages'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusChatMessage.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<CampusChatMessage> sendConversationMessage({
    required String token,
    required String conversationId,
    required String text,
  }) async {
    final json = await _postJson(
      '/api/conversations/$conversationId/messages',
      {'text': text},
      token: token,
    );
    return _readChatMessagePayload(json);
  }

  Future<CampusGroup> joinGroup({
    required String token,
    required String groupId,
  }) async {
    final json = await _postJson('/api/groups/$groupId/join', {}, token: token);
    return _readGroupPayload(json);
  }

  Future<CampusGroup> leaveGroup({
    required String token,
    required String groupId,
  }) async {
    final json = await _deleteJson('/api/groups/$groupId/join', token: token);
    return _readGroupPayload(json);
  }

  Future<List<CampusGroup>> fetchMyGroups({required String token}) async {
    final json = await _getJson('/api/me/groups', token: token);
    final value = json['groups'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusGroup.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<CampusGroup> fetchGroupDetail(String groupId) async {
    final json = await _getJson('/api/groups/$groupId');
    return _readGroupPayload(json);
  }

  Future<CampusTopic> fetchTopicDetail(String topicId) async {
    final json = await _getJson('/api/topics/$topicId');
    return _readTopicPayload(json);
  }

  Future<({String token, CampusUser user})> register({
    required String username,
    required String password,
    required String name,
  }) async {
    final json = await _postJson('/api/auth/register', {
      'username': username,
      'password': password,
      'name': name,
    });
    return _readAuthPayload(json);
  }

  Future<({String token, CampusUser user})> login({
    required String username,
    required String password,
  }) async {
    final json = await _postJson('/api/auth/login', {
      'username': username,
      'password': password,
    });
    return _readAuthPayload(json);
  }

  Future<CampusUser> verifyCampus({
    required String token,
    required String realName,
    required String campusName,
    required String studentId,
    required String major,
    required String enrollmentYear,
    required String campusRole,
  }) async {
    final json = await _postJson('/api/auth/campus-verify', {
      'realName': realName,
      'campusName': campusName,
      'studentId': studentId,
      'major': major,
      'enrollmentYear': enrollmentYear,
      'campusRole': campusRole,
    }, token: token);
    return _readUserPayload(json);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? queryParameters,
    String? token,
  }) async {
    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      path: path,
      queryParameters: queryParameters?.isEmpty == false
          ? queryParameters
          : null,
    );

    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.getUrl(uri).timeout(timeout);
      if (token?.isNotEmpty == true) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CampusApiException(
          'Request failed with ${response.statusCode}: $body',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();

      throw const CampusApiException('Response body is not a JSON object.');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse(baseUrl).replace(path: path);
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      if (token?.isNotEmpty == true) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.write(jsonEncode(body));

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);

      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody);
      final json = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? decoded.cast<String, dynamic>()
          : <String, dynamic>{};

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = json['message']?.toString();
        throw CampusApiException(
          message?.isNotEmpty == true
              ? message!
              : 'Request failed with ${response.statusCode}: $responseBody',
        );
      }

      return json;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse(baseUrl).replace(path: path);
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.patchUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      if (token?.isNotEmpty == true) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.write(jsonEncode(body));

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);

      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody);
      final json = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? decoded.cast<String, dynamic>()
          : <String, dynamic>{};

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = json['message']?.toString();
        throw CampusApiException(
          message?.isNotEmpty == true
              ? message!
              : 'Request failed with ${response.statusCode}: $responseBody',
        );
      }

      return json;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _deleteJson(String path, {String? token}) async {
    final uri = Uri.parse(baseUrl).replace(path: path);
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.deleteUrl(uri).timeout(timeout);
      if (token?.isNotEmpty == true) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);

      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody);
      final json = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? decoded.cast<String, dynamic>()
          : <String, dynamic>{};

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = json['message']?.toString();
        throw CampusApiException(
          message?.isNotEmpty == true
              ? message!
              : 'Request failed with ${response.statusCode}: $responseBody',
        );
      }

      return json;
    } finally {
      client.close(force: true);
    }
  }

  ({String token, CampusUser user}) _readAuthPayload(
    Map<String, dynamic> json,
  ) {
    final token = json['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const CampusApiException('Auth response is missing token.');
    }
    return (token: token, user: _readUserPayload(json));
  }

  CampusUser _readUserPayload(Map<String, dynamic> json) {
    final value = json['user'];
    if (value is Map<String, dynamic>) return CampusUser.fromJson(value);
    if (value is Map) return CampusUser.fromJson(value.cast<String, dynamic>());
    throw const CampusApiException('Auth response is missing user.');
  }

  CampusUserSettings _readSettingsPayload(Map<String, dynamic> json) {
    final value = json['settings'];
    if (value is Map<String, dynamic>) {
      return CampusUserSettings.fromJson(value);
    }
    if (value is Map) {
      return CampusUserSettings.fromJson(value.cast<String, dynamic>());
    }
    throw const CampusApiException('Response is missing settings.');
  }

  List<CampusUser> _readUserListPayload(Map<String, dynamic> json) {
    final value = json['users'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusUser.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  CampusPost _readPostPayload(Map<String, dynamic> json) {
    final value = json['post'];
    if (value is Map<String, dynamic>) return CampusPost.fromJson(value);
    if (value is Map) return CampusPost.fromJson(value.cast<String, dynamic>());
    throw const CampusApiException('Response is missing post.');
  }

  CampusActivity _readActivityPayload(Map<String, dynamic> json) {
    final value = json['activity'];
    if (value is Map<String, dynamic>) return CampusActivity.fromJson(value);
    if (value is Map) {
      return CampusActivity.fromJson(value.cast<String, dynamic>());
    }
    throw const CampusApiException('Response is missing activity.');
  }

  CampusGroup _readGroupPayload(Map<String, dynamic> json) {
    final value = json['group'];
    if (value is Map<String, dynamic>) return CampusGroup.fromJson(value);
    if (value is Map) {
      return CampusGroup.fromJson(value.cast<String, dynamic>());
    }
    throw const CampusApiException('Response is missing group.');
  }

  CampusTopic _readTopicPayload(Map<String, dynamic> json) {
    final value = json['topic'];
    if (value is Map<String, dynamic>) return CampusTopic.fromJson(value);
    if (value is Map) {
      return CampusTopic.fromJson(value.cast<String, dynamic>());
    }
    throw const CampusApiException('Response is missing topic.');
  }

  CampusComment _readCommentPayload(Map<String, dynamic> json) {
    final value = json['comment'];
    if (value is Map<String, dynamic>) return CampusComment.fromJson(value);
    if (value is Map) {
      return CampusComment.fromJson(value.cast<String, dynamic>());
    }
    throw const CampusApiException('Response is missing comment.');
  }

  CampusCheckInRecord _readCheckInPayload(Map<String, dynamic> json) {
    final value = json['checkIn'];
    if (value is Map<String, dynamic>) {
      return CampusCheckInRecord.fromJson(value);
    }
    if (value is Map) {
      return CampusCheckInRecord.fromJson(value.cast<String, dynamic>());
    }
    throw const CampusApiException('Response is missing check-in record.');
  }

  CampusChatMessage _readChatMessagePayload(Map<String, dynamic> json) {
    final value = json['message'];
    if (value is Map<String, dynamic>) {
      return CampusChatMessage.fromJson(value);
    }
    if (value is Map) {
      return CampusChatMessage.fromJson(value.cast<String, dynamic>());
    }
    throw const CampusApiException('Response is missing chat message.');
  }

  CampusDraft _readDraftPayload(Map<String, dynamic> json) {
    final value = json['draft'];
    if (value is Map<String, dynamic>) return CampusDraft.fromJson(value);
    if (value is Map) {
      return CampusDraft.fromJson(value.cast<String, dynamic>());
    }
    throw const CampusApiException('Response is missing draft.');
  }

  static String _defaultBaseUrl() {
    const fromDefine = String.fromEnvironment('CAMPUS_API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://127.0.0.1:4000';
  }
}

class CampusApiException implements Exception {
  const CampusApiException(this.message);

  final String message;

  @override
  String toString() => 'CampusApiException: $message';
}
