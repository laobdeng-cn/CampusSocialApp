from pathlib import Path
import re

ROOT = Path('.')
ROUTES = ROOT / 'backend/src/routes/index.js'
MODELS = ROOT / 'frontend/frontend/lib/models/campus_models.dart'
API = ROOT / 'frontend/frontend/lib/services/campus_api_client.dart'
REPO = ROOT / 'frontend/frontend/lib/repositories/campus_repository.dart'
MAIN = ROOT / 'frontend/frontend/lib/screens/main_shell.dart'

# ---------- backend: add public user profile endpoints ----------
routes = ROUTES.read_text()

if "const mongoose = require('mongoose');" not in routes:
    routes = routes.replace(
        "const express = require('express');",
        "const express = require('express');\nconst mongoose = require('mongoose');",
        1,
    )

backend_block = r'''
async function buildUserProfilePayload(userId, viewer = null) {
  if (!mongoose.Types.ObjectId.isValid(userId)) return null;

  const user = await User.findById(userId);
  if (!user) return null;

  const [followersCount, followingCount] = await Promise.all([
    Follow.countDocuments({ following: user._id }),
    Follow.countDocuments({ follower: user._id }),
  ]);

  let followedByMe = false;
  let followsMe = false;
  if (viewer?._id && String(viewer._id) !== String(user._id)) {
    const [viewerFollowsTarget, targetFollowsViewer] = await Promise.all([
      Follow.exists({ follower: viewer._id, following: user._id }),
      Follow.exists({ follower: user._id, following: viewer._id }),
    ]);
    followedByMe = Boolean(viewerFollowsTarget);
    followsMe = Boolean(targetFollowsViewer);
  }

  if (user.followers !== followersCount || user.following !== followingCount) {
    user.followers = followersCount;
    user.following = followingCount;
    await user.save();
  }

  const userPosts = await Post.find({
    author: user._id,
    visibility: { $ne: 'private' },
  })
    .populate('author')
    .sort({ createdAt: -1 })
    .lean();

  const postIds = userPosts.map((post) => post._id);

  const [likesReceivedCount, joinedEnrollments, createdActivities] =
    await Promise.all([
      postIds.length
        ? Like.countDocuments({ post: { $in: postIds } })
        : Promise.resolve(0),
      Enrollment.find({ user: user._id })
        .populate({ path: 'activity', populate: 'createdBy' })
        .sort({ createdAt: -1 })
        .lean(),
      Activity.find({ createdBy: user._id })
        .populate('createdBy')
        .sort({ createdAt: -1 })
        .lean(),
    ]);

  const activityMap = new Map();
  for (const enrollment of joinedEnrollments) {
    const activity = enrollment.activity;
    if (activity?._id) {
      activityMap.set(String(activity._id), activity);
    }
  }
  for (const activity of createdActivities) {
    if (activity?._id) {
      activityMap.set(String(activity._id), activity);
    }
  }

  const safeUser = {
    ...publicUser(user),
    followers: followersCount,
    following: followingCount,
    followedByMe,
    followsMe,
  };

  const posts = userPosts.map(serializePost);
  const activities = [...activityMap.values()].map(serializeActivity);

  return {
    user: safeUser,
    stats: {
      posts: posts.length,
      activities: activities.length,
      likesReceived: likesReceivedCount,
      followers: followersCount,
      following: followingCount,
    },
    posts,
    activities,
  };
}

router.get('/users/:id/profile', async (request, response, next) => {
  try {
    const viewer = await resolveOptionalUser(request);
    const profile = await buildUserProfilePayload(request.params.id, viewer);

    if (!profile) {
      response.status(404).json({ message: '用户不存在' });
      return;
    }

    response.json({ profile, ...profile });
  } catch (error) {
    next(error);
  }
});

router.get('/users/:id/posts', async (request, response, next) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(request.params.id)) {
      response.status(404).json({ message: '用户不存在' });
      return;
    }

    const user = await User.findById(request.params.id);
    if (!user) {
      response.status(404).json({ message: '用户不存在' });
      return;
    }

    const posts = await Post.find({
      author: user._id,
      visibility: { $ne: 'private' },
    })
      .populate('author')
      .sort({ createdAt: -1 })
      .lean();

    response.json({ posts: posts.map(serializePost) });
  } catch (error) {
    next(error);
  }
});

router.get('/users/:id/activities', async (request, response, next) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(request.params.id)) {
      response.status(404).json({ message: '用户不存在' });
      return;
    }

    const user = await User.findById(request.params.id);
    if (!user) {
      response.status(404).json({ message: '用户不存在' });
      return;
    }

    const [joinedEnrollments, createdActivities] = await Promise.all([
      Enrollment.find({ user: user._id })
        .populate({ path: 'activity', populate: 'createdBy' })
        .sort({ createdAt: -1 })
        .lean(),
      Activity.find({ createdBy: user._id })
        .populate('createdBy')
        .sort({ createdAt: -1 })
        .lean(),
    ]);

    const activityMap = new Map();
    for (const enrollment of joinedEnrollments) {
      const activity = enrollment.activity;
      if (activity?._id) activityMap.set(String(activity._id), activity);
    }
    for (const activity of createdActivities) {
      if (activity?._id) activityMap.set(String(activity._id), activity);
    }

    response.json({
      activities: [...activityMap.values()].map(serializeActivity),
    });
  } catch (error) {
    next(error);
  }
});

'''

if 'buildUserProfilePayload' not in routes:
    marker = "router.get('/users', async (_request, response, next) => {"
    if marker not in routes:
        raise SystemExit("❌ 后端没有找到 router.get('/users' 插入点")
    routes = routes.replace(marker, backend_block + '\n' + marker, 1)
    print('✅ 后端已新增用户主页接口')
else:
    print('ℹ️ 后端用户主页接口已存在，跳过')

ROUTES.write_text(routes)

# ---------- frontend model: CampusUserProfile ----------
models = MODELS.read_text()

profile_model_block = r'''
class CampusUserProfile {
  const CampusUserProfile({
    required this.user,
    required this.posts,
    required this.activities,
    required this.followingCount,
    required this.followersCount,
    required this.likesReceivedCount,
    required this.postCount,
    required this.activityCount,
  });

  final CampusUser user;
  final List<CampusPost> posts;
  final List<CampusActivity> activities;
  final int followingCount;
  final int followersCount;
  final int likesReceivedCount;
  final int postCount;
  final int activityCount;

  factory CampusUserProfile.fromJson(Map<String, dynamic> json) {
    final root = _readMap(json, 'profile') ?? json;
    final stats = _readMap(root, 'stats') ?? const <String, dynamic>{};

    final userJson = _readMap(root, 'user') ?? _readMap(json, 'user');
    final postsValue = root['posts'] ?? json['posts'];
    final activitiesValue = root['activities'] ?? json['activities'];

    final posts = postsValue is List
        ? postsValue
              .whereType<Map>()
              .map((item) => CampusPost.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false)
        : const <CampusPost>[];

    final activities = activitiesValue is List
        ? activitiesValue
              .whereType<Map>()
              .map(
                (item) => CampusActivity.fromJson(item.cast<String, dynamic>()),
              )
              .toList(growable: false)
        : const <CampusActivity>[];

    return CampusUserProfile(
      user: userJson == null
          ? CampusUser.fromJson(const {})
          : CampusUser.fromJson(userJson),
      posts: posts,
      activities: activities,
      followingCount: _readInt(stats, 'following'),
      followersCount: _readInt(stats, 'followers'),
      likesReceivedCount: _readInt(stats, 'likesReceived'),
      postCount: _readInt(stats, 'posts', fallback: posts.length),
      activityCount: _readInt(stats, 'activities', fallback: activities.length),
    );
  }
}

'''

if 'class CampusUserProfile' not in models:
    marker = '\nclass CampusUserSettings'
    if marker not in models:
        raise SystemExit('❌ 模型文件没有找到 CampusUserSettings 插入点')
    models = models.replace(marker, '\n' + profile_model_block + marker, 1)
    print('✅ 前端模型已新增 CampusUserProfile')
else:
    print('ℹ️ CampusUserProfile 已存在，跳过')

MODELS.write_text(models)

# ---------- frontend api client ----------
api = API.read_text()

api_methods_block = r'''
  Future<CampusUserProfile> fetchUserProfile({
    required String userId,
    String? token,
  }) async {
    final json = await _getJson('/api/users/$userId/profile', token: token);
    return CampusUserProfile.fromJson(json);
  }

  Future<List<CampusPost>> fetchUserPosts({
    required String userId,
    String? token,
  }) async {
    final json = await _getJson('/api/users/$userId/posts', token: token);
    final value = json['posts'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusPost.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<CampusActivity>> fetchUserActivities({
    required String userId,
    String? token,
  }) async {
    final json = await _getJson('/api/users/$userId/activities', token: token);
    final value = json['activities'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => CampusActivity.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

'''

if 'Future<CampusUserProfile> fetchUserProfile' not in api:
    marker = '  Future<CampusDiscover> fetchDiscover() async {'
    if marker not in api:
        raise SystemExit('❌ ApiClient 没找到 fetchDiscover 插入点')
    api = api.replace(marker, api_methods_block + marker, 1)
    print('✅ ApiClient 已新增用户主页接口封装')
else:
    print('ℹ️ ApiClient 用户主页方法已存在，跳过')

API.write_text(api)

# ---------- frontend repository ----------
repo = REPO.read_text()

repo_methods_block = r'''
  Future<CampusUserProfile> fetchUserProfile(CampusUser user) {
    final id = _requireUserId(user);
    return _apiClient.fetchUserProfile(token: AuthSession.token, userId: id);
  }

  Future<List<CampusPost>> fetchUserPosts(CampusUser user) {
    final id = _requireUserId(user);
    return _apiClient.fetchUserPosts(token: AuthSession.token, userId: id);
  }

  Future<List<CampusActivity>> fetchUserActivities(CampusUser user) async {
    final id = _requireUserId(user);
    final activities = await _apiClient.fetchUserActivities(
      token: AuthSession.token,
      userId: id,
    );
    return activities
        .map((activity) => _enrichActivity(activity, _cachedFeed.users))
        .toList(growable: false);
  }

'''

if 'Future<CampusUserProfile> fetchUserProfile' not in repo:
    marker = '  Future<List<CampusPost>> fetchMyPosts() async {'
    if marker not in repo:
        raise SystemExit('❌ Repository 没找到 fetchMyPosts 插入点')
    repo = repo.replace(marker, repo_methods_block + marker, 1)
    print('✅ Repository 已新增用户主页读取方法')
else:
    print('ℹ️ Repository 用户主页方法已存在，跳过')

REPO.write_text(repo)

# ---------- frontend UserProfileScreen: replace _loadProfile ----------
main = MAIN.read_text()

new_load_profile = r'''  Future<_RealUserProfileBundle> _loadProfile() async {
    final user = _displayUser;

    if (user.id.trim().isEmpty) {
      if (_isCurrentProfile) {
        return _loadCurrentProfileFallback(user);
      }

      return _RealUserProfileBundle.empty(user);
    }

    try {
      final profile = await CampusRepository.instance.fetchUserProfile(user);
      final profileUser = profile.user;

      if (_isCurrentProfile) {
        AuthSession.updateUser(
          profileUser.copyWith(
            followers: profile.followersCount,
            following: profile.followingCount,
          ),
        );
      }

      return _RealUserProfileBundle(
        user: profileUser.copyWith(
          followers: profile.followersCount,
          following: profile.followingCount,
        ),
        posts: profile.posts,
        activities: profile.activities,
        followingCount: profile.followingCount,
        followersCount: profile.followersCount,
        likesReceivedCount: profile.likesReceivedCount,
      );
    } catch (error) {
      if (_isCurrentProfile) {
        return _loadCurrentProfileFallback(
          user,
          errorMessage: _shellError(error),
        );
      }

      return _RealUserProfileBundle.empty(
        user,
        errorMessage: _shellError(error),
      );
    }
  }

  Future<_RealUserProfileBundle> _loadCurrentProfileFallback(
    CampusUser user, {
    String? errorMessage,
  }) async {
    try {
      final repo = CampusRepository.instance;

      final results = await Future.wait<Object>([
        repo.fetchMyPosts(),
        repo.fetchMyActivities(),
        repo.fetchCreatedActivities(),
        repo.fetchFollowing(),
        repo.fetchFollowers(),
        repo.fetchLikesReceived(),
      ]);

      final posts = results[0] as List<CampusPost>;
      final joinedActivities = results[1] as List<CampusActivity>;
      final createdActivities = results[2] as List<CampusActivity>;
      final following = results[3] as List<CampusUser>;
      final followers = results[4] as List<CampusUser>;
      final likesReceived = results[5] as List<CampusLikeRecord>;

      final activityMap = <String, CampusActivity>{};
      for (final activity in [...joinedActivities, ...createdActivities]) {
        final key = activity.id.isNotEmpty
            ? activity.id
            : '${activity.title}|${activity.date}|${activity.time}';
        activityMap[key] = activity;
      }

      return _RealUserProfileBundle(
        user: AuthSession.user ?? user,
        posts: posts,
        activities: activityMap.values.toList(growable: false),
        followingCount: following.length,
        followersCount: followers.length,
        likesReceivedCount: likesReceived.length,
        errorMessage: errorMessage,
      );
    } catch (fallbackError) {
      return _RealUserProfileBundle.empty(
        user,
        errorMessage: errorMessage ?? _shellError(fallbackError),
      );
    }
  }

'''

pattern = re.compile(
    r'  Future<_RealUserProfileBundle> _loadProfile\(\) async \{.*?\n  @override\n  Widget build',
    re.S,
)

if '_loadCurrentProfileFallback' not in main:
    match = pattern.search(main)
    if not match:
        raise SystemExit('❌ 没找到 UserProfileScreen 的 _loadProfile 方法，请把该方法上下文发我')
    main = main[:match.start()] + new_load_profile + '\n  @override\n  Widget build' + main[match.end():]
    print('✅ UserProfileScreen 已改为优先读取 /users/:id/profile')
else:
    print('ℹ️ UserProfileScreen 已有 fallback 方法，跳过')

MAIN.write_text(main)

print('\n🎉 用户主页真实数据第一步补丁完成')
