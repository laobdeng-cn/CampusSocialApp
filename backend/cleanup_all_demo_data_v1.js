require('dotenv').config();
const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');

const seed = require('./src/data/seed');

function loadModel(name) {
  const file = path.join(__dirname, 'src', 'models', `${name}.js`);
  if (!fs.existsSync(file)) return null;
  try {
    return require(file);
  } catch (error) {
    console.warn(`skip model ${name}: ${error.message}`);
    return null;
  }
}

const User = loadModel('User');
const Post = loadModel('Post');
const Activity = loadModel('Activity');
const Group = loadModel('Group');
const Topic = loadModel('Topic');
const Comment = loadModel('Comment');
const Like = loadModel('Like');
const Favorite = loadModel('Favorite');
const BrowsingHistory = loadModel('BrowsingHistory');
const Notification = loadModel('Notification');
const Enrollment = loadModel('Enrollment');
const CheckIn = loadModel('CheckIn');
const Draft = loadModel('Draft');
const Message = loadModel('Message');

const uri =
  process.env.MONGODB_URI ||
  process.env.MONGO_URI ||
  process.env.DATABASE_URL ||
  'mongodb://127.0.0.1:27017/campus_social_app';

function arr(value) {
  return Array.isArray(value) ? value : [];
}

(async () => {
  await mongoose.connect(uri);
  console.log('MongoDB connected:', uri);

  const seedUserNames = arr(seed.users).map((item) => item.name).filter(Boolean);
  const seedUsernames = arr(seed.users)
    .map((item) => `seed_${item.id}`)
    .filter(Boolean);

  const seedPostTitles = arr(seed.posts).map((item) => item.title).filter(Boolean);
  const seedActivityTitles = arr(seed.activities).map((item) => item.title).filter(Boolean);
  const seedGroupNames = arr(seed.groups).map((item) => item.name).filter(Boolean);
  const seedTopicNames = arr(seed.topics).map((item) => item.name || item.title).filter(Boolean);

  const demoUsers = User
    ? await User.find({
        $or: [
          { username: { $in: seedUsernames } },
          { username: /^seed_/ },
          { name: { $in: seedUserNames } },
        ],
      }).select('_id name username')
    : [];

  const demoUserIds = demoUsers.map((item) => item._id);

  const demoPosts = Post
    ? await Post.find({
        $or: [
          { title: { $in: seedPostTitles } },
          { author: { $in: demoUserIds } },
        ],
      }).select('_id title author')
    : [];

  const demoPostIds = demoPosts.map((item) => item._id);

  const demoActivities = Activity
    ? await Activity.find({
        $or: [
          { title: { $in: seedActivityTitles } },
          { createdBy: { $in: demoUserIds } },
          { host: { $in: seedUserNames } },
        ],
      }).select('_id title createdBy')
    : [];

  const demoActivityIds = demoActivities.map((item) => item._id);

  const demoGroups = Group
    ? await Group.find({
        $or: [
          { name: { $in: seedGroupNames } },
          { owner: { $in: demoUserIds } },
          { creator: { $in: demoUserIds } },
          { createdBy: { $in: demoUserIds } },
        ],
      }).select('_id name')
    : [];

  const demoGroupIds = demoGroups.map((item) => item._id);

  const demoTopics = Topic
    ? await Topic.find({
        $or: [
          { name: { $in: seedTopicNames } },
          { title: { $in: seedTopicNames } },
        ],
      }).select('_id name title')
    : [];

  const demoTopicIds = demoTopics.map((item) => item._id);

  console.log('\n====== 将删除演示用户 ======');
  console.table(demoUsers.map((u) => ({
    id: String(u._id),
    name: u.name,
    username: u.username,
  })));

  console.log('\n====== 将删除演示帖子 ======');
  console.table(demoPosts.map((p) => ({
    id: String(p._id),
    title: p.title,
    author: String(p.author),
  })));

  console.log('\n====== 将删除演示活动 ======');
  console.table(demoActivities.map((a) => ({
    id: String(a._id),
    title: a.title,
    createdBy: String(a.createdBy || ''),
  })));

  console.log('\n====== 将删除演示社群 ======');
  console.table(demoGroups.map((g) => ({
    id: String(g._id),
    name: g.name,
  })));

  console.log('\n====== 将删除演示话题 ======');
  console.table(demoTopics.map((t) => ({
    id: String(t._id),
    name: t.name || t.title,
  })));

  const tasks = [];

  if (Comment && demoPostIds.length) tasks.push(Comment.deleteMany({ post: { $in: demoPostIds } }));
  if (Like && demoPostIds.length) tasks.push(Like.deleteMany({ post: { $in: demoPostIds } }));
  if (Favorite && demoPostIds.length) tasks.push(Favorite.deleteMany({ post: { $in: demoPostIds } }));
  if (BrowsingHistory && demoPostIds.length) {
    tasks.push(BrowsingHistory.deleteMany({ kind: 'post', refId: { $in: demoPostIds } }));
  }
  if (Notification && demoPostIds.length) tasks.push(Notification.deleteMany({ post: { $in: demoPostIds } }));
  if (Draft && demoUserIds.length) tasks.push(Draft.deleteMany({ user: { $in: demoUserIds } }));

  if (Enrollment && demoActivityIds.length) {
    tasks.push(Enrollment.deleteMany({ activity: { $in: demoActivityIds } }));
  }
  if (CheckIn && demoActivityIds.length) {
    tasks.push(CheckIn.deleteMany({ activity: { $in: demoActivityIds } }));
  }
  if (Favorite && demoActivityIds.length) {
    tasks.push(Favorite.deleteMany({ activity: { $in: demoActivityIds } }));
  }
  if (Comment && demoActivityIds.length) {
    tasks.push(Comment.deleteMany({ activity: { $in: demoActivityIds } }));
  }
  if (Notification && demoActivityIds.length) {
    tasks.push(Notification.deleteMany({ activity: { $in: demoActivityIds } }));
  }
  if (BrowsingHistory && demoActivityIds.length) {
    tasks.push(BrowsingHistory.deleteMany({ kind: 'activity', refId: { $in: demoActivityIds } }));
  }

  if (Message && demoUserIds.length) {
    tasks.push(Message.deleteMany({
      $or: [
        { sender: { $in: demoUserIds } },
        { receiver: { $in: demoUserIds } },
        { user: { $in: demoUserIds } },
      ],
    }));
  }

  if (Group && demoPostIds.length) {
    tasks.push(Group.updateMany({}, {
      $pull: {
        discussionIds: { $in: demoPostIds },
        pinnedDiscussionIds: { $in: demoPostIds },
      },
    }));
  }

  if (Topic && demoPostIds.length) {
    tasks.push(Topic.updateMany({}, {
      $pull: {
        postIds: { $in: demoPostIds },
      },
    }));
  }

  if (Post && demoPostIds.length) {
    tasks.push(Post.deleteMany({ _id: { $in: demoPostIds } }));
  }

  if (Activity && demoActivityIds.length) {
    tasks.push(Activity.deleteMany({ _id: { $in: demoActivityIds } }));
  }

  if (Group && demoGroupIds.length) {
    tasks.push(Group.deleteMany({ _id: { $in: demoGroupIds } }));
  }

  if (Topic && demoTopicIds.length) {
    tasks.push(Topic.deleteMany({ _id: { $in: demoTopicIds } }));
  }

  if (User && demoUserIds.length) {
    tasks.push(User.deleteMany({ _id: { $in: demoUserIds } }));
  }

  const results = await Promise.allSettled(tasks);
  const failed = results.filter((item) => item.status === 'rejected');

  if (failed.length) {
    console.log('\n⚠️ 部分删除失败：');
    failed.forEach((item) => console.error(item.reason));
  }

  const remainPosts = Post
    ? await Post.find({}).populate('author').sort({ createdAt: -1 }).select('title author createdAt')
    : [];

  const remainUsers = User
    ? await User.find({}).sort({ createdAt: -1 }).select('name username createdAt')
    : [];

  console.log('\n====== 删除完成 ======');
  console.log('删除演示用户数：', demoUserIds.length);
  console.log('删除演示帖子数：', demoPostIds.length);
  console.log('删除演示活动数：', demoActivityIds.length);
  console.log('删除演示社群数：', demoGroupIds.length);
  console.log('删除演示话题数：', demoTopicIds.length);

  console.log('\n====== 剩余真实用户 ======');
  console.table(remainUsers.map((u) => ({
    id: String(u._id),
    name: u.name,
    username: u.username,
    createdAt: u.createdAt,
  })));

  console.log('\n====== 剩余真实帖子 ======');
  console.table(remainPosts.map((p) => ({
    id: String(p._id),
    title: p.title,
    author: p.author?.name,
    authorId: String(p.author?._id || p.author),
    createdAt: p.createdAt,
  })));

  await mongoose.disconnect();
})().catch(async (error) => {
  console.error(error);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
