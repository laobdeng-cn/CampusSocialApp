from pathlib import Path
import re
import shutil

ROOT = Path("/Users/beiyu/Desktop/CampusSocialApp")
MAIN = ROOT / "frontend/frontend/lib/screens/main_shell.dart"
REPO = ROOT / "frontend/frontend/lib/repositories/campus_repository.dart"

def backup(path: Path, suffix: str):
    bak = path.with_name(path.name + suffix)
    if not bak.exists():
        shutil.copy2(path, bak)
        print(f"✅ 已备份: {bak}")

def write_if_changed(path: Path, text: str):
    old = path.read_text()
    if old != text:
        path.write_text(text)
        print(f"✅ patched {path}")
    else:
        print(f"ℹ️ no change {path}")

def find_class_block(text: str, class_marker: str):
    start = text.find(class_marker)
    if start < 0:
        raise RuntimeError(f"找不到 class marker: {class_marker}")
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"找不到 class 左括号: {class_marker}")
    depth = 0
    for i in range(brace, len(text)):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1
    raise RuntimeError(f"class 括号不完整: {class_marker}")

backup(MAIN, ".bak_profile_real_sync_v1")
backup(REPO, ".bak_profile_real_sync_v1")

main = MAIN.read_text()
repo = REPO.read_text()

# =========================
# 1. Repository：补充 Profile 相关事件通知
# =========================

# createPost 后通知我的页面刷新
if "CampusEventType.profileChanged" not in repo[repo.find("Future<CampusPost> createPost"):repo.find("Future<List<CampusPost>> fetchMyPosts")]:
    repo = repo.replace(
        """    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: [post, ..._cachedFeed.posts],
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups,
      topics: _cachedFeed.topics,
    );
    return post;
  }

  Future<List<CampusPost>> fetchMyPosts() {""",
        """    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: [post, ..._cachedFeed.posts],
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups,
      topics: _cachedFeed.topics,
    );
    _emitSync(CampusEventType.postChanged, refId: post.id, payload: post);
    _emitSync(CampusEventType.profileChanged);
    _emitFeedChanged();
    return post;
  }

  Future<List<CampusPost>> fetchMyPosts() {""",
        1,
    )

# deletePost 后通知我的页面刷新
delete_start = repo.find("Future<void> deletePost")
delete_end = repo.find("Future<CampusPost> togglePostLike", delete_start)
if delete_start >= 0 and delete_end >= 0:
    delete_block = repo[delete_start:delete_end]
    if "CampusEventType.profileChanged" not in delete_block:
        delete_block = delete_block.replace(
            """    );
  }

  """,
            """    );
    _emitSync(CampusEventType.postChanged, refId: id);
    _emitSync(CampusEventType.profileChanged);
    _emitFeedChanged();
  }

  """,
            1,
        )
        repo = repo[:delete_start] + delete_block + repo[delete_end:]

# createComment 后通知我的评论/动态统计刷新
comment_start = repo.find("Future<({CampusComment comment, CampusPost post})> createComment")
comment_end = repo.find("Future<List<CampusComment>> fetchComments", comment_start)
if comment_start >= 0 and comment_end >= 0:
    comment_block = repo[comment_start:comment_end]
    if "CampusEventType.profileChanged" not in comment_block:
        comment_block = comment_block.replace(
            """    _replaceCachedPost(result.post);
    return result;
  }

  """,
            """    _replaceCachedPost(result.post);
    _emitSync(CampusEventType.postChanged, refId: id, payload: result.post);
    _emitSync(CampusEventType.profileChanged);
    _emitFeedChanged();
    return result;
  }

  """,
            1,
        )
        repo = repo[:comment_start] + comment_block + repo[comment_end:]

# clearHistory：清空浏览记录后通知我的页面刷新
repo = repo.replace(
    """  Future<void> clearHistory() {
    return _apiClient.clearHistory(token: _requireToken());
  }""",
    """  Future<void> clearHistory() async {
    await _apiClient.clearHistory(token: _requireToken());
    _emitSync(CampusEventType.profileChanged);
  }""",
)

# deleteDraft：删除草稿后通知我的页面刷新
repo = repo.replace(
    """  Future<void> deleteDraft(CampusDraft draft) {
    if (draft.id.isEmpty) {
      throw const CampusApiException('这条草稿暂未同步到后端');
    }
    return _apiClient.deleteDraft(token: _requireToken(), draftId: draft.id);
  }""",
    """  Future<void> deleteDraft(CampusDraft draft) async {
    if (draft.id.isEmpty) {
      throw const CampusApiException('这条草稿暂未同步到后端');
    }
    await _apiClient.deleteDraft(token: _requireToken(), draftId: draft.id);
    _emitSync(CampusEventType.profileChanged);
  }""",
)

# follow / unfollow：关注、取关后刷新关注/粉丝统计
repo = repo.replace(
    """  Future<CampusUser> followUser(CampusUser user) {
    final id = _requireUserId(user);
    return _apiClient.followUser(token: _requireToken(), userId: id);
  }

  Future<CampusUser> unfollowUser(CampusUser user) {
    final id = _requireUserId(user);
    return _apiClient.unfollowUser(token: _requireToken(), userId: id);
  }""",
    """  Future<CampusUser> followUser(CampusUser user) async {
    final id = _requireUserId(user);
    final next = await _apiClient.followUser(token: _requireToken(), userId: id);
    _emitSync(CampusEventType.profileChanged, refId: id, payload: next);
    return next;
  }

  Future<CampusUser> unfollowUser(CampusUser user) async {
    final id = _requireUserId(user);
    final next = await _apiClient.unfollowUser(token: _requireToken(), userId: id);
    _emitSync(CampusEventType.profileChanged, refId: id, payload: next);
    return next;
  }""",
)

# createGroup 也刷新我的社群统计
create_group_start = repo.find("Future<CampusGroup> createGroup")
create_group_end = repo.find("Future<CampusGroup> updateGroup", create_group_start)
if create_group_start >= 0 and create_group_end >= 0:
    block = repo[create_group_start:create_group_end]
    if "CampusEventType.profileChanged" not in block:
        block = block.replace(
            """    _emitFeedChanged();
    return enriched;
  }

  """,
            """    _emitFeedChanged();
    _emitSync(CampusEventType.profileChanged);
    return enriched;
  }

  """,
            1,
        )
        repo = repo[:create_group_start] + block + repo[create_group_end:]

# _replaceCachedGroup 兜底确保社群状态广播
group_replace_start = repo.find("CampusGroup _replaceCachedGroup")
if group_replace_start >= 0:
    group_replace_end = repo.find("void _removeCachedGroup", group_replace_start)
    block = repo[group_replace_start:group_replace_end]
    if "_emitSync(CampusEventType.groupChanged" not in block:
        block = block.replace(
            """    );
    return enriched;
  }

  """,
            """    );
    _emitSync(CampusEventType.groupChanged, refId: enriched.id, payload: enriched);
    _emitFeedChanged();
    return enriched;
  }

  """,
            1,
        )
        repo = repo[:group_replace_start] + block + repo[group_replace_end:]

write_if_changed(REPO, repo)

# =========================
# 2. main_shell：我的页面统计真实化 + EventBus 自动刷新
# =========================

needle = """class _ProfileScreenState extends State<ProfileScreen> {
  CampusUser get _user => AuthSession.user ?? xiaobei;

  Future<void> _openEditProfile() async {"""

replacement = """class _ProfileScreenState extends State<ProfileScreen> {
  CampusUser get _user => AuthSession.user ?? xiaobei;

  StreamSubscription<CampusDataEvent>? _profileSubscription;
  var _isLoadingProfileCounters = false;
  var _hasLoadedProfileCounters = false;

  int? _followingCount;
  int? _followersCount;
  int? _likedCount;
  int? _activityCount;
  int? _postCount;
  int? _commentCount;
  int? _favoriteCount;
  int? _favoritePostCount;
  int? _historyCount;
  int? _draftCount;
  int? _groupCount;

  String _countText(int? value) {
    if (value == null && _isLoadingProfileCounters) return '...';
    return '${value ?? 0}';
  }

  bool _shouldReloadProfileCounters(CampusDataEvent event) {
    return event.type == CampusEventType.feedChanged ||
        event.type == CampusEventType.postChanged ||
        event.type == CampusEventType.activityChanged ||
        event.type == CampusEventType.activityCommentChanged ||
        event.type == CampusEventType.groupChanged ||
        event.type == CampusEventType.profileChanged ||
        event.type == CampusEventType.notificationChanged;
  }

  @override
  void initState() {
    super.initState();
    _loadProfileCounters();
    _profileSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted || !_shouldReloadProfileCounters(event)) return;
      _loadProfileCounters(silent: true);
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileCounters({bool silent = false}) async {
    if (_isLoadingProfileCounters) return;
    if (mounted) setState(() => _isLoadingProfileCounters = true);

    try {
      final result = await Future.wait<dynamic>([
        CampusRepository.instance.fetchFollowing(),
        CampusRepository.instance.fetchFollowers(),
        CampusRepository.instance.fetchLikesReceived(),
        CampusRepository.instance.fetchMyActivities(),
        CampusRepository.instance.fetchMyPosts(),
        CampusRepository.instance.fetchMyComments(),
        CampusRepository.instance.fetchFavorites(),
        CampusRepository.instance.fetchHistory(),
        CampusRepository.instance.fetchDrafts(),
        CampusRepository.instance.fetchMyGroups(),
      ]);

      final following = result[0] as List<CampusUser>;
      final followers = result[1] as List<CampusUser>;
      final likes = result[2] as List<CampusLikeRecord>;
      final activities = result[3] as List<CampusActivity>;
      final posts = result[4] as List<CampusPost>;
      final comments = result[5] as List<CampusMyCommentRecord>;
      final favorites = result[6] as List<CampusFavoriteRecord>;
      final history = result[7] as List<CampusHistoryRecord>;
      final drafts = result[8] as List<CampusDraft>;
      final groups = result[9] as List<CampusGroup>;

      if (!mounted) return;
      setState(() {
        _followingCount = following.length;
        _followersCount = followers.length;
        _likedCount = likes.length;
        _activityCount = activities.length;
        _postCount = posts.length;
        _commentCount = comments.length;
        _favoriteCount = favorites.length;
        _favoritePostCount = favorites
            .where((record) => record.kind == 'post')
            .length;
        _historyCount = history.length;
        _draftCount = drafts.length;
        _groupCount = groups.length;
        _hasLoadedProfileCounters = true;
      });
    } catch (error) {
      if (mounted && !silent && !_hasLoadedProfileCounters) {
        _showShellMessage(context, _shellError(error));
      }
    } finally {
      if (mounted) setState(() => _isLoadingProfileCounters = false);
    }
  }

  Future<void> _openEditProfile() async {"""

if needle in main:
    main = main.replace(needle, replacement, 1)
else:
    print("⚠️ ProfileScreen state header 已处理或未匹配")

main = main.replace(
    "if (result != null && mounted) setState(() {});",
    """if (result != null && mounted) {
      setState(() {});
      _loadProfileCounters();
    }""",
    1,
)

main = main.replace(
    "value: '${user.following == 0 ? 128 : user.following}',",
    "value: _countText(_followingCount),",
)
main = main.replace(
    "value: '${user.followers == 0 ? 256 : user.followers}',",
    "value: _countText(_followersCount),",
)
main = main.replace("value: '36',\n                      label: '获赞',", "value: _countText(_likedCount),\n                      label: '获赞',")
main = main.replace("value: '12',\n                      label: '活动',", "value: _countText(_activityCount),\n                      label: '活动',")

main = main.replace("title: '我收藏的帖子',\n                          value: '56',", "title: '我收藏的帖子',\n                          value: _countText(_favoritePostCount),")
main = main.replace("title: '我参加的活动',\n                          value: '8',", "title: '我参加的活动',\n                          value: _countText(_activityCount),")
main = main.replace("title: '草稿箱',\n                          value: '3',", "title: '草稿箱',\n                          value: _countText(_draftCount),")

# 我的内容里补“我的社群”
if "title: '我的社群'," not in main:
    main = main.replace(
        """                        _ProfileListRow(
                          icon: Icons.drafts_outlined,
                          title: '草稿箱',""",
        """                        _ProfileListRow(
                          icon: Icons.groups_2_outlined,
                          title: '我的社群',
                          value: _countText(_groupCount),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const _MyGroupsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _ProfileListRow(
                          icon: Icons.drafts_outlined,
                          title: '草稿箱',""",
        1,
    )

# “我参加的活动”统一跳真实我的活动页
main = main.replace(
    "builder: (_) => const _JoinedActivitiesScreen(),",
    "builder: (_) => const _MyActivitiesScreen(),",
)

# =========================
# 3. 公共空状态卡片
# =========================
if "class _ProfileEmptyCard extends StatelessWidget" not in main:
    insert_at = main.find("class _MyPostsScreen extends StatefulWidget")
    empty_card = r"""
class _ProfileEmptyCard extends StatelessWidget {
  const _ProfileEmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Icon(icon, size: 46, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

"""
    if insert_at >= 0:
        main = main[:insert_at] + empty_card + main[insert_at:]
    else:
        print("⚠️ 找不到 _MyPostsScreen 插入点")

# =========================
# 4. 我的活动：替换 mock 为真实 fetchMyActivities
# =========================
if "class _MyActivitiesScreen extends StatelessWidget" in main:
    start, end = find_class_block(main, "class _MyActivitiesScreen extends StatelessWidget")
    new_my_activities = r"""
class _MyActivitiesScreen extends StatefulWidget {
  const _MyActivitiesScreen();

  @override
  State<_MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<_MyActivitiesScreen> {
  late Future<List<CampusActivity>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchMyActivities();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.activityChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.profileChanged) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = CampusRepository.instance.fetchMyActivities();
    });
  }

  bool _isEndedActivity(CampusActivity activity) {
    final status = activity.activityStatus.trim();
    return activity.isEnded ||
        status == 'ended' ||
        status == 'finished' ||
        status == 'completed';
  }

  bool _isUpcomingActivity(CampusActivity activity) {
    return activity.isCheckInNotStarted ||
        activity.activityStatus.trim() == 'registered';
  }

  String _statusLabel(CampusActivity activity) {
    if (activity.isCheckedIn) return '已签到';
    if (_isEndedActivity(activity)) return '已结束';
    if (activity.isCheckInAvailable) return '待签到';
    if (_isUpcomingActivity(activity)) return '已报名';
    return '已报名';
  }

  Color _statusColor(CampusActivity activity) {
    if (activity.isCheckedIn) return AppColors.green;
    if (_isEndedActivity(activity)) return AppColors.muted;
    if (activity.isCheckInAvailable) return AppColors.orange;
    return AppColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return _StatModuleShell(
      title: '我的活动',
      tabs: const ['全部', '进行中', '已结束'],
      child: FutureBuilder<List<CampusActivity>>(
        future: _future,
        builder: (context, snapshot) {
          final activities = snapshot.data ?? const <CampusActivity>[];
          final endedCount = activities.where(_isEndedActivity).length;
          final upcomingCount = activities.where(_isUpcomingActivity).length;
          final ongoingCount = activities.length - endedCount;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ActivitySummaryCard(
                      label: '进行中',
                      value: '$ongoingCount',
                      icon: Icons.flag_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActivitySummaryCard(
                      label: '即将开始',
                      value: '$upcomingCount',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActivitySummaryCard(
                      label: '已结束',
                      value: '$endedCount',
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  activities.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (activities.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.event_busy_outlined,
                  title: '暂无活动',
                  subtitle: '报名、签到或参与活动后，会自动显示在这里',
                )
              else
                for (final activity in activities) ...[
                  _MyActivityModuleCard(
                    title: activity.title,
                    image: activity.posterUrl,
                    time: '${activity.date}  ${activity.time}',
                    location: activity.location,
                    tags: [
                      _TinyTag(
                        label: _statusLabel(activity),
                        color: _statusColor(activity),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          );
        },
      ),
    );
  }
}

"""
    main = main[:start] + new_my_activities + main[end:]

# =========================
# 5. 我的社群页面
# =========================
if "class _MyGroupsScreen extends StatefulWidget" not in main:
    insert_at = main.find("class _BrowsingHistoryScreen extends StatefulWidget")
    my_groups = r"""
class _MyGroupsScreen extends StatefulWidget {
  const _MyGroupsScreen();

  @override
  State<_MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<_MyGroupsScreen> {
  late Future<List<CampusGroup>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchMyGroups();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.groupChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.profileChanged) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = CampusRepository.instance.fetchMyGroups();
    });
  }

  String _membershipLabel(CampusGroup group) {
    if (group.canManage) return '管理中';
    if (group.membershipStatus == 'pending') return '审核中';
    if (group.joined) return '已加入';
    return '未加入';
  }

  Color _membershipColor(CampusGroup group) {
    if (group.canManage) return AppColors.blue;
    if (group.membershipStatus == 'pending') return AppColors.orange;
    if (group.joined) return AppColors.green;
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '我的社群',
      child: FutureBuilder<List<CampusGroup>>(
        future: _future,
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <CampusGroup>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              CampusCard(
                child: Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? '正在同步社群数据'
                      : '共 ${groups.length} 个社群',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  groups.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (groups.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.groups_2_outlined,
                  title: '暂无社群',
                  subtitle: '加入或创建社群后，会自动显示在这里',
                )
              else
                for (final group in groups) ...[
                  CampusCard(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(group: group),
                        ),
                      );
                      if (mounted) _refresh();
                    },
                    child: Row(
                      children: [
                        SmartImage(
                          url: group.iconUrl,
                          width: 58,
                          height: 58,
                          borderRadius: 14,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${group.members} 位成员 · ${group.tags.take(2).join(' / ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 8),
                              Pill(
                                label: _membershipLabel(group),
                                color: _membershipColor(group),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

"""
    if insert_at >= 0:
        main = main[:insert_at] + my_groups + main[insert_at:]
    else:
        print("⚠️ 找不到 _BrowsingHistoryScreen 插入点，未插入 _MyGroupsScreen")

# =========================
# 6. 我的收藏：改为真实列表 + 实时刷新
# =========================
if "class _MyFavoritesScreen extends StatelessWidget" in main:
    start, end = find_class_block(main, "class _MyFavoritesScreen extends StatelessWidget")
    new_fav = r"""
class _MyFavoritesScreen extends StatefulWidget {
  const _MyFavoritesScreen({required this.user});

  final CampusUser user;

  @override
  State<_MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<_MyFavoritesScreen> {
  late Future<List<CampusFavoriteRecord>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchFavorites();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.activityChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.profileChanged) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = CampusRepository.instance.fetchFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '我的收藏',
      child: FutureBuilder<List<CampusFavoriteRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <CampusFavoriteRecord>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              CampusCard(
                child: Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? '正在同步收藏数据'
                      : '共 ${records.length} 条收藏',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  records.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (records.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.star_border_rounded,
                  title: '暂无收藏',
                  subtitle: '收藏帖子或活动后，会自动显示在这里',
                )
              else
                for (final record in records) ...[
                  _RealFavoriteRecordTile(record: record),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _RealFavoriteRecordTile extends StatelessWidget {
  const _RealFavoriteRecordTile({required this.record, this.postOnly = false});

  final CampusFavoriteRecord record;
  final bool postOnly;

  @override
  Widget build(BuildContext context) {
    final isActivity = record.kind == 'activity';
    final title = isActivity ? record.activity.title : record.post.title;
    final subtitle = isActivity
        ? '${record.activity.date}  ${record.activity.time} · ${record.activity.location}'
        : record.post.body;
    final image = isActivity
        ? record.activity.posterUrl
        : (record.post.images.isEmpty
              ? record.post.author.avatarUrl
              : record.post.images.first);

    return CampusCard(
      child: Row(
        children: [
          SmartImage(url: image, width: 72, height: 72, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pill(
                  label: isActivity ? '活动' : '帖子',
                  color: isActivity ? AppColors.green : AppColors.blue,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  '收藏于 ${_friendlyTime(record.createdAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

"""
    main = main[:start] + new_fav + main[end:]

# 我收藏的帖子页面
if "class _FavoritePostsScreen extends StatelessWidget" in main:
    start, end = find_class_block(main, "class _FavoritePostsScreen extends StatelessWidget")
    new_fav_posts = r"""
class _FavoritePostsScreen extends StatefulWidget {
  const _FavoritePostsScreen();

  @override
  State<_FavoritePostsScreen> createState() => _FavoritePostsScreenState();
}

class _FavoritePostsScreenState extends State<_FavoritePostsScreen> {
  late Future<List<CampusFavoriteRecord>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchFavorites();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.profileChanged) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = CampusRepository.instance.fetchFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '我收藏的帖子',
      child: FutureBuilder<List<CampusFavoriteRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final records = (snapshot.data ?? const <CampusFavoriteRecord>[])
              .where((record) => record.kind == 'post')
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              const _SegmentedFilterTabs(
                tabs: ['全部', '最新收藏', '最多点赞'],
                compact: true,
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  records.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (records.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.star_border_rounded,
                  title: '暂无收藏帖子',
                  subtitle: '收藏帖子后，会自动显示在这里',
                )
              else
                for (final record in records) ...[
                  _RealFavoriteRecordTile(record: record, postOnly: true),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

"""
    main = main[:start] + new_fav_posts + main[end:]

# =========================
# 7. 浏览记录：去掉 mock fallback + 实时刷新
# =========================
main = re.sub(
    r"class _BrowsingHistoryScreenState extends State<_BrowsingHistoryScreen> \{\n  late Future<List<CampusHistoryRecord>> _future;",
    """class _BrowsingHistoryScreenState extends State<_BrowsingHistoryScreen> {
  late Future<List<CampusHistoryRecord>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;""",
    main,
    count=1,
)

main = main.replace(
    """  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchHistory();
  }""",
    """  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchHistory();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.activityChanged ||
          event.type == CampusEventType.groupChanged) {
        setState(() => _future = CampusRepository.instance.fetchHistory());
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }""",
    1,
)

main = re.sub(
    r"children:\s*const\s*\[\s*_FallbackHistorySections\(\)\s*\],",
    """children: const [
                _ProfileEmptyCard(
                  icon: Icons.history_rounded,
                  title: '暂无浏览记录',
                  subtitle: '查看帖子、活动或社群详情后，会自动显示在这里',
                ),
              ],""",
    main,
    count=1,
)

# =========================
# 8. 草稿箱：去掉 mock fallback + 实时刷新
# =========================
main = re.sub(
    r"class _DraftBoxScreenState extends State<_DraftBoxScreen> \{\n  late Future<List<CampusDraft>> _future;",
    """class _DraftBoxScreenState extends State<_DraftBoxScreen> {
  late Future<List<CampusDraft>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;""",
    main,
    count=1,
)

# 只替换 DraftBoxScreen 内的 initState；如果已经被替换过不会重复
draft_start = main.find("class _DraftBoxScreenState extends State<_DraftBoxScreen>")
draft_end = main.find("class _FollowingScreen", draft_start)
if draft_start >= 0 and draft_end >= 0:
    block = main[draft_start:draft_end]
    if "_subscription = CampusEventBus.instance.stream.listen" not in block:
        block = block.replace(
            """  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchDrafts();
  }""",
            """  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchDrafts();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.feedChanged) {
        setState(() => _future = CampusRepository.instance.fetchDrafts());
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }""",
            1,
        )
        main = main[:draft_start] + block + main[draft_end:]

main = main.replace(
    "..._fallbackDraftTiles()",
    """const _ProfileEmptyCard(
                  icon: Icons.drafts_outlined,
                  title: '暂无草稿',
                  subtitle: '保存草稿后，会自动显示在这里',
                )""",
    1,
)

write_if_changed(MAIN, main)

print("✅ profile real sync v1 patch done")
