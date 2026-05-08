from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

start = text.find("class UserProfileScreen extends StatefulWidget")
end = text.find("\nconst _profileOwner", start)

if start == -1:
    raise SystemExit("❌ 没找到 UserProfileScreen")
if end == -1:
    raise SystemExit("❌ 没找到 const _profileOwner，无法确定替换范围")

new_block = r'''class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({required this.user, super.key});

  final CampusUser user;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _selectedTab = 0;
  late Future<_RealUserProfileBundle> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  static const _tabs = ['动态', '帖子', '活动', '相册'];

  bool get _isCurrentProfile {
    final authUser = AuthSession.user;
    if (authUser == null) return false;

    if (widget.user.id.isNotEmpty && authUser.id.isNotEmpty) {
      return widget.user.id == authUser.id;
    }

    return widget.user.name == authUser.name;
  }

  CampusUser get _displayUser {
    if (_isCurrentProfile) return AuthSession.user ?? widget.user;
    return widget.user;
  }

  @override
  void initState() {
    super.initState();
    _future = _loadProfile();

    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.activityChanged) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = _loadProfile();
    setState(() => _future = next);
    await next;
  }

  Future<_RealUserProfileBundle> _loadProfile() async {
    final user = _displayUser;

    // 当前后端已有的是“我的”相关接口。
    // 如果打开的是别人的主页，先只展示真实用户信息，不混入演示动态。
    if (!_isCurrentProfile) {
      return _RealUserProfileBundle.empty(user);
    }

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
      );
    } catch (error) {
      return _RealUserProfileBundle.empty(
        user,
        errorMessage: _shellError(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RealUserProfileBundle>(
      future: _future,
      builder: (context, snapshot) {
        final bundle =
            snapshot.data ?? _RealUserProfileBundle.empty(_displayUser);
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null;

        return Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (isLoading) const LinearProgressIndicator(minHeight: 2),
                _buildHeader(bundle),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    children: [
                      if (bundle.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        CampusCard(
                          child: Text(
                            bundle.errorMessage!,
                            style: const TextStyle(color: AppColors.red),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildShortcutCard(bundle.user),
                      const SizedBox(height: 8),
                      _buildIntroCard(bundle.user),
                      const SizedBox(height: 8),
                      CampusCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildTabBar(),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                              child: _buildTabContent(bundle),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
          bottomNavigationBar: BottomTabs(
            currentIndex: 4,
            onTap: (index) => navigateToTab(context, index),
          ),
        );
      },
    );
  }

  Widget _buildHeader(_RealUserProfileBundle bundle) {
    final user = bundle.user;
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Container(
          height: top + 172,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEAF4FF), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, top + 18, 18, 0),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.ink,
                      size: 36,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CampusAvatar(user: user, size: 96),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Pill(
                              label: user.school.isEmpty ? '未认证学校' : user.school,
                              color: AppColors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            if (user.major.trim().isNotEmpty) user.major,
                            if (user.grade.trim().isNotEmpty) user.grade,
                          ].join(' · ').isEmpty
                              ? '未填写专业信息'
                              : [
                                  if (user.major.trim().isNotEmpty) user.major,
                                  if (user.grade.trim().isNotEmpty) user.grade,
                                ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user.bio.trim().isEmpty
                              ? '这个同学还没有填写简介。'
                              : user.bio.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CampusCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('${bundle.followingCount}', '关注'),
                    _buildStat('${bundle.followersCount}', '粉丝'),
                    _buildStat('${bundle.likesReceivedCount}', '获赞'),
                    _buildStat('${bundle.activities.length}', '活动'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildShortcutCard(CampusUser user) {
    return CampusCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MyShortcut(
            icon: Icons.article_outlined,
            label: '我的帖子',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _MyPostsScreen(user: user)),
              );
            },
          ),
          _MyShortcut(
            icon: Icons.chat_bubble_outline,
            label: '我的评论',
            color: AppColors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _MyCommentsScreen(user: user)),
              );
            },
          ),
          _MyShortcut(
            icon: Icons.star_border_rounded,
            label: '我的收藏',
            color: AppColors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _MyFavoritesScreen(user: user)),
              );
            },
          ),
          _MyShortcut(
            icon: Icons.history,
            label: '浏览记录',
            color: AppColors.blueDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _BrowsingHistoryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard(CampusUser user) {
    return CampusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '个人简介',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.bio.trim().isEmpty ? '这个同学还没有填写简介。' : user.bio.trim(),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _infoChip(Icons.school_outlined, user.school),
              _infoChip(Icons.menu_book_outlined, user.major),
              _infoChip(Icons.workspace_premium_outlined, user.grade),
              if (user.role?.trim().isNotEmpty == true)
                _infoChip(Icons.verified_user_outlined, user.role!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String value) {
    final label = value.trim().isEmpty ? '未填写' : value.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blue, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.blue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        for (var index = 0; index < _tabs.length; index++)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Text(
                      _tabs[index],
                      style: TextStyle(
                        color: _selectedTab == index
                            ? AppColors.blue
                            : AppColors.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _selectedTab == index ? 30 : 0,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabContent(_RealUserProfileBundle bundle) {
    return switch (_selectedTab) {
      2 => _buildActivityList(bundle.activities),
      3 => _buildAlbumEmpty(),
      _ => _buildPostList(bundle.posts),
    };
  }

  Widget _buildPostList(List<CampusPost> posts) {
    if (posts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: '暂无真实动态',
        subtitle: '发布帖子后，会自动显示在这里',
      );
    }

    return Column(
      children: [
        for (final post in posts) ...[
          _ProfileRealPostTile(post: post),
          if (post != posts.last) const Divider(height: 26),
        ],
      ],
    );
  }

  Widget _buildActivityList(List<CampusActivity> activities) {
    if (activities.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available_outlined,
        title: '暂无真实活动',
        subtitle: '报名或创建活动后，会自动显示在这里',
      );
    }

    return Column(
      children: [
        for (final activity in activities) ...[
          _ProfileRealActivityTile(activity: activity),
          if (activity != activities.last) const Divider(height: 26),
        ],
      ],
    );
  }

  Widget _buildAlbumEmpty() {
    return _buildEmptyState(
      icon: Icons.photo_library_outlined,
      title: '暂无真实相册',
      subtitle: '当前后端还没有相册接口，暂不展示演示图片',
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 42),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RealUserProfileBundle {
  const _RealUserProfileBundle({
    required this.user,
    required this.posts,
    required this.activities,
    required this.followingCount,
    required this.followersCount,
    required this.likesReceivedCount,
    this.errorMessage,
  });

  final CampusUser user;
  final List<CampusPost> posts;
  final List<CampusActivity> activities;
  final int followingCount;
  final int followersCount;
  final int likesReceivedCount;
  final String? errorMessage;

  factory _RealUserProfileBundle.empty(
    CampusUser user, {
    String? errorMessage,
  }) {
    return _RealUserProfileBundle(
      user: user,
      posts: const [],
      activities: const [],
      followingCount: user.following,
      followersCount: user.followers,
      likesReceivedCount: 0,
      errorMessage: errorMessage,
    );
  }
}

class _ProfileRealPostTile extends StatelessWidget {
  const _ProfileRealPostTile({required this.post});

  final CampusPost post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampusAvatar(user: post.author, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.author.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _shellFriendlyTime(post.createdAt),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(width: 8),
                    _CompactBadge(label: '# ${post.topic}', color: AppColors.blue),
                    const Spacer(),
                    const Icon(Icons.more_horiz, color: AppColors.muted),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                    if (post.images.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      SmartImage(
                        url: post.images.first,
                        width: 108,
                        height: 82,
                        borderRadius: 10,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ProfileActionMetric(
                      icon: Icons.favorite_border_rounded,
                      value: post.likes,
                    ),
                    const SizedBox(width: 28),
                    _ProfileActionMetric(
                      icon: Icons.mode_comment_outlined,
                      value: post.comments,
                    ),
                    const SizedBox(width: 28),
                    _ProfileActionMetric(
                      icon: Icons.star_border_rounded,
                      value: post.saves,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRealActivityTile extends StatelessWidget {
  const _ProfileRealActivityTile({required this.activity});

  final CampusActivity activity;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activity: activity),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartImage(
            url: activity.posterUrl,
            width: 92,
            height: 76,
            borderRadius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${activity.date} ${activity.time}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  activity.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  '${activity.enrolled}/${activity.capacity} 人报名',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

'''

text = text[:start] + new_block + text[end:]
MAIN.write_text(text)

print("✅ 已替换 UserProfileScreen 为真实数据版")
