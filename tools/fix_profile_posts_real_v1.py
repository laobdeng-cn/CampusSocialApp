from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_profile_posts_real_v1")
if not bak.exists():
    bak.write_text(text)

start = text.find("class _ProfilePostList extends StatelessWidget {")
if start == -1:
    raise SystemExit("❌ 没找到 class _ProfilePostList")

end = text.find("CampusPost _profilePostForUser", start)
if end == -1:
    raise SystemExit("❌ 没找到 CampusPost _profilePostForUser，无法确定替换范围")

new_class = r'''class _ProfilePostList extends StatelessWidget {
  const _ProfilePostList({required this.user, required this.showThirdPost});

  final CampusUser user;
  final bool showThirdPost;

  bool _isTargetPost(CampusPost post) {
    final targetId = user.id.trim();
    final authorId = post.author.id.trim();

    if (targetId.isNotEmpty && authorId.isNotEmpty) {
      return targetId == authorId;
    }

    return post.author.name.trim() == user.name.trim();
  }

  bool _isCurrentProfile() {
    final authUser = AuthSession.user;
    if (authUser == null) return false;

    if (authUser.id.trim().isNotEmpty && user.id.trim().isNotEmpty) {
      return authUser.id.trim() == user.id.trim();
    }

    return authUser.name.trim() == user.name.trim();
  }

  Future<List<CampusPost>> _loadPosts() async {
    final seen = <String>{};
    final result = <CampusPost>[];

    void addPosts(Iterable<CampusPost> posts) {
      for (final post in posts) {
        if (post.id.trim().isEmpty) continue;
        if (!_isTargetPost(post)) continue;
        if (seen.add(post.id.trim())) {
          result.add(post);
        }
      }
    }

    addPosts(CampusRepository.instance.cachedFeed.posts);

    try {
      final feed = await CampusRepository.instance.fetchFeed();
      addPosts(feed.posts);
    } catch (_) {}

    if (_isCurrentProfile()) {
      try {
        final myPosts = await CampusRepository.instance.fetchMyPosts();
        addPosts(myPosts);
      } catch (_) {}
    }

    result.sort((left, right) {
      final leftTime = DateTime.tryParse(left.createdAt);
      final rightTime = DateTime.tryParse(right.createdAt);
      if (leftTime != null && rightTime != null) {
        return rightTime.compareTo(leftTime);
      }
      return 0;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusPost>>(
      future: _loadPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final posts = snapshot.data ?? const <CampusPost>[];

        if (posts.isEmpty) {
          return CampusCard(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: const [
                  Icon(
                    Icons.article_outlined,
                    color: AppColors.muted,
                    size: 38,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '暂无真实帖子',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '发布帖子后，会自动显示在这里',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < posts.length; i++) ...[
              _ProfilePostTile(post: posts[i]),
              if (i != posts.length - 1) const Divider(indent: 16, endIndent: 16),
            ],
          ],
        );
      },
    );
  }
}

'''

text = text[:start] + new_class + "\n" + text[end:]

# 个人资料页帖子时间改成友好时间，避免直接显示 ISO 时间
old = """Text(
                        post.createdAt,
                        style: const TextStyle(color: AppColors.muted),
                      ),"""
new = """Text(
                        _friendlyTime(post.createdAt),
                        style: const TextStyle(color: AppColors.muted),
                      ),"""

if old in text:
    text = text.replace(old, new, 1)
    print("✅ _ProfilePostTile 时间已改成友好时间")
else:
    print("⚠️ 没匹配到 post.createdAt 时间文本，可能已改过")

MAIN.write_text(text)
print("✅ 个人资料页动态/帖子列表已改为真实数据")
