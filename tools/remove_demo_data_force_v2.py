from pathlib import Path
import re

ROOT = Path(".")
SERVER = ROOT / "backend/src/server.js"
FEED = ROOT / "backend/src/feedRoutes.js"
MAIN = ROOT / "frontend/frontend/lib/screens/main_shell.dart"
REPO = ROOT / "frontend/frontend/lib/repositories/campus_repository.dart"

# ---------- 1. 禁用启动时 seed ----------
if SERVER.exists():
    server = SERVER.read_text()
    server_bak = SERVER.with_suffix(SERVER.suffix + ".bak_force_remove_demo_v2")
    if not server_bak.exists():
        server_bak.write_text(server)

    server = server.replace(
        "connectToMongo()\n  .then(seedDemoData)\n  .catch((error) => {",
        "connectToMongo()\n  .then(async () => {\n    if (process.env.ENABLE_DEMO_SEED === 'true') {\n      await seedDemoData();\n    } else {\n      console.log('Demo data seed disabled.');\n    }\n  })\n  .catch((error) => {",
    )

    server = server.replace(
        ".then(seedDemoData)",
        ".then(async () => { if (process.env.ENABLE_DEMO_SEED === 'true') await seedDemoData(); else console.log('Demo data seed disabled.'); })",
    )

    SERVER.write_text(server)
    print("✅ server.js：已确保默认不自动注入演示数据")

# ---------- 2. 强制修 feedRoutes：只返回 MongoDB 真实数据 ----------
if FEED.exists():
    feed = FEED.read_text()
    feed_bak = FEED.with_suffix(FEED.suffix + ".bak_force_remove_demo_v2")
    if not feed_bak.exists():
        feed_bak.write_text(feed)

    if "const Post = require('./models/Post');" not in feed:
        feed = feed.replace(
            "const Activity = require('./models/Activity');",
            "const Activity = require('./models/Activity');\nconst Post = require('./models/Post');",
            1,
        )

    if "function serializePost(post)" not in feed:
        insert = """function serializePost(post) {
  if (!post) return null;
  const plain = typeof post.toObject === 'function' ? post.toObject() : post;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    groupId: plain.group ? String(plain.group._id || plain.group.id || plain.group) : '',
    author: publicUser(plain.author),
    createdAt: plain.createdAt instanceof Date ? plain.createdAt.toISOString() : plain.createdAt,
    updatedAt: plain.updatedAt instanceof Date ? plain.updatedAt.toISOString() : plain.updatedAt,
  };
}

"""
        marker = "function parseActivitySchedule(activity) {"
        if marker in feed:
            feed = feed.replace(marker, insert + marker, 1)
        else:
            feed = insert + feed

    helper = """const DEMO_USER_NAMES = new Set([
  '林小北',
  '陈可欣',
  '王子豪',
  '刘思雨',
  '张晓晨',
  'user123',
]);

const DEMO_POST_TITLES = new Set([
  '校园日落拍摄地推荐',
  '新图书馆自习位怎么预约？求攻略！',
  '高效复习时间表分享，亲测有效！',
  '各科目复习资料大合集（持续更新）',
  '图书馆自习打卡',
  '食堂新品测评｜芝士焗饭绝了！',
]);

const DEMO_ACTIVITY_TITLES = new Set([
  '校园音乐之夜',
  '摄影社团采风活动',
  '设计作品分享会',
]);

function isDemoUserPayload(user) {
  if (!user) return false;
  return DEMO_USER_NAMES.has(user.name) || String(user.username || '').startsWith('seed_');
}

function isDemoPostPayload(post) {
  if (!post) return false;
  return DEMO_POST_TITLES.has(String(post.title || '').trim()) || isDemoUserPayload(post.author);
}

function isDemoActivityPayload(activity) {
  if (!activity) return false;
  return DEMO_ACTIVITY_TITLES.has(String(activity.title || '').trim());
}

"""

    if "function isDemoPostPayload(post)" not in feed:
        if "const seed = require('./data/seed');" in feed:
            feed = feed.replace("const seed = require('./data/seed');", "const seed = require('./data/seed');\n\n" + helper, 1)
        else:
            feed = helper + feed

    new_feed_route = """router.get('/feed', async (request, response, next) => {
  try {
    const [users, posts, activities] = await Promise.all([
      User.find().sort({ createdAt: -1 }).lean(),
      Post.find({ visibility: { $ne: 'private' } })
        .populate('author')
        .sort({ createdAt: -1 })
        .lean(),
      Activity.find({ publicDisplay: { $ne: false } })
        .populate('createdBy')
        .sort({ enrolled: -1, createdAt: -1 })
        .lean(),
    ]);

    const realPosts = posts
      .map((post) => serializePost(post))
      .filter((post) => post && post.id && post.author && !isDemoPostPayload(post));

    const realActivities = activities
      .map((activity) => serializeActivity(activity))
      .filter((activity) => activity && activity.id && !isDemoActivityPayload(activity));

    response.json({
      users: users.map(publicUser).filter((user) => !isDemoUserPayload(user)),
      posts: realPosts,
      activities: realActivities,
      groups: [],
      topics: [],
    });
  } catch (error) {
    next(error);
  }
});"""

    pattern = re.compile(
        r"router\.get\('/feed', async \(request, response, next\) => \{.*?\n\}\);",
        re.S,
    )

    feed, count = pattern.subn(new_feed_route, feed, count=1)
    if count == 0:
        print("⚠️ feedRoutes.js：没有匹配到 router.get('/feed')，请手动检查")
    else:
        print("✅ feedRoutes.js：已强制改成只返回真实 MongoDB 数据，并过滤 seed 演示内容")

    FEED.write_text(feed)

# ---------- 3. 前端双保险：显示层继续过滤演示标题/演示用户 ----------
if MAIN.exists():
    main = MAIN.read_text()
    main_bak = MAIN.with_suffix(MAIN.suffix + ".bak_force_remove_demo_v2")
    if not main_bak.exists():
        main_bak.write_text(main)

    new_visible = """List<CampusPost> _visibleRealHomePosts(Iterable<CampusPost> posts) {
  const demoTitles = <String>{
    '校园日落拍摄地推荐',
    '新图书馆自习位怎么预约？求攻略！',
    '高效复习时间表分享，亲测有效！',
    '各科目复习资料大合集（持续更新）',
    '图书馆自习打卡',
    '食堂新品测评｜芝士焗饭绝了！',
  };

  const demoAuthors = <String>{
    '林小北',
    '陈可欣',
    '王子豪',
    '刘思雨',
    '张晓晨',
  };

  final seen = <String>{};
  final result = <CampusPost>[];

  for (final post in posts) {
    final id = post.id.trim();
    if (id.isEmpty) continue;

    if (demoTitles.contains(post.title.trim())) continue;
    if (demoAuthors.contains(post.author.name.trim())) continue;

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

"""
    main = re.sub(
        r"List<CampusPost> _visibleRealHomePosts\(Iterable<CampusPost> posts\) \{.*?\n\}\s*\n",
        new_visible,
        main,
        count=1,
        flags=re.S,
    )
    MAIN.write_text(main)
    print("✅ main_shell.dart：首页显示层已过滤演示标题/演示用户")

if REPO.exists():
    repo = REPO.read_text()
    repo_bak = REPO.with_suffix(REPO.suffix + ".bak_force_remove_demo_v2")
    if not repo_bak.exists():
        repo_bak.write_text(repo)

    new_demo_func = """bool _isDemoPost(CampusPost post) {
  const demoTitles = <String>{
    '校园日落拍摄地推荐',
    '新图书馆自习位怎么预约？求攻略！',
    '高效复习时间表分享，亲测有效！',
    '各科目复习资料大合集（持续更新）',
    '图书馆自习打卡',
    '食堂新品测评｜芝士焗饭绝了！',
  };

  const demoAuthors = <String>{
    '林小北',
    '陈可欣',
    '王子豪',
    '刘思雨',
    '张晓晨',
  };

  return post.id.trim().isEmpty ||
      demoTitles.contains(post.title.trim()) ||
      demoAuthors.contains(post.author.name.trim());
}

"""
    repo = re.sub(
        r"bool _isDemoPost\(CampusPost post\) \{.*?\n\}\s*\n",
        new_demo_func,
        repo,
        count=1,
        flags=re.S,
    )

    repo = re.sub(
        r"  bool _isFrontendDemoPostV2\(CampusPost post\) \{.*?\n  \}\s*\n",
        """  bool _isFrontendDemoPostV2(CampusPost post) {
    return _isDemoPost(post);
  }

""",
        repo,
        count=1,
        flags=re.S,
    )

    REPO.write_text(repo)
    print("✅ campus_repository.dart：缓存层已过滤演示标题/演示用户")

print("\n🎉 强制删除/过滤演示数据代码补丁完成")
