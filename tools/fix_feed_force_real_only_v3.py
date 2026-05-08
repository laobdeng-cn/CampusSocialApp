from pathlib import Path
import re

FEED = Path("backend/src/feedRoutes.js")
text = FEED.read_text()

bak = FEED.with_suffix(".js.bak_force_real_feed_v3")
if not bak.exists():
    bak.write_text(text)

# 确保引入 Post
if "const Post = require('./models/Post');" not in text:
    text = text.replace(
        "const Activity = require('./models/Activity');",
        "const Activity = require('./models/Activity');\nconst Post = require('./models/Post');",
        1,
    )

# 确保 serializePost 存在
if "function serializePost(post)" not in text:
    marker = "function parseActivitySchedule(activity) {"
    helper = """function serializePost(post) {
  if (!post) return null;
  const plain = typeof post.toObject === 'function' ? post.toObject() : post;

  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    groupId: plain.group ? String(plain.group._id || plain.group.id || plain.group) : '',
    author: publicUser(plain.author),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
    updatedAt: plain.updatedAt instanceof Date
      ? plain.updatedAt.toISOString()
      : plain.updatedAt,
  };
}

"""
    if marker not in text:
        raise SystemExit("❌ 没找到 parseActivitySchedule 插入点，请把 backend/src/feedRoutes.js 发我")
    text = text.replace(marker, helper + marker, 1)

# 强制替换整个 router.get('/feed')
new_route = """router.get('/feed', async (request, response, next) => {
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
      .filter((post) => post && post.id && post.author);

    const realActivities = activities
      .map((activity) => serializeActivity(activity))
      .filter((activity) => activity && activity.id);

    response.json({
      users: users.map(publicUser),
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

text, count = pattern.subn(new_route, text, count=1)
if count == 0:
    raise SystemExit("❌ 没有匹配到 router.get('/feed')，请把 backend/src/feedRoutes.js 发我")

FEED.write_text(text)
print("✅ 已强制重写 /api/feed：posts 只来自 MongoDB Post.find")
