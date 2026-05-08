from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_home_real_user_header_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 增加真实用户过滤函数：过滤当前登录用户 + 演示用户
if "List<CampusUser> _visibleRealHomeUsers" not in text:
    insert_after = re.search(
        r"List<CampusPost> _visibleRealHomePosts\(Iterable<CampusPost> posts\) \{.*?\n\}\s*\n",
        text,
        re.S,
    )
    if not insert_after:
        raise SystemExit("❌ 没找到 _visibleRealHomePosts，请把 main_shell.dart 顶部发我")

    helper = """List<CampusUser> _visibleRealHomeUsers(Iterable<CampusUser> users) {
  const demoNames = <String>{
    '林小北',
    '陈可欣',
    '王子豪',
    '刘思雨',
    '张晓晨',
  };

  final currentUserId = AuthSession.user?.id.trim() ?? '';
  final seen = <String>{};
  final result = <CampusUser>[];

  for (final user in users) {
    final id = user.id.trim();
    final name = user.name.trim();

    if (id.isEmpty) continue;
    if (currentUserId.isNotEmpty && id == currentUserId) continue;
    if (demoNames.contains(name)) continue;

    final key = id.isNotEmpty ? id : name;
    if (seen.add(key)) result.add(user);
  }

  return result;
}

"""
    pos = insert_after.end()
    text = text[:pos] + helper + text[pos:]
    print("✅ 已新增 _visibleRealHomeUsers")
else:
    print("ℹ️ _visibleRealHomeUsers 已存在，跳过新增")

# 2. 首页 build 中 users 改为真实用户过滤；增加 currentName
old = """    final users = feed.users;
    final posts = _visibleRealHomePosts(feed.posts);
"""
new = """    final currentUser = AuthSession.user;
    final currentName = currentUser == null || currentUser.name.trim().isEmpty
        ? '同学'
        : currentUser.name.trim();
    final users = _visibleRealHomeUsers(feed.users);
    final posts = _visibleRealHomePosts(feed.posts);
"""

if old in text:
    text = text.replace(old, new, 1)
    print("✅ 首页 users 已改为真实用户过滤")
elif "final currentName =" in text and "_visibleRealHomeUsers(feed.users)" in text:
    print("ℹ️ 首页 currentName/users 已经改过")
else:
    print("⚠️ 没匹配到 HomeScreen build 的 users 定义，请检查 main_shell.dart 180 行附近")

# 3. 替换首页问候语：早上好，xxx -> 早上好，$currentName
text, count = re.subn(
    r"Text\(\s*'早上好，[^']*',\s*style:",
    "Text(\n                            '早上好，$currentName',\n                            style:",
    text,
    count=1,
    flags=re.S,
)

if count:
    print("✅ 首页问候语已改为 AuthSession.user")
else:
    print("⚠️ 没替换到首页问候语，可能已经改过")

# 4. 你可能认识的人：不要 skip(1)，因为当前用户已经过滤掉了
text = text.replace(
    "itemCount: users.skip(1).take(3).length,",
    "itemCount: users.take(3).length,",
)
text = text.replace(
    "final user = users[index + 1];",
    "final user = users[index];",
)

MAIN.write_text(text)
print("🎉 首页真实用户信息补丁完成")
