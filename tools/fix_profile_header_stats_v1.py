from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_profile_header_stats_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 在 _UserProfileHeader.build 里加入 stats 变量
old = """    final profileBio = _profileBioFor(user);
    final profileGrade = _profileGradeFor(user);
    final profileClub = _profileClubFor(user);
"""
new = """    final profileBio = _profileBioFor(user);
    final profileGrade = _profileGradeFor(user);
    final profileClub = _profileClubFor(user);
    final profileStats = _profileStatsFor(user);
"""

if old in text:
    text = text.replace(old, new, 1)
    print("✅ 已在 _UserProfileHeader.build 中加入 profileStats")
elif "final profileStats = _profileStatsFor(user);" in text:
    print("ℹ️ profileStats 已存在")
else:
    print("⚠️ 没匹配到 _UserProfileHeader.build 的 profileBio/profileGrade/profileClub 位置")

# 2. 替换 header 里固定数字：128 / 256 / 36 / 12
# 只替换第一次出现的固定统计数字，避免影响其他页面。
pairs = [
    ("'128'", "'${profileStats.following}'"),
    ("'256'", "'${profileStats.followers}'"),
    ("'36'", "'${profileStats.likes}'"),
    ("'12'", "'${profileStats.activities}'"),
]

for old_value, new_value in pairs:
    if old_value in text:
        text = text.replace(old_value, new_value, 1)
        print(f"✅ 已替换 {old_value} -> {new_value}")
    else:
        print(f"⚠️ 没找到 {old_value}，可能已经替换过")

# 3. 增加真实统计模型和计算函数
if "class _ProfileHeaderStats" not in text:
    helper = r'''

class _ProfileHeaderStats {
  const _ProfileHeaderStats({
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

_ProfileHeaderStats _profileStatsFor(CampusUser user) {
  final targetId = user.id.trim();
  final targetName = user.name.trim();

  bool isTargetPost(CampusPost post) {
    final authorId = post.author.id.trim();
    final authorName = post.author.name.trim();

    if (targetId.isNotEmpty && authorId.isNotEmpty) {
      return targetId == authorId;
    }

    return targetName.isNotEmpty && authorName == targetName;
  }

  final posts = CampusRepository.instance.cachedFeed.posts
      .where(isTargetPost)
      .toList(growable: false);

  final likes = posts.fold<int>(0, (sum, post) => sum + post.likes);

  final isCurrentUser = AuthSession.user != null &&
      ((targetId.isNotEmpty &&
              AuthSession.user!.id.trim().isNotEmpty &&
              targetId == AuthSession.user!.id.trim()) ||
          (targetName.isNotEmpty && targetName == AuthSession.user!.name.trim()));

  final activityCount = isCurrentUser
      ? CampusRepository.instance.cachedFeed.activities.length
      : 0;

  return _ProfileHeaderStats(
    following: user.following,
    followers: user.followers,
    likes: likes,
    activities: activityCount,
  );
}

'''
    text = text + helper
    print("✅ 已新增 _ProfileHeaderStats / _profileStatsFor")
else:
    print("ℹ️ _ProfileHeaderStats 已存在")

MAIN.write_text(text)
print("🎉 个人资料页顶部统计真实化 v1 完成")
