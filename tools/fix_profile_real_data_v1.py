from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_profile_real_data_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 给 UserProfileScreenState 增加真实数据状态
old_state = """class _UserProfileScreenState extends State<UserProfileScreen> {
  int _selectedTab = 0;

  static const _tabs = ['动态', '帖子', '活动', '相册'];
"""

new_state = """class _UserProfileScreenState extends State<UserProfileScreen> {
  int _selectedTab = 0;
  late Future<_ProfileRealData> _future;

  static const _tabs = ['动态', '帖子', '活动', '相册'];

  @override
  void initState() {
    super.initState();
    _future = _loadRealData();
  }

  bool get _isCurrentUser {
    final currentId = AuthSession.user?.id.trim() ?? '';
    final targetId = widget.user.id.trim();
    return currentId.isNotEmpty && targetId.isNotEmpty && currentId == targetId;
  }

  Future<_ProfileRealData> _loadRealData() async {
    final targetId = widget.user.id.trim();

    List<CampusPost> posts = CampusRepository.instance.cachedFeed.posts
        .where((post) => post.author.id.trim() == targetId)
        .toList(growable: false);

    List<CampusActivity> activities = const [];

    try {
      final feed = await CampusRepository.instance.fetchFeed();
      posts = feed.posts
          .where((post) => post.author.id.trim() == targetId)
          .toList(growable: false);
    } catch (_) {}

    if (_isCurrentUser) {
      try {
        posts = await CampusRepository.instance.fetchMyPosts();
      } catch (_) {}

      try {
        activities = await CampusRepository.instance.fetchMyActivities();
      } catch (_) {}
    }

    posts = posts
        .where((post) => post.id.trim().isNotEmpty)
        .toList(growable: false);

    posts.sort((left, right) {
      final leftTime = DateTime.tryParse(left.createdAt);
      final rightTime = DateTime.tryParse(right.createdAt);
      if (leftTime != null && rightTime != null) {
        return rightTime.compareTo(leftTime);
      }
      return 0;
    });

    final likes = posts.fold<int>(0, (sum, post) => sum + post.likes);

    return _ProfileRealData(
      posts: posts,
      activities: activities,
      likes: likes,
    );
  }
"""

if old_state in text:
    text = text.replace(old_state, new_state, 1)
    print("✅ 已增强 UserProfileScreenState")
else:
    print("⚠️ 没匹配到 _UserProfileScreenState 开头，可能已经改过")

# 2. 替换 UserProfileScreen build 主要内容，用 FutureBuilder 包真实数据
old_build = re.search(
    r"""  @override
  Widget build\(BuildContext context\) \{
    return Scaffold\(
      backgroundColor: Colors\.white,
      body: ListView\(
        padding: EdgeInsets\.zero,
        children: \[
          _UserProfileHeader\(user: widget\.user\),
          Padding\(
            padding: const EdgeInsets\.fromLTRB\(14, 0, 14, 12\),
            child: Column\(
              children: \[
                _ProfileShortcutCard\(user: widget\.user\),
                if \(_selectedTab == 0\) \.\.\.\[
                  const SizedBox\(height: 8\),
                  const _ProfileIntroCard\(\),
                \],
                const SizedBox\(height: 8\),
                _ProfileTabbedCard\(
                  tabs: _tabs,
                  selectedTab: _selectedTab,
                  onTabChanged: \(index\) \{
                    setState\(\(\) => _selectedTab = index\);
                  \},
                  child: switch \(_selectedTab\) \{
                    1 => _ProfilePostList\(
                      user: widget\.user,
                      showThirdPost: true,
                    \),
                    2 => const _ProfileActivityList\(\),
                    3 => const _ProfileAlbumList\(\),
                    _ => _ProfilePostList\(
                      user: widget\.user,
                      showThirdPost: false,
                    \),
                  \},
                \),
              \],
            \),
          \),
          const SizedBox\(height: 16\),
        \],
      \),
      bottomNavigationBar: BottomTabs\(
        currentIndex: 4,
        onTap: \(index\) => navigateToTab\(context, index\),
      \),
    \);
  \}
""",
    text,
    re.S,
)

new_build = """  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileRealData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _ProfileRealData.empty();

        return Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            onRefresh: () async {
              final next = _loadRealData();
              setState(() => _future = next);
              await next;
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _UserProfileHeader(
                  user: widget.user,
                  stats: data.statsFor(widget.user),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    children: [
                      _ProfileShortcutCard(user: widget.user),
                      if (_selectedTab == 0) ...[
                        const SizedBox(height: 8),
                        _ProfileIntroCard(user: widget.user),
                      ],
                      const SizedBox(height: 8),
                      _ProfileTabbedCard(
                        tabs: _tabs,
                        selectedTab: _selectedTab,
                        onTabChanged: (index) {
                          setState(() => _selectedTab = index);
                        },
                        child: switch (_selectedTab) {
                          1 => _RealProfilePostList(
                            user: widget.user,
                            posts: data.posts,
                          ),
                          2 => _RealProfileActivityList(
                            activities: data.activities,
                          ),
                          3 => _RealProfileAlbumList(posts: data.posts),
                          _ => _RealProfilePostList(
                            user: widget.user,
                            posts: data.posts,
                          ),
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
"""

if old_build:
    text = text[:old_build.start()] + new_build + text[old_build.end():]
    print("✅ 已替换 UserProfileScreen build 为真实数据版本")
else:
    print("⚠️ 没匹配到 UserProfileScreen build，可能需要手动处理")

# 3. 修改 _UserProfileHeader 构造：增加 stats 参数
text = text.replace(
    "const _UserProfileHeader({required this.user});",
    "const _UserProfileHeader({required this.user, required this.stats});",
)

text = text.replace(
    "final CampusUser user;\n\n  @override\n  Widget build(BuildContext context) {",
    "final CampusUser user;\n  final _ProfileStats stats;\n\n  @override\n  Widget build(BuildContext context) {",
    1,
)

# 4. 把 header 中固定数字替换为 stats
replacements = {
    "Text('128',": "Text('${stats.following}',",
    "Text('256',": "Text('${stats.followers}',",
    "Text('36',": "Text('${stats.likes}',",
    "Text('12',": "Text('${stats.activities}',",
}
for old, new in replacements.items():
    text = text.replace(old, new, 1)

# 5. ProfileIntroCard 改为接收真实 user，避免写死简介
text = text.replace(
    "class _ProfileIntroCard extends StatelessWidget {\n  const _ProfileIntroCard();",
    "class _ProfileIntroCard extends StatelessWidget {\n  const _ProfileIntroCard({required this.user});\n\n  final CampusUser user;",
)

text = text.replace(
    "热爱用镜头记录生活，喜欢探索校园的每一个角落。\\n希望通过摄影分享美好，也期待认识志同道合的朋友～",
    "${user.bio.trim().isEmpty ? '这个同学还没有填写简介。' : user.bio}",
)

text = text.replace(
    "加入学校：  计算机学院（双学位）",
    "加入学校：  ${user.school}",
)

# 6. 添加真实 Profile 数据组件
if "class _ProfileRealData" not in text:
    append = r'''

class _ProfileRealData {
  const _ProfileRealData({
    required this.posts,
    required this.activities,
    required this.likes,
  });

  final List<CampusPost> posts;
  final List<CampusActivity> activities;
  final int likes;

  factory _ProfileRealData.empty() {
    return const _ProfileRealData(
      posts: [],
      activities: [],
      likes: 0,
    );
  }

  _ProfileStats statsFor(CampusUser user) {
    return _ProfileStats(
      following: user.following,
      followers: user.followers,
      likes: likes,
      activities: activities.length,
    );
  }
}

class _ProfileStats {
  const _ProfileStats({
    required this.following,
    required this.followers,
    required this.likes,
    required this.activities,
  });

  final int following;
  final int followers;
  final int likes;
  final int activities;
}

class _RealProfilePostList extends StatelessWidget {
  const _RealProfilePostList({
    required this.user,
    required this.posts,
  });

  final CampusUser user;
  final List<CampusPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return CampusCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: const [
              Icon(Icons.article_outlined, color: AppColors.muted, size: 38),
              SizedBox(height: 10),
              Text(
                '暂无真实动态',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '发布帖子后，会显示在这里',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final post in posts) ...[
          _RealProfilePostTile(post: post),
          const Divider(height: 22),
        ],
      ],
    );
  }
}

class _RealProfilePostTile extends StatelessWidget {
  const _RealProfilePostTile({required this.post});

  final CampusPost post;

  @override
  Widget build(BuildContext context) {
    final image = post.images.isEmpty ? '' : post.images.first;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CampusAvatar(user: post.author, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
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
                        _friendlyTime(post.createdAt),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(width: 8),
                      _CompactBadge(
                        label: '# ${post.topic}',
                        color: AppColors.blue,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (image.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  SmartImage(
                    url: image,
                    width: 108,
                    height: 88,
                    borderRadius: 9,
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
    );
  }
}

class _RealProfileActivityList extends StatelessWidget {
  const _RealProfileActivityList({required this.activities});

  final List<CampusActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return CampusCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: const [
              Icon(Icons.event_available_outlined, color: AppColors.muted, size: 38),
              SizedBox(height: 10),
              Text(
                '暂无真实活动',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '报名或发布活动后，会显示在这里',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final activity in activities) ...[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            leading: SmartImage(
              url: activity.posterUrl,
              width: 58,
              height: 58,
              borderRadius: 12,
            ),
            title: Text(
              activity.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${activity.date} · ${activity.location}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityDetailScreen(activity: activity),
                ),
              );
            },
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _RealProfileAlbumList extends StatelessWidget {
  const _RealProfileAlbumList({required this.posts});

  final List<CampusPost> posts;

  @override
  Widget build(BuildContext context) {
    final images = posts
        .expand((post) => post.images)
        .where((image) => image.trim().isNotEmpty)
        .toList(growable: false);

    if (images.isEmpty) {
      return CampusCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: const [
              Icon(Icons.image_outlined, color: AppColors.muted, size: 38),
              SizedBox(height: 10),
              Text(
                '暂无真实相册',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '发布带图片的帖子后，会显示在这里',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        return SmartImage(
          url: images[index],
          height: 96,
          borderRadius: 10,
        );
      },
    );
  }
}

'''
    text += append
    print("✅ 已追加真实个人资料组件")
else:
    print("ℹ️ 真实个人资料组件已存在")

MAIN.write_text(text)
print("🎉 个人资料页真实化 v1 补丁完成")
