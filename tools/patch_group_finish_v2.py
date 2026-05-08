from pathlib import Path
import re

ROOT = Path.home() / "Desktop" / "CampusSocialApp"
REPO = ROOT / "frontend" / "frontend" / "lib" / "repositories" / "campus_repository.dart"
MAIN = ROOT / "frontend" / "frontend" / "lib" / "screens" / "main_shell.dart"
DETAIL = ROOT / "frontend" / "frontend" / "lib" / "screens" / "detail_pages.dart"

def read(path):
    return path.read_text(encoding="utf-8")

def write(path, text):
    path.write_text(text, encoding="utf-8")
    print(f"patched {path}")

def replace_block(text, start_marker, end_marker, new_block, label):
    start = text.find(start_marker)
    if start < 0:
        print(f"⚠️ 未找到 {label} start: {start_marker}")
        return text
    end = text.find(end_marker, start)
    if end < 0:
        print(f"⚠️ 未找到 {label} end: {end_marker}")
        return text
    return text[:start] + new_block + "\n\n" + text[end:]

def patch_repository():
    repo = read(REPO)
    old = repo

    # 1) fetchGroupDetail 拉到详情后同步缓存，保证详情页、社区页、管理台使用同一份 group 状态
    repo = replace_block(
        repo,
        "  Future<CampusGroup> fetchGroupDetail(CampusGroup group) async {",
        "  Future<CampusGroup> createGroup({",
        """  Future<CampusGroup> fetchGroupDetail(CampusGroup group) async {
    final id = _requireGroupId(group);
    final detail = _enrichGroup(
      await _apiClient.fetchGroupDetail(id, token: AuthSession.token),
    );
    return _replaceCachedGroup(detail);
  }""",
        "fetchGroupDetail",
    )

    # 2) _replaceCachedGroup 统一负责写缓存 + 发事件 + 触发 feedChanged
    repo = replace_block(
        repo,
        "  CampusGroup _replaceCachedGroup(CampusGroup nextGroup) {",
        "  void _removeCachedGroup(String groupId) {",
        """  CampusGroup _replaceCachedGroup(CampusGroup nextGroup) {
    final enriched = _enrichGroup(nextGroup);
    final exists = _cachedFeed.groups.any((group) => group.id == enriched.id);

    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: _cachedFeed.activities,
      groups: exists
          ? _cachedFeed.groups
                .map((group) => group.id == enriched.id ? enriched : group)
                .toList(growable: false)
          : [enriched, ..._cachedFeed.groups],
      topics: _cachedFeed.topics,
    );

    _emitSync(
      CampusEventType.groupChanged,
      refId: enriched.id,
      payload: enriched,
    );
    _emitFeedChanged();
    return enriched;
  }""",
        "_replaceCachedGroup",
    )

    # 3) 审核入群后即时刷新 group 详情；失败时做本地兜底
    repo = replace_block(
        repo,
        "  Future<CampusGroupMember> reviewGroupJoinRequest({",
        "  Future<CampusGroupMember> updateGroupMemberRole({",
        """  Future<CampusGroupMember> reviewGroupJoinRequest({
    required CampusGroup group,
    required CampusGroupMember request,
    required bool approved,
  }) async {
    final groupId = _requireGroupId(group);
    if (request.id.isEmpty) {
      throw const CampusApiException('这条申请暂未同步到后端');
    }

    final member = await _apiClient.reviewGroupJoinRequest(
      token: _requireToken(),
      groupId: groupId,
      membershipId: request.id,
      approved: approved,
    );

    try {
      final detail = await _apiClient.fetchGroupDetail(
        groupId,
        token: AuthSession.token,
      );
      _replaceCachedGroup(detail);
    } catch (_) {
      if (approved) {
        _replaceCachedGroup(group.copyWith(members: group.members + 1));
      } else {
        _emitSync(CampusEventType.groupChanged, refId: groupId);
        _emitFeedChanged();
      }
    }

    _emitSync(CampusEventType.notificationChanged);
    return member;
  }""",
        "reviewGroupJoinRequest",
    )

    # 4) 移除成员后即时刷新 group 详情；失败时做本地兜底
    repo = replace_block(
        repo,
        "  Future<void> removeGroupMember({",
        "  Future<CampusTopic> fetchTopicDetail(CampusTopic topic) async {",
        """  Future<void> removeGroupMember({
    required CampusGroup group,
    required CampusGroupMember member,
  }) async {
    final groupId = _requireGroupId(group);
    if (member.id.isEmpty) {
      throw const CampusApiException('这位成员暂未同步到后端');
    }

    await _apiClient.removeGroupMember(
      token: _requireToken(),
      groupId: groupId,
      membershipId: member.id,
    );

    try {
      final detail = await _apiClient.fetchGroupDetail(
        groupId,
        token: AuthSession.token,
      );
      _replaceCachedGroup(detail);
    } catch (_) {
      _replaceCachedGroup(
        group.copyWith(
          members: group.members <= 0 ? 0 : group.members - 1,
          admins: member.role == 'admin' && group.admins > 0
              ? group.admins - 1
              : group.admins,
        ),
      );
    }
  }""",
        "removeGroupMember",
    )

    if repo != old:
        write(REPO, repo)
    else:
        print("repo no changes")

def patch_main_shell():
    main = read(MAIN)
    old = main

    # 1) 社区页监听 group/feed 事件，审核、加入、退出、编辑后自动刷新推荐群组
    if "StreamSubscription<CampusDataEvent>? _communitySubscription;" not in main:
        main = main.replace(
            "class _CommunityScreenState extends State<CommunityScreen> {\n  CampusDiscover? _discover;\n  var _isLoadingDiscover = false;",
            """class _CommunityScreenState extends State<CommunityScreen> {
  CampusDiscover? _discover;
  StreamSubscription<CampusDataEvent>? _communitySubscription;
  var _isLoadingDiscover = false;""",
            1,
        )

        main = main.replace(
            """  @override
  void initState() {
    super.initState();
    _loadDiscover();
  }

  Future<void> _loadDiscover() async {""",
            """  @override
  void initState() {
    super.initState();
    _loadDiscover();
    _communitySubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.groupChanged ||
          event.type == CampusEventType.feedChanged) {
        _loadDiscover();
      }
    });
  }

  @override
  void dispose() {
    _communitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDiscover() async {""",
            1,
        )

    # 2) 推荐群组列表：已加入/审核中只展示状态，不让列表按钮误触退出
    main = main.replace(
        """        onPressed: _group.membershipStatus == 'pending' || _isSubmitting
            ? null
            : _toggleJoin,""",
        """        onPressed:
            _group.joined || _group.membershipStatus == 'pending' || _isSubmitting
            ? null
            : _toggleJoin,""",
        1,
    )

    if main != old:
        write(MAIN, main)
    else:
        print("main_shell no changes")

def patch_detail_pages():
    detail = read(DETAIL)
    old = detail

    # 1) 社群详情页监听 groupChanged，同步成员数、审核状态、公告、讨论、活动
    if "StreamSubscription<CampusDataEvent>? _groupSubscription;" not in detail:
        detail = detail.replace(
            """class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late CampusGroup _group = widget.group;
  var _isLoading = false;
  var _isSubmitting = false;""",
            """class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late CampusGroup _group = widget.group;
  StreamSubscription<CampusDataEvent>? _groupSubscription;
  var _isLoading = false;
  var _isSubmitting = false;""",
            1,
        )

        detail = detail.replace(
            """  @override
  void initState() {
    super.initState();
    Future<void>(() {""",
            """  @override
  void initState() {
    super.initState();
    _groupSubscription = CampusEventBus.instance.stream.listen(_handleGroupEvent);
    Future<void>(() {""",
            1,
        )

        detail = detail.replace(
            """  Future<void> _loadDetail() async {""",
            """  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }

  void _handleGroupEvent(CampusDataEvent event) {
    if (!mounted) return;
    if (!event.matches(CampusEventType.groupChanged, refId: _group.id)) return;

    final payload = event.payload;
    if (payload is CampusGroup && payload.id == _group.id) {
      setState(() => _group = payload);
      return;
    }

    for (final cached in CampusRepository.instance.cachedFeed.groups) {
      if (cached.id == _group.id) {
        setState(() => _group = cached);
        return;
      }
    }
  }

  Future<void> _loadDetail() async {""",
            1,
        )

    # 2) 加入社群后 pending 文案正确
    detail = detail.replace(
        """      _showMessage(
        context,
        group.joined ? '已加入 ${group.name}' : '已退出 ${group.name}',
      );""",
        """      _showMessage(
        context,
        group.membershipStatus == 'pending'
            ? '入群申请已提交，等待管理员审核'
            : group.joined
            ? '已加入 ${group.name}'
            : '已退出 ${group.name}',
      );""",
        1,
    )

    # 3) 热门讨论过滤空数据，避免空白圆点
    detail = detail.replace(
        """    final sortedDiscussions = [...group.discussions]
      ..sort((left, right) {
        if (left.pinnedInGroup == right.pinnedInGroup) return 0;
        return left.pinnedInGroup ? -1 : 1;
      });""",
        """    final sortedDiscussions = group.discussions
        .where(
          (post) =>
              post.title.trim().isNotEmpty || post.body.trim().isNotEmpty,
        )
        .toList(growable: true)
      ..sort((left, right) {
        if (left.pinnedInGroup == right.pinnedInGroup) return 0;
        return left.pinnedInGroup ? -1 : 1;
      });""",
        1,
    )

    # 4) 社群活动为空时不再使用 campusActivity 假数据
    detail = detail.replace(
        """                        CampusCard(
                          child: Column(
                            children:
                                (group.activities.isEmpty
                                        ? [campusActivity]
                                        : group.activities)
                                    .map(
                                      (activity) => _GroupActivityTile(
                                        activity: activity,
                                      ),
                                    )
                                    .toList(growable: false),
                          ),
                        ),""",
        """                        if (group.activities.isEmpty)
                          const CampusCard(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: Text(
                                  '暂无即将开展的活动',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            ),
                          )
                        else
                          CampusCard(
                            child: Column(
                              children: group.activities
                                  .map(
                                    (activity) => _GroupActivityTile(
                                      activity: activity,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),""",
        1,
    )

    # 5) 热门讨论为空时显示空状态
    detail = detail.replace(
        """                        CampusCard(
                          child: Column(
                            children: [
                              for (final post in sortedDiscussions)
                                _SimpleDiscussionTile(post: post),
                            ],
                          ),
                        ),""",
        """                        if (sortedDiscussions.isEmpty)
                          const CampusCard(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: Text(
                                  '暂无热门讨论',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            ),
                          )
                        else
                          CampusCard(
                            child: Column(
                              children: [
                                for (final post in sortedDiscussions)
                                  _SimpleDiscussionTile(post: post),
                              ],
                            ),
                          ),""",
        1,
    )

    # 6) 社群活动按钮显示真实状态
    if "String _groupActivityActionText(CampusActivity activity)" not in detail:
        marker = "class _GroupActivityTile extends StatelessWidget"
        helper = """String _groupActivityActionText(CampusActivity activity) {
  if (activity.isCheckedIn) return '已签到';
  if (activity.isEnded) return '已结束';
  if (activity.activityStatus == 'registered' ||
      activity.isCheckInNotStarted ||
      activity.isCheckInAvailable) {
    return '已报名';
  }
  if (activity.capacity > 0 && activity.enrolled >= activity.capacity) {
    return '已满员';
  }
  return '去报名';
}

"""
        if marker in detail:
            detail = detail.replace(marker, helper + marker, 1)
        else:
            print("⚠️ 未找到 _GroupActivityTile，跳过活动按钮 helper")

    detail = detail.replace(
        "child: const Text('报名中'),",
        "child: Text(_groupActivityActionText(activity)),",
        1,
    )

    # 7) 入群申请通过/拒绝后，当前列表立即移除，减少旧数据残留
    detail = replace_block(
        detail,
        "  Future<void> _review(CampusGroupMember request, bool approved) async {",
        "  @override\n  Widget build(BuildContext context) {",
        """  Future<void> _review(CampusGroupMember request, bool approved) async {
    final previousFuture = _future;

    setState(() {
      _future = previousFuture.then(
        (items) => items
            .where((item) => item.id != request.id)
            .toList(growable: false),
      );
    });

    try {
      await CampusRepository.instance.reviewGroupJoinRequest(
        group: widget.group,
        request: request,
        approved: approved,
      );
      if (!mounted) return;
      _showMessage(context, approved ? '已通过入群申请' : '已拒绝入群申请');
      _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _future = previousFuture);
      _showMessage(context, _friendlyError(error));
    }
  }""",
        "GroupJoinRequestsScreen._review",
    )

    if detail != old:
        write(DETAIL, detail)
    else:
        print("detail_pages no changes")

patch_repository()
patch_main_shell()
patch_detail_pages()

print("✅ group finish v2 patch done")
