from pathlib import Path

FEED = Path("backend/src/feedRoutes.js")
text = FEED.read_text()

bak = FEED.with_suffix(".js.bak_feed_real_posts_force_v4")
if not bak.exists():
    bak.write_text(text)

# 1. 引入 Post 模型
if "const Post = require('./models/Post');" not in text:
    text = text.replace(
        "const Activity = require('./models/Activity');",
        "const Activity = require('./models/Activity');\nconst Post = require('./models/Post');",
        1,
    )

# 2. 增加 serializePost
if "function serializePost(post)" not in text:
    marker = "function parseActivitySchedule(activity) {"
    if marker not in text:
        raise SystemExit("❌ 没找到 parseActivitySchedule(activity)，请把 backend/src/feedRoutes.js 发我")

    serialize_post = """function serializePost(post) {
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
    text = text.replace(marker, serialize_post + marker, 1)

# 3. 强制替换 router.get('/feed') 整段
start = text.find("router.get('/feed'")
if start == -1:
    raise SystemExit("❌ 没找到 router.get('/feed')")

end_marker = "\n\nrouter.get('/me/activities'"
end = text.find(end_marker, start)
if end == -1:
    raise SystemExit("❌ 没找到 router.get('/me/activities')，无法确定 /feed 结束位置")

new_feed = """router.get('/feed', async (_request, response, next) => {
  try {
    if (!isMongoReady()) {
      response.json({
        users: [],
        posts: [],
        activities: [],
        groups: [],
        topics: [],
      });
      return;
    }

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
    console.error('Feed route failed:', error);
    next(error);
  }
});"""

text = text[:start] + new_feed + text[end:]

FEED.write_text(text)

print("✅ 已强制替换 backend/src/feedRoutes.js 的 /api/feed")
print("✅ /api/feed 现在 posts 只来自 MongoDB 的 Post.find")
