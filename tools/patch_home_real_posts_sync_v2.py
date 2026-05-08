#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys

PROJECT = Path.home() / "Desktop" / "CampusSocialApp"
REPO = PROJECT / "frontend/frontend/lib/repositories/campus_repository.dart"
MAIN = PROJECT / "frontend/frontend/lib/screens/main_shell.dart"


def backup(path: Path, suffix: str) -> None:
    bak = path.with_name(path.name + suffix)
    if not bak.exists():
        shutil.copy2(path, bak)
        print(f"✅ 已备份: {bak}")
    else:
        print(f"ℹ️ 备份已存在: {bak}")


def find_method_block(text: str, signature: str) -> tuple[int, int]:
    start = text.find(signature)
    if start < 0:
        raise RuntimeError(f"找不到方法: {signature}")
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"找不到方法开始括号: {signature}")

    depth = 0
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1
    raise RuntimeError(f"找不到方法结束括号: {signature}")


def replace_method(text: str, signature: str, replacement: str) -> str:
    start, end = find_method_block(text, signature)
    return text[:start] + replacement.rstrip() + text[end:]


def patch_repository() -> None:
    text = REPO.read_text(encoding="utf-8")
    backup(REPO, ".bak_home_real_posts_sync_v2")

    helper = '''
  List<CampusPost> _mergeRealPostsForHomeV2({
    required Iterable<CampusPost> primary,
    required Iterable<CampusPost> extra,
  }) {
    final byId = <String, CampusPost>{};

    void addPost(CampusPost post) {
      final id = post.id.trim();
      if (id.isEmpty || _isDemoPost(post)) return;
      byId[id] = post;
    }

    for (final post in primary) {
      addPost(post);
    }
    for (final post in extra) {
      addPost(post);
    }

    final merged = byId.values.toList(growable: false);
    merged.sort((left, right) {
      final leftTime = DateTime.tryParse(left.createdAt);
      final rightTime = DateTime.tryParse(right.createdAt);
      if (leftTime != null && rightTime != null) {
        return rightTime.compareTo(leftTime);
      }
      if (leftTime != null) return -1;
      if (rightTime != null) return 1;
      return right.createdAt.compareTo(left.createdAt);
    });
    return merged;
  }

  CampusFeed _mergeExtraPostsIntoFeedV2(
    CampusFeed feed,
    Iterable<CampusPost> extraPosts,
  ) {
    final mergedPosts = _mergeRealPostsForHomeV2(
      primary: feed.posts,
      extra: extraPosts,
    );

    return CampusFeed(
      users: feed.users,
      posts: mergedPosts,
      activities: feed.activities,
      groups: feed.groups,
      topics: feed.topics
          .map(
            (topic) => topic.copyWith(
              posts: _mergeRealPostsForHomeV2(
                primary: topic.posts,
                extra: mergedPosts.where((post) => post.topic == topic.name),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

'''

    if "_mergeExtraPostsIntoFeedV2" not in text:
        marker = "  Future<CampusFeed> fetchFeed() async {"
        idx = text.find(marker)
        if idx < 0:
            raise RuntimeError("找不到 fetchFeed，用于插入真实帖子合并方法")
        text = text[:idx] + helper + text[idx:]
        print("✅ 已插入首页真实帖子合并方法")
    else:
        print("ℹ️ 首页真实帖子合并方法已存在，跳过插入")

    fetch_feed_replacement = '''
  Future<CampusFeed> fetchFeed() async {
    try {
      final remoteFeed = await _apiClient.fetchFeed();
      var nextFeed = _normalizeFeed(remoteFeed);

      final authToken = AuthSession.token;
      if (authToken?.isNotEmpty == true) {
        final token = authToken!;

        try {
          final myPosts = await _apiClient.fetchMyPosts(token: token);
          nextFeed = _mergeExtraPostsIntoFeedV2(nextFeed, myPosts);
        } catch (_) {
          // /api/feed 偶尔没有带上当前用户帖子时，至少保留本地缓存里的真实帖子。
          nextFeed = _mergeExtraPostsIntoFeedV2(nextFeed, _cachedFeed.posts);
        }

        try {
          final favorites = await _apiClient.fetchFavorites(token: token);
          _cacheFavoriteRecords(favorites);
        } catch (_) {
          // 收藏状态同步失败不影响首页真实帖子展示。
        }
      } else {
        nextFeed = _mergeExtraPostsIntoFeedV2(nextFeed, _cachedFeed.posts);
      }

      _cachedFeed = _applyFavoriteStateToFeed(nextFeed);
      _cachedFeed = _stripFrontendDemoFeedV2(_cachedFeed);
      return _cachedFeed;
    } catch (_) {
      _cachedFeed = _applyFavoriteStateToFeed(
        _mergeExtraPostsIntoFeedV2(_cachedFeed, const <CampusPost>[]),
      );
      _cachedFeed = _stripFrontendDemoFeedV2(_cachedFeed);
      return _cachedFeed;
    }
  }
'''
    text = replace_method(text, "  Future<CampusFeed> fetchFeed() async", fetch_feed_replacement)
    print("✅ 已替换 fetchFeed：/api/feed + /api/me/posts 合并")

    fetch_my_posts_replacement = '''
  Future<List<CampusPost>> fetchMyPosts() async {
    final posts = await _apiClient.fetchMyPosts(token: _requireToken());
    final realPosts = posts
        .where((post) => post.id.trim().isNotEmpty && !_isDemoPost(post))
        .toList(growable: false);

    _cachedFeed = _applyFavoriteStateToFeed(
      _mergeExtraPostsIntoFeedV2(_cachedFeed, realPosts),
    );
    _cachedFeed = _stripFrontendDemoFeedV2(_cachedFeed);
    _emitFeedChanged();
    return realPosts;
  }
'''
    text = replace_method(text, "  Future<List<CampusPost>> fetchMyPosts()", fetch_my_posts_replacement)
    print("✅ 已替换 fetchMyPosts：我的帖子也回写首页缓存")

    REPO.write_text(text, encoding="utf-8")


def patch_main_shell() -> None:
    text = MAIN.read_text(encoding="utf-8")
    backup(MAIN, ".bak_home_real_posts_sync_v2")

    old = '''                    for (final post in posts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PostFeedCard(post: post),
                      ),'''
    new = '''                    if (posts.isEmpty)
                      CampusCard(
                        padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              color: AppColors.muted,
                              size: 42,
                            ),
                            SizedBox(height: 10),
                            Text(
                              '暂无真实校园动态',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '发布一条帖子后，会自动显示在这里',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final post in posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: PostFeedCard(post: post),
                        ),'''
    if old in text and "暂无真实校园动态" not in text:
        text = text.replace(old, new, 1)
        print("✅ 首页校园动态已加入空状态")
    else:
        print("ℹ️ 首页空状态可能已存在，或结构已变，跳过")

    MAIN.write_text(text, encoding="utf-8")


def main() -> None:
    if not PROJECT.exists():
        print(f"❌ 找不到项目目录: {PROJECT}")
        sys.exit(1)
    if not REPO.exists():
        print(f"❌ 找不到文件: {REPO}")
        sys.exit(1)
    if not MAIN.exists():
        print(f"❌ 找不到文件: {MAIN}")
        sys.exit(1)

    print("====== 首页真实帖子同步补丁 v2 ======")
    patch_repository()
    patch_main_shell()
    print("✅ patch done")


if __name__ == "__main__":
    main()
