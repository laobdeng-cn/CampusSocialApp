const dotenv = require('dotenv');
const mongoose = require('mongoose');

const Activity = require('./models/Activity');
const BrowsingHistory = require('./models/BrowsingHistory');
const CheckIn = require('./models/CheckIn');
const Comment = require('./models/Comment');
const Conversation = require('./models/Conversation');
const Draft = require('./models/Draft');
const Enrollment = require('./models/Enrollment');
const Favorite = require('./models/Favorite');
const Follow = require('./models/Follow');
const Group = require('./models/Group');
const GroupMembership = require('./models/GroupMembership');
const Like = require('./models/Like');
const Message = require('./models/Message');
const Notification = require('./models/Notification');
const Post = require('./models/Post');
const Topic = require('./models/Topic');
const User = require('./models/User');
const { hashPassword } = require('./auth');
const seed = require('./data/seed');

dotenv.config();

function omitRelationFields(item, fields) {
  const doc = { ...item };
  for (const field of fields) {
    delete doc[field];
  }
  delete doc.id;
  return doc;
}

async function run() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    throw new Error('MONGODB_URI is not configured.');
  }

  await mongoose.connect(uri, { serverSelectionTimeoutMS: 3000 });

  await Promise.all([
    User.deleteMany({}),
    Post.deleteMany({}),
    Activity.deleteMany({}),
    BrowsingHistory.deleteMany({}),
    Group.deleteMany({}),
    GroupMembership.deleteMany({}),
    Draft.deleteMany({}),
    Topic.deleteMany({}),
    CheckIn.deleteMany({}),
    Comment.deleteMany({}),
    Conversation.deleteMany({}),
    Enrollment.deleteMany({}),
    Favorite.deleteMany({}),
    Follow.deleteMany({}),
    Like.deleteMany({}),
    Message.deleteMany({}),
    Notification.deleteMany({}),
  ]);

  const userIdBySeedId = new Map();
  const users = await User.insertMany(
    seed.users.map((user, index) => {
      const doc = omitRelationFields(user, []);
      if (index === 0) {
        doc.username = '13800000000';
        doc.passwordHash = hashPassword('123456');
        doc.campusVerified = true;
        doc.campusName = doc.school;
        doc.realName = doc.name;
        doc.studentId = '20240001';
        doc.campusRole = 'student';
        doc.enrollmentYear = '2024';
        doc.settings = {
          notifications: {
            messageReminder: true,
            activityNotice: true,
            systemNotice: true,
          },
          privacy: {
            allowSearch: true,
            blockStrangerComments: true,
            profileVisibility: 'friends',
            dmPermission: 'friends_and_following',
          },
        };
      }
      return doc;
    })
  );
  seed.users.forEach((user, index) => {
    userIdBySeedId.set(user.id, users[index]._id);
  });

  const activities = await Activity.insertMany(
    seed.activities.map((activity) => {
      const doc = omitRelationFields(activity, ['guests', 'guestIds', 'highlights']);
      doc.tags = activity.highlights?.length ? activity.highlights : activity.tags;
      doc.checkInCode = activity.checkInCode || 'MUSIC2026';
      return doc;
    })
  );
  const activityIdBySeedId = new Map();
  seed.activities.forEach((activity, index) => {
    activityIdBySeedId.set(activity.id, activities[index]._id);
  });

  const posts = await Post.insertMany(
    seed.posts.map((post) => {
      const doc = omitRelationFields(post, ['author', 'authorId', 'createdAt']);
      const authorId = userIdBySeedId.get(post.authorId);
      if (!authorId) {
        throw new Error(`Missing seeded user for post authorId: ${post.authorId}`);
      }
      doc.author = authorId;
      return doc;
    })
  );

  await Follow.insertMany([
    {
      follower: userIdBySeedId.get('u_xiaobei'),
      following: userIdBySeedId.get('u_kexin'),
    },
    {
      follower: userIdBySeedId.get('u_xiaobei'),
      following: userIdBySeedId.get('u_zihao'),
    },
    {
      follower: userIdBySeedId.get('u_xiaobei'),
      following: userIdBySeedId.get('u_siyu'),
    },
    {
      follower: userIdBySeedId.get('u_kexin'),
      following: userIdBySeedId.get('u_xiaobei'),
    },
    {
      follower: userIdBySeedId.get('u_zihao'),
      following: userIdBySeedId.get('u_xiaobei'),
    },
    {
      follower: userIdBySeedId.get('u_siyu'),
      following: userIdBySeedId.get('u_xiaobei'),
    },
  ]);

  const postByTitle = new Map(posts.map((post) => [post.title, post]));
  const postBySeedId = new Map();
  seed.posts.forEach((post, index) => {
    postBySeedId.set(post.id, posts[index]._id);
  });
  const xiaobeiId = userIdBySeedId.get('u_xiaobei');
  const kexinId = userIdBySeedId.get('u_kexin');
  const zihaoId = userIdBySeedId.get('u_zihao');
  const siyuId = userIdBySeedId.get('u_siyu');
  const xiaochenId = userIdBySeedId.get('u_xiaochen');

  await Favorite.insertMany([
    {
      post: postByTitle.get('校园日落拍摄地推荐')._id,
      user: xiaobeiId,
    },
    {
      post: postByTitle.get('新图书馆自习位怎么预约？求攻略！')._id,
      user: xiaobeiId,
    },
    {
      post: postByTitle.get('各科目复习资料大合集（持续更新）')._id,
      user: xiaobeiId,
    },
  ]);

  await BrowsingHistory.insertMany([
    {
      user: xiaobeiId,
      kind: 'post',
      refId: postByTitle.get('校园日落拍摄地推荐')._id,
      title: '校园日落拍摄地推荐',
      subtitle: '陈可欣 · 128赞 · 23评论',
      imageUrl: 'asset:assets/images/profile_sunset.png',
    },
    {
      user: xiaobeiId,
      kind: 'activity',
      refId: activities[0]._id,
      title: activities[0].title,
      subtitle: `${activities[0].host} · ${activities[0].enrolled}人参加`,
      imageUrl: 'asset:assets/images/favorite_music.png',
    },
    {
      user: xiaobeiId,
      kind: 'topic',
      title: '期末复习攻略',
      subtitle: '2.3k讨论 · 856关注',
    },
  ]);

  await Draft.insertMany([
    {
      user: xiaobeiId,
      kind: 'post',
      title: '校园春日摄影征集',
      body: '春天的校园总是充满生机，快来分享你镜头下的春日美景吧～',
      topic: '摄影作品分享',
      location: '校园湖边',
      images: ['https://images.unsplash.com/photo-1522383225653-ed111181a951?auto=format&fit=crop&w=700&q=80'],
    },
    {
      user: xiaobeiId,
      kind: 'post',
      title: '宿舍收纳心得分享',
      body: '整理了几种实用的宿舍收纳技巧，让小空间也能整洁有序！',
      topic: '生活分享',
      location: '学生宿舍',
      images: ['https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=700&q=80'],
    },
    {
      user: xiaobeiId,
      kind: 'activity',
      title: '周末徒步活动计划',
      body: '计划组织一次周末徒步活动，一起亲近自然，放松身心！',
      topic: '活动招募',
      location: '东湖绿道',
      status: 'pending',
      images: ['https://images.unsplash.com/photo-1551632811-561732d1e306?auto=format&fit=crop&w=700&q=80'],
    },
  ]);

  await Like.insertMany([
    {
      post: postByTitle.get('新图书馆自习位怎么预约？求攻略！')._id,
      user: userIdBySeedId.get('u_kexin'),
    },
    {
      post: postByTitle.get('新图书馆自习位怎么预约？求攻略！')._id,
      user: userIdBySeedId.get('u_zihao'),
    },
    {
      post: postByTitle.get('各科目复习资料大合集（持续更新）')._id,
      user: userIdBySeedId.get('u_siyu'),
    },
  ]);

  const seededComments = await Comment.insertMany([
    {
      post: postByTitle.get('新图书馆自习位怎么预约？求攻略！')._id,
      author: xiaobeiId,
      text: '我也遇到过这种情况，建议大家可以试试早上 7:30 放号的那一波。',
      likes: 32,
    },
    {
      post: postByTitle.get('校园日落拍摄地推荐')._id,
      author: xiaobeiId,
      text: '第三张光影绝了！是用什么镜头拍的呀？感觉氛围感拉满了。',
      likes: 18,
    },
    {
      post: postByTitle.get('各科目复习资料大合集（持续更新）')._id,
      author: xiaobeiId,
      text: '你的方法很实用，我打算试试番茄钟加思维导图，感谢分享。',
      likes: 24,
    },
  ]);
  await Promise.all(
    seededComments.map((comment) =>
      Post.updateOne({ _id: comment.post }, { $inc: { comments: 1 } })
    )
  );

  await Promise.all(
    users.map(async (user) => {
      user.following = await Follow.countDocuments({ follower: user._id });
      user.followers = await Follow.countDocuments({ following: user._id });
      await user.save();
    })
  );

  await Notification.insertMany([
    {
      recipient: xiaobeiId,
      actor: kexinId,
      post: postByTitle.get('新图书馆自习位怎么预约？求攻略！')._id,
      category: 'interaction',
      title: '陈可欣',
      firstLine: '点赞了你的帖子《新图书馆自习位怎么预约？求攻略！》',
      secondLine: '一起发现更好的自习位置',
      action: 'like',
      unread: true,
    },
    {
      recipient: xiaobeiId,
      actor: zihaoId,
      post: postByTitle.get('新图书馆自习位怎么预约？求攻略！')._id,
      category: 'interaction',
      title: '王子豪',
      firstLine: '评论了你的帖子《新图书馆自习位怎么预约？求攻略！》',
      secondLine: '这个座位视野超好，学习效率翻倍！',
      action: 'comment',
      unread: true,
    },
    {
      recipient: xiaobeiId,
      actor: siyuId,
      post: postByTitle.get('各科目复习资料大合集（持续更新）')._id,
      category: 'interaction',
      title: '刘思雨',
      firstLine: '收藏了你的帖子《各科目复习资料大合集（持续更新）》',
      secondLine: '资料太实用了，收藏慢慢看',
      action: 'favorite',
      unread: false,
    },
    {
      recipient: xiaobeiId,
      category: 'notice',
      title: '报名成功',
      firstLine: '你已成功报名「校园音乐之夜」。',
      secondLine: '活动时间：6月15日 19:00，地点：大学生活动中心',
      action: 'activity_registered',
      unread: true,
    },
    {
      recipient: xiaobeiId,
      category: 'notice',
      title: '社区公告',
      firstLine: '关于优化社区发帖规范的公告',
      secondLine: '请大家共同维护良好的社区氛围！',
      action: 'system_notice',
      unread: false,
    },
  ]);

  async function seedConversation(otherUserId, messages) {
    const conversation = await Conversation.create({
      participants: [xiaobeiId, otherUserId],
      lastMessage: messages[messages.length - 1].text,
    });
    await Message.insertMany(
      messages.map((message) => ({
        conversation: conversation._id,
        sender: message.fromMe ? xiaobeiId : otherUserId,
        text: message.text,
        readBy: message.fromMe ? [xiaobeiId] : [],
      }))
    );
  }

  await seedConversation(kexinId, [
    { text: '下周一起去图书馆自习吧？' },
    { text: '可以呀，我想找靠窗的位置。', fromMe: true },
    { text: '那我明天把预约链接发你。' },
  ]);
  await seedConversation(zihaoId, [
    { text: '关于周末的摄影活动，你有时间吗？' },
    { text: '有的，我想拍湖边日出。', fromMe: true },
    { text: '太好了，我们 6:30 在图书馆门口集合。' },
  ]);
  await seedConversation(siyuId, [
    { text: '谢谢你的资料分享！对我们的组会很有帮助～' },
    { text: '不客气，后面有新版本我再发你。', fromMe: true },
  ]);
  await seedConversation(xiaochenId, [
    { text: '校园音乐之夜彩排时间更新到周五晚上啦。' },
  ]);

  const groups = await Group.insertMany(
    seed.groups.map((group) => {
      const doc = omitRelationFields(group, ['activities', 'discussions']);
      doc.activityIds = (group.activityIds || [])
        .map((id) => activityIdBySeedId.get(id))
        .filter(Boolean);
      doc.discussionIds = (group.discussionIds || [])
        .map((id) => postBySeedId.get(id))
        .filter(Boolean);
      return doc;
    })
  );
  await GroupMembership.insertMany([
    { group: groups[0]._id, user: userIdBySeedId.get('u_xiaobei'), role: 'owner' },
    { group: groups[0]._id, user: userIdBySeedId.get('u_kexin'), role: 'member' },
  ]);

  await Topic.insertMany(
    seed.topics.map((topic) => {
      const doc = omitRelationFields(topic, ['posts', 'contributors']);
      doc.postIds = (topic.postIds || [])
        .map((id) => postBySeedId.get(id))
        .filter(Boolean);
      doc.contributorIds = (topic.contributorIds || [])
        .map((id) => userIdBySeedId.get(id))
        .filter(Boolean);
      return doc;
    })
  );

  const counts = {
    users: await User.countDocuments(),
    posts: await Post.countDocuments(),
    activities: await Activity.countDocuments(),
    groups: await Group.countDocuments(),
    groupMemberships: await GroupMembership.countDocuments(),
    topics: await Topic.countDocuments(),
    follows: await Follow.countDocuments(),
    likes: await Like.countDocuments(),
    comments: await Comment.countDocuments(),
    favorites: await Favorite.countDocuments(),
    history: await BrowsingHistory.countDocuments(),
    drafts: await Draft.countDocuments(),
    notifications: await Notification.countDocuments(),
    conversations: await Conversation.countDocuments(),
    messages: await Message.countDocuments(),
  };

  console.log(`Seeded MongoDB database: ${mongoose.connection.name}`);
  console.log(JSON.stringify(counts, null, 2));
}

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
