require('dotenv').config();

const mongoose = require('mongoose');
const { hashPassword } = require('./src/auth');

const Activity = require('./src/models/Activity');
const BrowsingHistory = require('./src/models/BrowsingHistory');
const CheckIn = require('./src/models/CheckIn');
const Comment = require('./src/models/Comment');
const Conversation = require('./src/models/Conversation');
const Draft = require('./src/models/Draft');
const Enrollment = require('./src/models/Enrollment');
const Favorite = require('./src/models/Favorite');
const Follow = require('./src/models/Follow');
const Group = require('./src/models/Group');
const GroupMembership = require('./src/models/GroupMembership');
const Like = require('./src/models/Like');
const Message = require('./src/models/Message');
const Notification = require('./src/models/Notification');
const Post = require('./src/models/Post');
const User = require('./src/models/User');

const MONGODB_URI =
  process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/campus_social_app';

const PASSWORD = '123456';

const demoUsernames = [
  '18800000001',
  '18800000002',
  '18800000003',
  '18800000004',
];

const demoActivityTitles = [
  '校园音乐之夜',
  'AI 未来发展趋势讲座',
  '摄影社团采风活动',
  '图书馆学习打卡活动',
  '篮球友谊赛',
];

const demoPostTitles = [
  '新图书馆自习位怎么预约？求攻略！',
  '校园日落拍摄地推荐',
  'AI 讲座听完的一些笔记',
  '篮球赛报名组队中',
  '摄影社团采风活动预告',
];

const demoGroupNames = ['摄影协会', 'AI 学习小组'];

const image = {
  avatarLin: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=300&q=80',
  avatarKexin: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=300&q=80',
  avatarZihao: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
  avatarSiyu: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',

  music: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1200&q=80',
  ai: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
  photo: 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1200&q=80',
  library: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=1200&q=80',
  basketball: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=1200&q=80',

  sunset: 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1200&q=80',
  books: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=1200&q=80',
  coding: 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80',
  sport: 'https://images.unsplash.com/photo-1519861531473-9200262188bf?auto=format&fit=crop&w=1200&q=80',
  campus: 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&w=1200&q=80',
};

function plusDays(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date.toISOString().slice(0, 10);
}

async function clearOldDemoData() {
  const oldUsers = await User.find({ username: { $in: demoUsernames } }).select('_id');
  const oldUserIds = oldUsers.map((user) => user._id);

  const oldGroups = await Group.find({ name: { $in: demoGroupNames } }).select('_id');
  const oldGroupIds = oldGroups.map((group) => group._id);

  const oldPosts = await Post.find({
    $or: [
      { title: { $in: demoPostTitles } },
      { author: { $in: oldUserIds } },
      { group: { $in: oldGroupIds } },
    ],
  }).select('_id');
  const oldPostIds = oldPosts.map((post) => post._id);

  const oldActivities = await Activity.find({
    $or: [
      { title: { $in: demoActivityTitles } },
      { createdBy: { $in: oldUserIds } },
      { group: { $in: oldGroupIds } },
    ],
  }).select('_id');
  const oldActivityIds = oldActivities.map((activity) => activity._id);

  const oldConversations = await Conversation.find({
    participants: { $in: oldUserIds },
  }).select('_id');
  const oldConversationIds = oldConversations.map((conversation) => conversation._id);

  await Promise.all([
    Message.deleteMany({
      $or: [
        { conversation: { $in: oldConversationIds } },
        { sender: { $in: oldUserIds } },
      ],
    }),
    Conversation.deleteMany({ _id: { $in: oldConversationIds } }),

    Notification.deleteMany({
      $or: [
        { recipient: { $in: oldUserIds } },
        { actor: { $in: oldUserIds } },
        { post: { $in: oldPostIds } },
        { activity: { $in: oldActivityIds } },
        { group: { $in: oldGroupIds } },
      ],
    }),

    CheckIn.deleteMany({
      $or: [
        { user: { $in: oldUserIds } },
        { activity: { $in: oldActivityIds } },
      ],
    }),
    Enrollment.deleteMany({
      $or: [
        { user: { $in: oldUserIds } },
        { activity: { $in: oldActivityIds } },
      ],
    }),

    Comment.deleteMany({
      $or: [
        { author: { $in: oldUserIds } },
        { post: { $in: oldPostIds } },
        { activity: { $in: oldActivityIds } },
      ],
    }),
    Like.deleteMany({
      $or: [
        { user: { $in: oldUserIds } },
        { post: { $in: oldPostIds } },
      ],
    }),
    Favorite.deleteMany({
      $or: [
        { user: { $in: oldUserIds } },
        { post: { $in: oldPostIds } },
        { activity: { $in: oldActivityIds } },
      ],
    }),
    Follow.deleteMany({
      $or: [
        { follower: { $in: oldUserIds } },
        { following: { $in: oldUserIds } },
      ],
    }),

    BrowsingHistory.deleteMany({ user: { $in: oldUserIds } }),
    Draft.deleteMany({ user: { $in: oldUserIds } }),
    GroupMembership.deleteMany({
      $or: [
        { user: { $in: oldUserIds } },
        { group: { $in: oldGroupIds } },
      ],
    }),

    Post.deleteMany({ _id: { $in: oldPostIds } }),
    Activity.deleteMany({ _id: { $in: oldActivityIds } }),
    Group.deleteMany({ _id: { $in: oldGroupIds } }),
    User.deleteMany({ _id: { $in: oldUserIds } }),
  ]);
}

async function seedUsers() {
  const passwordHash = hashPassword(PASSWORD);

  const users = await User.create([
    {
      name: '林同学',
      username: '18800000001',
      passwordHash,
      school: '重庆移通学院',
      major: '计算机科学与技术',
      grade: '2024级',
      avatarUrl: image.avatarLin,
      bio: '喜欢校园活动、摄影和运动，希望认识更多同学。',
      role: '学生',
      realName: '林同学',
      studentId: '20240001',
      campusName: '重庆移通学院',
      campusVerified: true,
      campusRole: 'student',
      enrollmentYear: '2024',
    },
    {
      name: '陈可欣',
      username: '18800000002',
      passwordHash,
      school: '重庆移通学院',
      major: '视觉传达设计',
      grade: '2023级',
      avatarUrl: image.avatarKexin,
      bio: '摄影协会负责人，喜欢记录校园生活。',
      role: '摄影协会负责人',
      realName: '陈可欣',
      studentId: '20230002',
      campusName: '重庆移通学院',
      campusVerified: true,
      campusRole: 'student',
      enrollmentYear: '2023',
    },
    {
      name: '王子豪',
      username: '18800000003',
      passwordHash,
      school: '重庆移通学院',
      major: '人工智能',
      grade: '2024级',
      avatarUrl: image.avatarZihao,
      bio: '关注 AI 技术和篮球活动。',
      role: '学生',
      realName: '王子豪',
      studentId: '20240003',
      campusName: '重庆移通学院',
      campusVerified: true,
      campusRole: 'student',
      enrollmentYear: '2024',
    },
    {
      name: '刘思雨',
      username: '18800000004',
      passwordHash,
      school: '重庆移通学院',
      major: '英语',
      grade: '2024级',
      avatarUrl: image.avatarSiyu,
      bio: '喜欢读书、社团活动和校园分享。',
      role: '学生',
      realName: '刘思雨',
      studentId: '20240004',
      campusName: '重庆移通学院',
      campusVerified: true,
      campusRole: 'student',
      enrollmentYear: '2024',
    },
  ]);

  return {
    lin: users[0],
    kexin: users[1],
    zihao: users[2],
    siyu: users[3],
  };
}

async function seedGroups(users) {
  const groups = await Group.create([
    {
      name: '摄影协会',
      description: '分享校园摄影、外拍活动和后期修图经验。',
      coverUrl: image.photo,
      iconUrl: image.avatarKexin,
      members: 4,
      admins: 1,
      tags: ['摄影', '外拍', '校园风景'],
      announcementText: '周末采风活动已开放报名，集合地点为图书馆前广场。',
      announcementUpdatedAt: new Date(),
      announcementUpdatedBy: users.kexin._id,
      visibility: 'public',
    },
    {
      name: 'AI 学习小组',
      description: '交流 AI 工具、算法学习和课程项目经验。',
      coverUrl: image.ai,
      iconUrl: image.avatarZihao,
      members: 4,
      admins: 1,
      tags: ['AI', '学习', '项目实践'],
      announcementText: '本周三晚举行 AI 讲座复盘讨论。',
      announcementUpdatedAt: new Date(),
      announcementUpdatedBy: users.zihao._id,
      visibility: 'public',
    },
  ]);

  await GroupMembership.create([
    { group: groups[0]._id, user: users.kexin._id, role: 'owner', status: 'active' },
    { group: groups[0]._id, user: users.lin._id, role: 'member', status: 'active' },
    { group: groups[0]._id, user: users.siyu._id, role: 'member', status: 'active' },

    { group: groups[1]._id, user: users.zihao._id, role: 'owner', status: 'active' },
    { group: groups[1]._id, user: users.lin._id, role: 'member', status: 'active' },
    { group: groups[1]._id, user: users.kexin._id, role: 'member', status: 'active' },
  ]);

  return {
    photoGroup: groups[0],
    aiGroup: groups[1],
  };
}

async function seedActivities(users, groups) {
  const activities = await Activity.create([
    {
      createdBy: users.kexin._id,
      title: '校园音乐之夜',
      category: '文艺演出',
      posterUrl: image.music,
      images: [image.music],
      date: plusDays(5),
      time: '19:00-21:00',
      location: '大学生活动中心',
      host: '校学生会',
      capacity: 120,
      price: '免费',
      description: '面向全校同学开放的音乐演出活动，包含乐队表演、民谣弹唱和互动抽奖。',
      checkInCode: 'campus2026',
      allowComments: true,
      publicDisplay: true,
      registrationDeadline: plusDays(4),
      tags: ['音乐', '校园活动', '晚会'],
    },
    {
      createdBy: users.zihao._id,
      group: groups.aiGroup._id,
      title: 'AI 未来发展趋势讲座',
      category: '学术讲座',
      posterUrl: image.ai,
      images: [image.ai],
      date: plusDays(7),
      time: '15:00-17:00',
      location: '第二教学楼 204',
      host: 'AI 学习小组',
      capacity: 80,
      price: '免费',
      description: '围绕生成式 AI、智能应用开发和校园项目实践进行交流分享。',
      checkInCode: 'AI2026',
      allowComments: true,
      publicDisplay: true,
      registrationDeadline: plusDays(6),
      tags: ['AI', '讲座', '技术交流'],
    },
    {
      createdBy: users.kexin._id,
      group: groups.photoGroup._id,
      title: '摄影社团采风活动',
      category: '社团活动',
      posterUrl: image.photo,
      images: [image.photo, image.sunset],
      date: plusDays(3),
      time: '06:30-10:30',
      location: '图书馆前广场集合',
      host: '摄影协会',
      capacity: 30,
      price: '免费',
      description: '组织同学前往湖边和校园主干道拍摄日出、建筑和校园风景。',
      checkInCode: 'campus2026',
      allowComments: true,
      publicDisplay: true,
      registrationDeadline: plusDays(2),
      tags: ['摄影', '外拍', '社团'],
    },
    {
      createdBy: users.siyu._id,
      title: '图书馆学习打卡活动',
      category: '学习打卡',
      posterUrl: image.library,
      images: [image.library],
      date: plusDays(1),
      time: '09:00-18:00',
      location: '图书馆二楼自习区',
      host: '学习互助小组',
      capacity: 50,
      price: '免费',
      description: '面向期末复习同学开放的自习打卡活动，完成打卡可获得积分。',
      checkInCode: 'STUDY2026',
      allowComments: true,
      publicDisplay: true,
      registrationDeadline: plusDays(1),
      tags: ['学习', '打卡', '自习'],
    },
    {
      createdBy: users.zihao._id,
      title: '篮球友谊赛',
      category: '体育活动',
      posterUrl: image.basketball,
      images: [image.basketball],
      date: plusDays(10),
      time: '16:00-18:00',
      location: '西区篮球场',
      host: '体育部',
      capacity: 24,
      price: '免费',
      description: '以班级和兴趣小组为单位自由组队，鼓励新同学参与。',
      checkInCode: 'BALL2026',
      allowComments: true,
      publicDisplay: true,
      registrationDeadline: plusDays(9),
      tags: ['篮球', '运动', '组队'],
    },
  ]);

  return {
    music: activities[0],
    ai: activities[1],
    photo: activities[2],
    study: activities[3],
    basketball: activities[4],
    all: activities,
  };
}

async function seedPosts(users, groups) {
  const posts = await Post.create([
    {
      author: users.siyu._id,
      title: '新图书馆自习位怎么预约？求攻略！',
      body: '最近准备期末复习，想找一个安静的位置学习。有没有同学知道图书馆自习位预约流程？',
      topic: '学习交流',
      images: [image.library],
      location: '图书馆',
      visibility: 'public',
      likes: 0,
      comments: 0,
      saves: 0,
      shares: 0,
    },
    {
      author: users.kexin._id,
      group: groups.photoGroup._id,
      title: '校园日落拍摄地推荐',
      body: '傍晚去操场后面的步道拍了一组日落，光线很柔和，适合拍人像和校园风景。',
      topic: '校园生活',
      images: [image.sunset],
      location: '操场步道',
      visibility: 'public',
      pinnedInGroup: true,
    },
    {
      author: users.zihao._id,
      group: groups.aiGroup._id,
      title: 'AI 讲座听完的一些笔记',
      body: '今天的讲座提到大模型应用、提示词设计和校园项目落地，整理了一些重点给大家参考。',
      topic: '技术分享',
      images: [image.coding],
      location: '第二教学楼',
      visibility: 'public',
    },
    {
      author: users.zihao._id,
      title: '篮球赛报名组队中',
      body: '下周篮球友谊赛还差两名队友，欢迎喜欢运动的同学一起报名。',
      topic: '运动组队',
      images: [image.sport],
      location: '西区篮球场',
      visibility: 'public',
    },
    {
      author: users.kexin._id,
      group: groups.photoGroup._id,
      title: '摄影社团采风活动预告',
      body: '本周末早上 6:30 图书馆前广场集合，建议带相机、脚架和充足电量。',
      topic: '社团活动',
      images: [image.photo],
      location: '图书馆前广场',
      visibility: 'public',
      pinnedInGroup: true,
    },
  ]);

  return {
    library: posts[0],
    sunset: posts[1],
    aiNote: posts[2],
    basketball: posts[3],
    photoNotice: posts[4],
    all: posts,
  };
}

async function seedRelations(users, posts, activities) {
  await Follow.create([
    { follower: users.lin._id, following: users.kexin._id },
    { follower: users.kexin._id, following: users.lin._id },
    { follower: users.zihao._id, following: users.lin._id },
    { follower: users.siyu._id, following: users.kexin._id },
    { follower: users.lin._id, following: users.zihao._id },
  ]);

  await Like.create([
    { user: users.lin._id, post: posts.sunset._id },
    { user: users.zihao._id, post: posts.sunset._id },
    { user: users.siyu._id, post: posts.sunset._id },

    { user: users.lin._id, post: posts.aiNote._id },
    { user: users.kexin._id, post: posts.aiNote._id },

    { user: users.kexin._id, post: posts.library._id },
    { user: users.zihao._id, post: posts.library._id },
  ]);

  await Favorite.create([
    { user: users.lin._id, kind: 'post', post: posts.sunset._id },
    { user: users.lin._id, kind: 'activity', activity: activities.music._id },
    { user: users.siyu._id, kind: 'activity', activity: activities.photo._id },
    { user: users.zihao._id, kind: 'post', post: posts.photoNotice._id },
  ]);

  const comments = await Comment.create([
    {
      kind: 'post',
      post: posts.sunset._id,
      author: users.lin._id,
      text: '这个角度很好看，下次也想去拍一组。',
    },
    {
      kind: 'post',
      post: posts.library._id,
      author: users.zihao._id,
      text: '可以在学校公众号里预约，也可以现场扫码查看空位。',
    },
    {
      kind: 'post',
      post: posts.aiNote._id,
      author: users.kexin._id,
      text: '整理得很清楚，适合放到小组资料里。',
    },
    {
      kind: 'activity',
      activity: activities.photo._id,
      author: users.lin._id,
      text: '活动安排很清楚，我已经报名了。',
    },
    {
      kind: 'activity',
      activity: activities.music._id,
      author: users.siyu._id,
      text: '这个活动适合和朋友一起去。',
    },
  ]);

  return comments;
}

async function seedEnrollmentAndCheckIn(users, activities) {
  const enrollments = await Enrollment.create([
    { activity: activities.photo._id, user: users.lin._id, status: 'registered' },
    { activity: activities.photo._id, user: users.zihao._id, status: 'registered' },
    { activity: activities.photo._id, user: users.siyu._id, status: 'registered' },

    { activity: activities.music._id, user: users.lin._id, status: 'registered' },
    { activity: activities.music._id, user: users.siyu._id, status: 'registered' },

    { activity: activities.ai._id, user: users.lin._id, status: 'registered' },
  ]);

  const linPhotoEnrollment = enrollments.find(
    (item) =>
      String(item.activity) === String(activities.photo._id) &&
      String(item.user) === String(users.lin._id)
  );

  await CheckIn.create([
    {
      activity: activities.photo._id,
      user: users.lin._id,
      enrollment: linPhotoEnrollment?._id,
      method: 'code',
      status: 'checked_in',
      code: 'campus2026',
    },
  ]);

  return enrollments;
}

async function seedNotifications(users, posts, activities, groups) {
  await Notification.create([
    {
      recipient: users.lin._id,
      actor: users.kexin._id,
      activity: activities.photo._id,
      category: 'notice',
      title: '报名成功',
      firstLine: '你已成功报名「摄影社团采风活动」',
      secondLine: '请于活动当天 06:30 前到图书馆前广场集合',
      action: 'activity_registered',
      unread: true,
    },
    {
      recipient: users.lin._id,
      actor: users.kexin._id,
      activity: activities.photo._id,
      category: 'notice',
      title: '签到成功',
      firstLine: '你已完成「摄影社团采风活动」签到',
      secondLine: '签到口令 campus2026 已验证通过',
      action: 'activity_checkin',
      unread: true,
    },
    {
      recipient: users.lin._id,
      actor: users.zihao._id,
      post: posts.library._id,
      category: 'interaction',
      title: '新的评论',
      firstLine: '王子豪评论了你的帖子',
      secondLine: '可以在学校公众号里预约，也可以现场扫码查看空位。',
      action: 'comment',
      unread: true,
    },
    {
      recipient: users.lin._id,
      actor: users.kexin._id,
      category: 'interaction',
      title: '新粉丝',
      firstLine: '陈可欣关注了你',
      secondLine: '一起记录校园生活吧',
      action: 'follow',
      unread: false,
    },
    {
      recipient: users.lin._id,
      actor: users.kexin._id,
      group: groups.photoGroup._id,
      category: 'notice',
      title: '社群公告',
      firstLine: '摄影协会发布了新的活动提醒',
      secondLine: '周末采风活动集合地点为图书馆前广场',
      action: 'group_notice',
      unread: true,
    },
  ]);
}

async function seedConversations(users) {
  const conversation1 = await Conversation.create({
    participants: [users.lin._id, users.kexin._id],
    lastMessage: '签到口令是 campus2026，活动当天输入即可完成签到。',
  });

  await Message.create([
    {
      conversation: conversation1._id,
      sender: users.kexin._id,
      text: '你好，摄影社团采风活动还有名额，可以直接在活动详情页报名。',
      readBy: [users.kexin._id],
    },
    {
      conversation: conversation1._id,
      sender: users.lin._id,
      text: '[收到] 我已经报名了，签到口令在哪里看？',
      readBy: [users.lin._id, users.kexin._id],
    },
    {
      conversation: conversation1._id,
      sender: users.kexin._id,
      text: '签到口令是 campus2026，活动当天输入即可完成签到。',
      readBy: [users.kexin._id],
    },
  ]);

  const conversation2 = await Conversation.create({
    participants: [users.lin._id, users.zihao._id],
    lastMessage: 'AI 讲座结束后可以一起整理笔记。',
  });

  await Message.create([
    {
      conversation: conversation2._id,
      sender: users.zihao._id,
      text: 'AI 讲座结束后可以一起整理笔记。',
      readBy: [users.zihao._id, users.lin._id],
    },
    {
      conversation: conversation2._id,
      sender: users.lin._id,
      text: '[点赞] 可以，我也想补充一些项目实践内容。',
      readBy: [users.zihao._id, users.lin._id],
    },
  ]);

  return [conversation1, conversation2];
}

async function seedPersonalData(users, posts, activities, groups) {
  await BrowsingHistory.create([
    {
      user: users.lin._id,
      kind: 'activity',
      refId: activities.photo._id,
      title: '摄影社团采风活动',
      subtitle: '图书馆前广场集合 · 06:30-10:30',
      imageUrl: image.photo,
    },
    {
      user: users.lin._id,
      kind: 'post',
      refId: posts.sunset._id,
      title: '校园日落拍摄地推荐',
      subtitle: '陈可欣 · 校园生活',
      imageUrl: image.sunset,
    },
    {
      user: users.lin._id,
      kind: 'group',
      refId: groups.photoGroup._id,
      title: '摄影协会',
      subtitle: '校园摄影、外拍活动和后期修图经验',
      imageUrl: image.photo,
    },
  ]);

  await Draft.create([
    {
      user: users.lin._id,
      kind: 'post',
      title: '期末复习资料整理',
      body: '准备整理一份课程复习资料，后续补充网课链接和题库资源。',
      topic: '学习交流',
      location: '图书馆',
      images: [image.books],
      status: 'draft',
    },
    {
      user: users.lin._id,
      kind: 'activity',
      title: '晨跑打卡活动策划',
      body: '计划组织一个为期一周的校园晨跑打卡活动。',
      topic: '运动',
      location: '操场',
      images: [image.sport],
      status: 'draft',
    },
  ]);
}

async function refreshCounters(users, posts, activities, groups) {
  for (const user of Object.values(users)) {
    const [followers, following] = await Promise.all([
      Follow.countDocuments({ following: user._id }),
      Follow.countDocuments({ follower: user._id }),
    ]);
    await User.updateOne({ _id: user._id }, { followers, following });
  }

  for (const post of posts.all) {
    const [likes, comments, saves] = await Promise.all([
      Like.countDocuments({ post: post._id }),
      Comment.countDocuments({ post: post._id }),
      Favorite.countDocuments({ post: post._id }),
    ]);
    await Post.updateOne(
      { _id: post._id },
      {
        likes,
        comments,
        saves,
        shares: Math.min(3, Math.max(0, comments)),
      }
    );
  }

  for (const activity of activities.all) {
    const enrolled = await Enrollment.countDocuments({
      activity: activity._id,
      status: 'registered',
    });
    await Activity.updateOne({ _id: activity._id }, { enrolled });
  }

  const photoDiscussions = [posts.sunset._id, posts.photoNotice._id];
  const aiDiscussions = [posts.aiNote._id];

  await Group.updateOne(
    { _id: groups.photoGroup._id },
    {
      members: await GroupMembership.countDocuments({
        group: groups.photoGroup._id,
        status: 'active',
      }),
      admins: await GroupMembership.countDocuments({
        group: groups.photoGroup._id,
        status: 'active',
        role: { $in: ['owner', 'admin'] },
      }),
      activityIds: [activities.photo._id],
      discussionIds: photoDiscussions,
      pinnedDiscussionIds: photoDiscussions,
    }
  );

  await Group.updateOne(
    { _id: groups.aiGroup._id },
    {
      members: await GroupMembership.countDocuments({
        group: groups.aiGroup._id,
        status: 'active',
      }),
      admins: await GroupMembership.countDocuments({
        group: groups.aiGroup._id,
        status: 'active',
        role: { $in: ['owner', 'admin'] },
      }),
      activityIds: [activities.ai._id],
      discussionIds: aiDiscussions,
      pinnedDiscussionIds: aiDiscussions,
    }
  );
}

async function main() {
  console.log('====== 连接 MongoDB ======');
  console.log(MONGODB_URI);

  await mongoose.connect(MONGODB_URI, {
    serverSelectionTimeoutMS: 5000,
  });

  console.log('====== 清理旧演示数据 ======');
  await clearOldDemoData();

  console.log('====== 写入用户 ======');
  const users = await seedUsers();

  console.log('====== 写入社群 ======');
  const groups = await seedGroups(users);

  console.log('====== 写入活动 ======');
  const activities = await seedActivities(users, groups);

  console.log('====== 写入帖子 ======');
  const posts = await seedPosts(users, groups);

  console.log('====== 写入互动关系 ======');
  await seedRelations(users, posts, activities);

  console.log('====== 写入报名与签到 ======');
  await seedEnrollmentAndCheckIn(users, activities);

  console.log('====== 写入通知 ======');
  await seedNotifications(users, posts, activities, groups);

  console.log('====== 写入私信 ======');
  await seedConversations(users);

  console.log('====== 写入个人中心数据 ======');
  await seedPersonalData(users, posts, activities, groups);

  console.log('====== 刷新统计数字 ======');
  await refreshCounters(users, posts, activities, groups);

  console.log('');
  console.log('✅ 演示数据写入完成');
  console.log('');
  console.table([
    { name: '林同学', username: '18800000001', password: PASSWORD, usage: '主账号：报名、签到、通知、私信、个人中心截图' },
    { name: '陈可欣', username: '18800000002', password: PASSWORD, usage: '活动发布者 / 摄影协会负责人' },
    { name: '王子豪', username: '18800000003', password: PASSWORD, usage: '评论、点赞、AI 讲座、篮球活动' },
    { name: '刘思雨', username: '18800000004', password: PASSWORD, usage: '图书馆学习、收藏、评论' },
  ]);

  console.log('');
  console.log('签到口令：campus2026');
  console.log('推荐先登录：18800000001 / 123456');
}

main()
  .catch((error) => {
    console.error('❌ seed 失败：', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
