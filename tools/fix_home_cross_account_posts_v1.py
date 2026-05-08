from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
REPO = Path("frontend/frontend/lib/repositories/campus_repository.dart")

main = MAIN.read_text()
repo = REPO.read_text()

# 1. 修复首页可见帖子过滤：不要再按标题过滤真实帖子
main = re.sub(
    r"""List<CampusPost> _visibleRealHomePosts\(Iterable<CampusPost> posts\) \{
.*?
\}
\s*
List<CampusPost> _realCampusPosts""",
    """List<CampusPost> _visibleRealHomePosts(Iterable<CampusPost> posts) {
  final seen = <String>{};
  final result = <CampusPost>[];

  for (final post in posts) {
    final id = post.id.trim();

    // 只过滤前端本地 sample_data 里的假帖子。
    // MongoDB 里的真实帖子都有 ObjectId，不能再按标题/正文误杀。
    if (id.isEmpty) continue;

    if (seen.add(id)) result.add(post);
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

List<CampusPost> _realCampusPosts""",
    main,
    count=1,
    flags=re.S,
)

MAIN.write_text(main)
print("✅ 已修复首页过滤：不再按标题过滤真实帖子")

# 2. 修复 Repository 顶部 _isDemoPost：只过滤 id 为空的前端假帖子
repo = re.sub(
    r"""bool _isDemoPost\(CampusPost post\) \{
.*?
\}
\s*
class CampusRepository""",
    """bool _isDemoPost(CampusPost post) {
  // 只把没有后端 id 的前端 sample_data 当作演示帖子。
  // 真实 MongoDB 帖子即使标题叫“测试帖子 / 动态标题测试”，也必须显示。
  return post.id.trim().isEmpty;
}

class CampusRepository""",
    repo,
    count=1,
    flags=re.S,
)

# 3. 修复 _isFrontendDemoPostV2：不再按标题/正文误杀真实帖子
repo = re.sub(
    r"""  bool _isFrontendDemoPostV2\(CampusPost post\) \{
.*?
  \}
\s*
  List<CampusPost> _stripFrontendDemoPostsV2""",
    """  bool _isFrontendDemoPostV2(CampusPost post) {
    // 只过滤前端本地假帖子。
    // 后端真实帖子不能按标题、正文、作者名过滤，否则换账号后会看不到别人发的测试帖。
    return post.id.trim().isEmpty;
  }

  List<CampusPost> _stripFrontendDemoPostsV2""",
    repo,
    count=1,
    flags=re.S,
)

REPO.write_text(repo)
print("✅ 已修复 Repository 演示帖子过滤逻辑")
