require('dotenv').config();
const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');

function model(name) {
  const file = path.join(__dirname, 'src', 'models', `${name}.js`);
  if (!fs.existsSync(file)) return null;
  return require(file);
}

const User = model('User');
const Post = model('Post');
const Activity = model('Activity');
const Group = model('Group');
const Topic = model('Topic');
const Comment = model('Comment');
const Like = model('Like');
const Favorite = model('Favorite');
const BrowsingHistory = model('BrowsingHistory');
const Notification = model('Notification');
const Enrollment = model('Enrollment');
const CheckIn = model('CheckIn');
const Draft = model('Draft');
const Message = model('Message');
const Follow = model('Follow');

const uri =
  process.env.MONGODB_URI ||
  process.env.MONGO_URI ||
  process.env.DATABASE_URL ||
  'mongodb://127.0.0.1:27017/campus_social_app';

const demoNames = [
  '林小北',
  '陈可欣',
  '王子豪',
  '刘思雨',
  '张晓晨',
  'user123',
];

const demoTitles = [
  '校园日落拍摄地推荐',
  '新图书馆自习位怎么预约？求攻略！',
  '高效复习时间表分享，亲测有效！',
  '各科目复习资料大合集（持续更新）',
  '图书馆自习打卡',
  '食堂新品测评｜芝士焗饭绝了！',
];

const demoActivityTitles = [
  '校园音乐之夜',
  '摄影社团采风活动',
  '设计作品分享会',
];

(async () => {
  await mongoose.connect(uri);
  console.log('MongoDB connected:', uri);

  const demoUsers = User
    ? await User.find({
        $or: [
          { name: { $in: demoNames } },
          { username: /^seed_/ },
        ],
      }).select('_id name username')
    : [];

  const demoUserIds = demoUsers.map((u) => u._id);

  const demoPosts = Post
    ? await Post.find({
        $or: [
          { title: { $in: demoTitles } },
          { author: { $in: demoUserIds } },
        ],
      }).select('_id title author')
    : [];

  const demoPostIds = demoPosts.map((p) => p._id);

  const demoActivities = Activity
    ? await Activity.find({
        $or: [
          { title: { $in: demoActivityTitles } },
          { createdBy: { $in: demoUserIds } },
          { host: { $in: demoNames } },
        ],
      }).select('_id title createdBy')
    : [];

  const demoActivityIds = demoActivities.map((a) => a._id);

  const tasks = [];

  if (Comment) {
    if (demoPostIds.length) tasks.push(Comment.deleteMany({ post: { $in: demoPostIds } }));
    if (demoActivityIds.length) tasks.push(Comment.deleteMany({ activity: { $in: demoActivityIds } }));
    if (demoUserIds.length) tasks.push(Comment.deleteMany({ author: { $in: demoUserIds } }));
    if (demoUserIds.length) tasks.push(Comment.deleteMany({ user: { $in: demoUserIds } }));
  }
  if (Like) {
    if (demoPostIds.length) tasks.push(Like.deleteMany({ post: { $in: demoPostIds } }));
    if (demoUserIds.length) tasks.push(Like.deleteMany({ user: { $in: demoUserIds } }));
  }
  if (Favorite) {
    if (demoPostIds.length) tasks.push(Favorite.deleteMany({ post: { $in: demoPostIds } }));
    if (demoActivityIds.length) tasks.push(Favorite.deleteMany({ activity: { $in: demoActivityIds } }));
    if (demoUserIds.length) tasks.push(Favorite.deleteMany({ user: { $in: demoUserIds } }));
  }
  if (BrowsingHistory) {
    if (demoPostIds.length) tasks.push(BrowsingHistory.deleteMany({ kind: 'post', refId: { $in: demoPostIds } }));
    if (demoActivityIds.length) tasks.push(BrowsingHistory.deleteMany({ kind: 'activity', refId: { $in: demoActivityIds } }));
    if (demoUserIds.length) tasks.push(BrowsingHistory.deleteMany({ user: { $in: demoUserIds } }));
  }
  if (Notification) {
    if (demoPostIds.length) tasks.push(Notification.deleteMany({ post: { $in: demoPostIds } }));
    if (demoActivityIds.length) tasks.push(Notification.deleteMany({ activity: { $in: demoActivityIds } }));
    if (demoUserIds.length) {
      tasks.push(Notification.deleteMany({
        $or: [
          { user: { $in: demoUserIds } },
          { actor: { $in: demoUserIds } },
          { sender: { $in: demoUserIds } },
          { receiver: { $in: demoUserIds } },
        ],
      }));
    }
  }
  if (Enrollment && demoActivityIds.length) tasks.push(Enrollment.deleteMany({ activity: { $in: demoActivityIds } }));
  if (CheckIn && demoActivityIds.length) tasks.push(CheckIn.deleteMany({ activity: { $in: demoActivityIds } }));
  if (Draft && demoUserIds.length) tasks.push(Draft.deleteMany({ user: { $in: demoUserIds } }));
  if (Message && demoUserIds.length) {
    tasks.push(Message.deleteMany({
      $or: [
        { sender: { $in: demoUserIds } },
        { receiver: { $in: demoUserIds } },
        { user: { $in: demoUserIds } },
      ],
    }));
  }
  if (Follow && demoUserIds.length) {
    tasks.push(Follow.deleteMany({
      $or: [
        { follower: { $in: demoUserIds } },
        { following: { $in: demoUserIds } },
      ],
    }));
  }
  if (Group) {
    if (demoPostIds.length) {
      tasks.push(Group.updateMany({}, {
        $pull: {
          discussionIds: { $in: demoPostIds },
          pinnedDiscussionIds: { $in: demoPostIds },
        },
      }));
    }
    if (demoUserIds.length) {
      tasks.push(Group.deleteMany({
        $or: [
          { owner: { $in: demoUserIds } },
          { creator: { $in: demoUserIds } },
          { createdBy: { $in: demoUserIds } },
          { name: { $in: ['编程学习小组', '摄影交流社', '校园跑团'] } },
        ],
      }));
    }
  }
  if (Topic) {
    if (demoPostIds.length) tasks.push(Topic.updateMany({}, { $pull: { postIds: { $in: demoPostIds } } }));
    tasks.push(Topic.deleteMany({
      $or: [
        { name: { $in: ['校园生活', '资料分享', '时间规划', '摄影作品分享'] } },
        { title: { $in: ['校园生活', '资料分享', '时间规划', '摄影作品分享'] } },
      ],
    }));
  }
  if (Post && demoPostIds.length) tasks.push(Post.deleteMany({ _id: { $in: demoPostIds } }));
  if (Activity && demoActivityIds.length) tasks.push(Activity.deleteMany({ _id: { $in: demoActivityIds } }));
  if (User && demoUserIds.length) tasks.push(User.deleteMany({ _id: { $in: demoUserIds } }));

  await Promise.all(tasks);

  const remainUsers = User
    ? await User.find({}).sort({ createdAt: -1 }).select('name username createdAt')
    : [];
  const remainPosts = Post
    ? await Post.find({}).populate('author').sort({ createdAt: -1 }).select('title author createdAt')
    : [];
  const remainActivities = Activity
    ? await Activity.find({}).populate('createdBy').sort({ createdAt: -1 }).select('title createdBy createdAt')
    : [];

  console.log('\n✅ 删除完成');
  console.log('删除演示用户：', demoUsers.length);
  console.log('删除演示帖子：', demoPosts.length);
  console.log('删除演示活动：', demoActivities.length);

  console.log('\n====== 剩余用户 ======');
  console.table(remainUsers.map((u) => ({
    id: String(u._id),
    name: u.name,
    username: u.username,
  })));

  console.log('\n====== 剩余帖子 ======');
  console.table(remainPosts.map((p) => ({
    id: String(p._id),
    title: p.title,
    author: p.author?.name,
    username: p.author?.username,
  })));

  console.log('\n====== 剩余活动 ======');
  console.table(remainActivities.map((a) => ({
    id: String(a._id),
    title: a.title,
    createdBy: a.createdBy?.name,
  })));

  await mongoose.disconnect();
})().catch(async (error) => {
  console.error(error);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
