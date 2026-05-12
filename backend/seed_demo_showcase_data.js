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
const Topic = require('./src/models/Topic');
const User = require('./src/models/User');

const MONGODB_URI =
  process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/campus_social';
const PASSWORD = '123456';
const CHECK_IN_CODE = 'campus2026';

const generatedUserPattern = /^(paper_real_|showcase_|demo_|seed_)/;

const oldGeneratedNames = [
  'Flutter校园开发组',
  '活动运营中心',
  '摄影协会',
  'AI学习小组',
  '图书馆自习联盟',
  '志愿服务队',
  '篮球与夜跑社',
  '新媒体海报工坊',
  '数据库设计讨论组',
  '校园认证体验小队',
  '校园活动报名',
  '口令签到实践',
  'Flutter移动端',
  'Node.js接口',
  'MongoDB数据模型',
  '校园摄影采风',
  '学习打卡',
  '社群管理',
  '活动测试记录',
  '校园志愿服务',
  '运动与健康',
  '毕业设计交流',
];

const usersSeed = [
  ['demo_student_001', '刘凯旗', '学生', '计算机学院 / 计算机科学与技术', '2024级', 'asset:assets/images/asian_student_male_01.png'],
  ['demo_student_002', '沈清禾', '学生', '大数据学院 / 数据科学与大数据技术', '2023级', 'asset:assets/images/asian_student_female_02.png'],
  ['demo_student_003', '陈可欣', '学生', '艺术传媒学院 / 网络与新媒体', '2022级', 'asset:assets/images/asian_student_female_03.png'],
  ['demo_student_004', '王子豪', '学生', '通信与信息工程学院 / 人工智能', '2025级', 'asset:assets/images/asian_student_male_04.png'],
  ['demo_organizer_001', '杨老师', '教师', '计算机学院', '教师', 'asset:assets/images/asian_student_male_05.png'],
  ['demo_admin_001', '周予安', '社群管理员', '计算机学院 / 智能科学与技术', '2023级', 'asset:assets/images/asian_student_male_06.png'],
  ['demo_photo_001', '林嘉宁', '社团负责人', '艺术传媒学院 / 视觉传达设计', '2022级', 'asset:assets/images/asian_student_female_07.png'],
  ['demo_volunteer_001', '苏语桐', '志愿者', '数字经济商学院 / 工商管理', '2024级', 'asset:assets/images/asian_student_female_08.png'],
];

const topicSeeds = [
  ['校园活动', '活动报名、现场签到和活动复盘都集中在这里。', 'asset:assets/images/activity_stage_blue.png'],
  ['社团招新', '摄影、音乐、运动和志愿服务社团的活动信息。', 'asset:assets/images/activity_recruit_banner.png'],
  ['学习讲座', '公开课、技术分享和学习互助活动。', 'asset:assets/images/activity_ai_head.png'],
  ['志愿服务', '校园公益、社区服务和志愿招募。', 'asset:assets/images/activity_volunteer_hands.png'],
];

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

function dateText(date) {
  return `${date.getMonth() + 1}月${date.getDate()}日`;
}

function timeText(start, end) {
  const pad = (value) => String(value).padStart(2, '0');
  return `${pad(start.getHours())}:${pad(start.getMinutes())}-${pad(end.getHours())}:${pad(end.getMinutes())}`;
}

function idOf(doc) {
  return doc._id;
}

async function clearGeneratedData() {
  const generatedUsers = await User.find({
    $or: [
      { username: generatedUserPattern },
      { name: { $in: usersSeed.map((item) => item[1]) } },
    ],
  }).select('_id');
  const userIds = generatedUsers.map(idOf);

  const generatedGroups = await Group.find({
    $or: [
      { name: { $in: oldGeneratedNames } },
      { name: { $regex: /^(校园活动中心|摄影协会|志愿服务队)$/ } },
    ],
  }).select('_id');
  const groupIds = generatedGroups.map(idOf);

  const generatedTopics = await Topic.find({
    $or: [
      { name: { $in: oldGeneratedNames } },
      { name: { $in: topicSeeds.map((item) => item[0]) } },
    ],
  }).select('_id');
  const topicIds = generatedTopics.map(idOf);

  const generatedActivities = await Activity.find({
    $or: [
      { createdBy: { $in: userIds } },
      { group: { $in: groupIds } },
      { title: { $regex: /(校园歌手大赛|AI公开课|摄影社春日采风|志愿服务招募|篮球友谊赛|社群管理员训练营|测试|论文|毕业设计|流程彩排|截图素材)/ } },
    ],
  }).select('_id');
  const activityIds = generatedActivities.map(idOf);

  const generatedPosts = await Post.find({
    $or: [
      { author: { $in: userIds } },
      { group: { $in: groupIds } },
      { topic: { $in: topicSeeds.map((item) => item[0]) } },
      { title: { $regex: /(校园歌手大赛|摄影采风|AI公开课|志愿服务|活动复盘|测试|论文|截图)/ } },
    ],
  }).select('_id');
  const postIds = generatedPosts.map(idOf);

  const generatedConversations = await Conversation.find({
    participants: { $in: userIds },
  }).select('_id');
  const conversationIds = generatedConversations.map(idOf);

  await Promise.all([
    Message.deleteMany({
      $or: [{ conversation: { $in: conversationIds } }, { sender: { $in: userIds } }],
    }),
    Conversation.deleteMany({ _id: { $in: conversationIds } }),
    Notification.deleteMany({
      $or: [
        { recipient: { $in: userIds } },
        { actor: { $in: userIds } },
        { post: { $in: postIds } },
        { activity: { $in: activityIds } },
        { group: { $in: groupIds } },
      ],
    }),
    BrowsingHistory.deleteMany({
      $or: [
        { user: { $in: userIds } },
        { refId: { $in: [...postIds, ...activityIds, ...groupIds, ...topicIds] } },
      ],
    }),
    CheckIn.deleteMany({
      $or: [{ user: { $in: userIds } }, { activity: { $in: activityIds } }],
    }),
    Enrollment.deleteMany({
      $or: [{ user: { $in: userIds } }, { activity: { $in: activityIds } }],
    }),
    Comment.deleteMany({
      $or: [
        { author: { $in: userIds } },
        { post: { $in: postIds } },
        { activity: { $in: activityIds } },
      ],
    }),
    Like.deleteMany({
      $or: [{ user: { $in: userIds } }, { post: { $in: postIds } }],
    }),
    Favorite.deleteMany({
      $or: [
        { user: { $in: userIds } },
        { post: { $in: postIds } },
        { activity: { $in: activityIds } },
      ],
    }),
    Follow.deleteMany({
      $or: [{ follower: { $in: userIds } }, { following: { $in: userIds } }],
    }),
    Draft.deleteMany({ user: { $in: userIds } }),
    GroupMembership.deleteMany({
      $or: [{ user: { $in: userIds } }, { group: { $in: groupIds } }],
    }),
  ]);

  await Promise.all([
    Post.deleteMany({ _id: { $in: postIds } }),
    Activity.deleteMany({ _id: { $in: activityIds } }),
    Group.deleteMany({ _id: { $in: groupIds } }),
    Topic.deleteMany({ _id: { $in: topicIds } }),
    User.deleteMany({ _id: { $in: userIds } }),
  ]);
}

async function createUsers() {
  const passwordHash = hashPassword(PASSWORD);
  const docs = await User.create(
    usersSeed.map(([username, name, role, major, grade, avatarUrl], index) => {
      const teacher = role === '教师';
      return {
        username,
        name,
        passwordHash,
        school: '重庆移通学院',
        major,
        grade,
        avatarUrl,
        bio: teacher
          ? '负责校园活动组织与现场签到管理。'
          : '喜欢参加校园活动，也会在平台里记录活动体验。',
        role,
        realName: name,
        studentId: teacher
          ? `T2026${String(index + 1).padStart(3, '0')}`
          : `2024${String(3000 + index).padStart(4, '0')}`,
        campusName: '重庆移通学院',
        campusVerified: true,
        campusRole: teacher ? 'teacher' : 'student',
        enrollmentYear: teacher ? '2020' : grade.replace('级', ''),
      };
    })
  );
  return Object.fromEntries(docs.map((user) => [user.username, user]));
}

async function createTopics() {
  const docs = await Topic.create(
    topicSeeds.map(([name, description, coverUrl], index) => ({
      name,
      description,
      coverUrl,
      onlineCount: 26 + index * 9,
      discussions: `${12 + index * 4}条讨论`,
      relatedTopics: topicSeeds.filter((item) => item[0] !== name).map((item) => item[0]).slice(0, 3),
    }))
  );
  return Object.fromEntries(docs.map((topic) => [topic.name, topic]));
}

async function createGroups(users) {
  const groups = await Group.create([
    {
      name: '校园活动中心',
      description: '统一发布校内活动、报名提醒和现场签到安排。',
      coverUrl: 'asset:assets/images/activity_stage_blue.png',
      iconUrl: 'asset:assets/images/activity_recruit_banner.png',
      tags: ['活动', '报名', '签到'],
      members: 0,
      admins: 0,
      visibility: 'public',
      announcementText: '本周活动报名和签到都在平台内完成，请留意活动详情页的口令提示。',
      announcementUpdatedAt: new Date(),
      announcementUpdatedBy: users.demo_organizer_001._id,
    },
    {
      name: '摄影协会',
      description: '组织校园采风、活动跟拍和作品分享。',
      coverUrl: 'asset:assets/images/activity_photo_camera.png',
      iconUrl: 'asset:assets/images/activity_photo_thumb.png',
      tags: ['摄影', '社团', '采风'],
      members: 0,
      admins: 0,
      visibility: 'approval',
      announcementText: '春日采风活动已开放报名，集合地点以活动详情为准。',
      announcementUpdatedAt: new Date(),
      announcementUpdatedBy: users.demo_photo_001._id,
    },
    {
      name: '志愿服务队',
      description: '发布校园志愿服务、社区公益和活动现场协助招募。',
      coverUrl: 'asset:assets/images/activity_volunteer_hands.png',
      iconUrl: 'asset:assets/images/asian_student_female_08.png',
      tags: ['志愿', '公益', '服务'],
      members: 0,
      admins: 0,
      visibility: 'public',
      announcementText: '志愿活动名额有限，报名成功后请按时到场签到。',
      announcementUpdatedAt: new Date(),
      announcementUpdatedBy: users.demo_volunteer_001._id,
    },
  ]);

  const memberships = [
    [groups[0], users.demo_organizer_001, 'owner'],
    [groups[0], users.demo_admin_001, 'admin'],
    [groups[0], users.demo_student_001, 'member'],
    [groups[0], users.demo_student_002, 'member'],
    [groups[1], users.demo_photo_001, 'owner'],
    [groups[1], users.demo_student_001, 'member'],
    [groups[1], users.demo_student_003, 'member'],
    [groups[2], users.demo_volunteer_001, 'owner'],
    [groups[2], users.demo_student_002, 'member'],
    [groups[2], users.demo_student_004, 'member'],
  ];

  await GroupMembership.create(
    memberships.map(([group, user, role]) => ({
      group: group._id,
      user: user._id,
      role,
      status: 'active',
      reviewedBy: group.announcementUpdatedBy,
      reviewedAt: new Date(),
    }))
  );

  for (const group of groups) {
    group.members = await GroupMembership.countDocuments({ group: group._id, status: 'active' });
    group.admins = await GroupMembership.countDocuments({
      group: group._id,
      status: 'active',
      role: { $in: ['owner', 'admin'] },
    });
    await group.save();
  }

  return Object.fromEntries(groups.map((group) => [group.name, group]));
}

async function createActivities(users, groups) {
  const now = new Date();
  const tomorrow = addMinutes(now, 24 * 60);
  const dayAfter = addMinutes(now, 48 * 60);
  const threeDays = addMinutes(now, 72 * 60);
  const yesterday = addMinutes(now, -24 * 60);

  const specs = [
    {
      key: 'singing',
      title: '校园歌手大赛',
      category: '文艺',
      group: groups['校园活动中心'],
      createdBy: users.demo_organizer_001,
      posterUrl: 'asset:assets/images/activity_music_thumb.png',
      date: dateText(now),
      time: '00:00-23:59',
      location: '大学生活动中心礼堂',
      host: '校学生会文艺部',
      capacity: 120,
      description: '面向全校同学开放的校园歌手舞台，报名后可在现场使用口令签到。',
      tags: ['音乐', '舞台', '签到中'],
    },
    {
      key: 'ai',
      title: 'AI公开课：生成式应用实践',
      category: '讲座',
      group: groups['校园活动中心'],
      createdBy: users.demo_organizer_001,
      posterUrl: 'asset:assets/images/activity_ai_head.png',
      date: dateText(tomorrow),
      time: '14:00-16:00',
      location: '图书馆报告厅 A',
      host: '计算机学院',
      capacity: 80,
      description: '围绕生成式 AI 工具、校园应用案例和移动端开发实践进行分享。',
      tags: ['AI', '讲座', '学习'],
    },
    {
      key: 'photo',
      title: '摄影社春日采风',
      category: '社团',
      group: groups['摄影协会'],
      createdBy: users.demo_photo_001,
      posterUrl: 'asset:assets/images/activity_photo_camera.png',
      date: dateText(dayAfter),
      time: '09:30-12:00',
      location: '南湖广场集合点',
      host: '摄影协会',
      capacity: 30,
      description: '沿校园湖畔和教学区进行采风拍摄，活动结束后可在社群内分享作品。',
      tags: ['摄影', '采风', '社团'],
    },
    {
      key: 'volunteerFull',
      title: '志愿服务招募',
      category: '志愿',
      group: groups['志愿服务队'],
      createdBy: users.demo_volunteer_001,
      posterUrl: 'asset:assets/images/activity_volunteer_hands.png',
      date: dateText(threeDays),
      time: '08:30-11:30',
      location: '校门口志愿服务站',
      host: '志愿服务队',
      capacity: 1,
      description: '协助校园开放日引导和签到，本场用于演示名额已满的报名拦截。',
      tags: ['志愿', '公益', '名额已满'],
    },
    {
      key: 'basketballDone',
      title: '篮球友谊赛',
      category: '体育',
      group: groups['校园活动中心'],
      createdBy: users.demo_admin_001,
      posterUrl: 'asset:assets/images/activity_basketball_court.png',
      date: dateText(yesterday),
      time: '16:00-18:00',
      location: '东区篮球场',
      host: '篮球与夜跑社',
      capacity: 60,
      description: '学院间篮球友谊赛，已完成报名和签到，可用于展示历史记录。',
      tags: ['篮球', '运动', '已结束'],
    },
    {
      key: 'groupAdmin',
      title: '社群管理员训练营',
      category: '社群',
      group: groups['校园活动中心'],
      createdBy: users.demo_admin_001,
      posterUrl: 'asset:assets/images/activity_recruit_banner.png',
      date: dateText(threeDays),
      time: '15:00-17:00',
      location: '学生事务中心 201',
      host: '校园活动中心',
      capacity: 40,
      description: '讲解社群公告、成员审核、置顶讨论和社群活动发布流程。',
      tags: ['社群', '管理', '公告'],
    },
  ];

  const docs = await Activity.create(
    specs.map((item) => ({
      createdBy: item.createdBy._id,
      group: item.group._id,
      title: item.title,
      category: item.category,
      posterUrl: item.posterUrl,
      images: [item.posterUrl],
      date: item.date,
      time: item.time,
      location: item.location,
      host: item.host,
      enrolled: 0,
      capacity: item.capacity,
      price: '免费',
      description: item.description,
      checkInCode: CHECK_IN_CODE,
      allowComments: true,
      publicDisplay: true,
      registrationDeadline: item.date,
      tags: item.tags,
    }))
  );

  const byKey = Object.fromEntries(docs.map((doc, index) => [specs[index].key, doc]));
  for (const doc of docs) {
    await Group.updateOne({ _id: doc.group }, { $addToSet: { activityIds: doc._id } });
  }
  return byKey;
}

async function createPosts(users, groups, topics) {
  const posts = await Post.create([
    {
      author: users.demo_student_001._id,
      group: groups['校园活动中心']._id,
      title: '校园歌手大赛报名入口已经开放',
      body: '今天在首页看到校园歌手大赛，报名、收藏和签到入口都在同一个活动详情页里。',
      topic: '校园活动',
      images: ['asset:assets/images/activity_music_thumb.png'],
      location: '大学生活动中心',
      shares: 6,
      pinnedInGroup: true,
    },
    {
      author: users.demo_photo_001._id,
      group: groups['摄影协会']._id,
      title: '摄影社春日采风路线公布',
      body: '本次采风从南湖广场出发，沿图书馆和教学楼外景拍摄，欢迎同学报名参加。',
      topic: '社团招新',
      images: ['asset:assets/images/activity_photo_thumb.png'],
      location: '南湖广场',
      shares: 3,
      pinnedInGroup: true,
    },
    {
      author: users.demo_organizer_001._id,
      group: groups['校园活动中心']._id,
      title: 'AI公开课明天下午开讲',
      body: '本场公开课会结合 Flutter 校园应用案例讲生成式 AI 的实际使用方式。',
      topic: '学习讲座',
      images: ['asset:assets/images/activity_ai_thumb.png'],
      location: '图书馆报告厅 A',
      shares: 5,
    },
    {
      author: users.demo_volunteer_001._id,
      group: groups['志愿服务队']._id,
      title: '志愿服务活动名额已经报满',
      body: '本场开放日协助岗位只有 1 个名额，后续还会继续发布新的志愿服务活动。',
      topic: '志愿服务',
      images: ['asset:assets/images/activity_volunteer_hands.png'],
      location: '校门口志愿服务站',
      shares: 2,
    },
  ]);

  for (const group of Object.values(groups)) {
    const groupPosts = posts.filter((post) => String(post.group) === String(group._id));
    group.discussionIds = groupPosts.map(idOf);
    group.pinnedDiscussionIds = groupPosts.filter((post) => post.pinnedInGroup).map(idOf);
    await group.save();
  }

  for (const topic of Object.values(topics)) {
    const related = posts.filter((post) => post.topic === topic.name);
    topic.postIds = related.map(idOf);
    topic.contributorIds = [...new Set(related.map((post) => String(post.author)))];
    topic.discussions = `${related.length + topic.onlineCount}条讨论`;
    await topic.save();
  }

  return posts;
}

async function createRelations(users, activities, posts) {
  const enrollments = await Enrollment.create([
    { activity: activities.singing._id, user: users.demo_student_001._id, status: 'registered' },
    { activity: activities.singing._id, user: users.demo_student_002._id, status: 'registered' },
    { activity: activities.singing._id, user: users.demo_student_003._id, status: 'registered' },
    { activity: activities.singing._id, user: users.demo_student_004._id, status: 'registered' },
    { activity: activities.photo._id, user: users.demo_student_001._id, status: 'registered' },
    { activity: activities.photo._id, user: users.demo_student_003._id, status: 'registered' },
    { activity: activities.volunteerFull._id, user: users.demo_student_002._id, status: 'registered' },
    { activity: activities.basketballDone._id, user: users.demo_student_001._id, status: 'registered' },
    { activity: activities.basketballDone._id, user: users.demo_student_004._id, status: 'registered' },
    { activity: activities.groupAdmin._id, user: users.demo_student_002._id, status: 'cancelled' },
  ]);

  const enrollmentBy = (activity, user) =>
    enrollments.find((item) =>
      String(item.activity) === String(activity._id) && String(item.user) === String(user._id)
    );

  await CheckIn.create([
    {
      activity: activities.singing._id,
      user: users.demo_student_002._id,
      enrollment: enrollmentBy(activities.singing, users.demo_student_002)._id,
      code: CHECK_IN_CODE,
    },
    {
      activity: activities.singing._id,
      user: users.demo_student_003._id,
      enrollment: enrollmentBy(activities.singing, users.demo_student_003)._id,
      code: CHECK_IN_CODE,
    },
    {
      activity: activities.basketballDone._id,
      user: users.demo_student_001._id,
      enrollment: enrollmentBy(activities.basketballDone, users.demo_student_001)._id,
      code: CHECK_IN_CODE,
    },
  ]);

  await Promise.all(Object.values(activities).map(async (activity) => {
    activity.enrolled = await Enrollment.countDocuments({
      activity: activity._id,
      status: 'registered',
    });
    await activity.save();
  }));

  const comments = await Comment.create([
    {
      kind: 'activity',
      activity: activities.singing._id,
      author: users.demo_student_002._id,
      text: '我已经报名，现场会提前到签到台试一下口令签到。',
      likes: 2,
    },
    {
      kind: 'activity',
      activity: activities.ai._id,
      author: users.demo_student_003._id,
      text: '这个主题很适合计算机学院同学参加，期待案例分享。',
      likes: 1,
    },
    {
      kind: 'post',
      post: posts[0]._id,
      author: users.demo_student_004._id,
      text: '报名入口很清楚，活动详情里的时间地点也好找。',
      likes: 3,
    },
  ]);

  await Like.create([
    { post: posts[0]._id, user: users.demo_student_002._id },
    { post: posts[0]._id, user: users.demo_student_003._id },
    { post: posts[1]._id, user: users.demo_student_001._id },
  ]);

  await Favorite.create([
    { kind: 'activity', activity: activities.ai._id, user: users.demo_student_001._id },
    { kind: 'activity', activity: activities.photo._id, user: users.demo_student_001._id },
    { kind: 'post', post: posts[1]._id, user: users.demo_student_001._id },
  ]);

  await Follow.create([
    { follower: users.demo_student_001._id, following: users.demo_organizer_001._id },
    { follower: users.demo_student_001._id, following: users.demo_photo_001._id },
    { follower: users.demo_student_002._id, following: users.demo_student_001._id },
  ]);

  for (const post of posts) {
    post.likes = await Like.countDocuments({ post: post._id });
    post.comments = await Comment.countDocuments({ post: post._id });
    post.saves = await Favorite.countDocuments({ post: post._id });
    await post.save();
  }

  for (const user of Object.values(users)) {
    user.followers = await Follow.countDocuments({ following: user._id });
    user.following = await Follow.countDocuments({ follower: user._id });
    await user.save();
  }

  return comments;
}

async function createPersonalData(users, activities, posts, groups, topics) {
  await Notification.create([
    {
      recipient: users.demo_student_001._id,
      actor: users.demo_organizer_001._id,
      activity: activities.singing._id,
      category: 'notice',
      title: '报名成功',
      firstLine: '你已成功报名「校园歌手大赛」',
      secondLine: `${activities.singing.date} ${activities.singing.time} · ${activities.singing.location}`,
      action: 'activity_registered',
      unread: true,
    },
    {
      recipient: users.demo_student_001._id,
      actor: users.demo_organizer_001._id,
      activity: activities.singing._id,
      category: 'notice',
      title: '签到提醒',
      firstLine: '「校园歌手大赛」正在签到',
      secondLine: `现场口令：${CHECK_IN_CODE}`,
      action: 'activity_checkin_available',
      unread: true,
    },
    {
      recipient: users.demo_student_001._id,
      actor: users.demo_student_004._id,
      post: posts[0]._id,
      category: 'interaction',
      title: '帖子有新评论',
      firstLine: '王子豪评论了你的帖子「校园歌手大赛报名入口已经开放」',
      secondLine: '报名入口很清楚，活动详情里的时间地点也好找。',
      action: 'post_commented',
      unread: true,
    },
    {
      recipient: users.demo_organizer_001._id,
      actor: users.demo_student_001._id,
      activity: activities.singing._id,
      category: 'notice',
      title: '新增报名',
      firstLine: '刘凯旗报名了「校园歌手大赛」',
      secondLine: `当前已报名 ${activities.singing.enrolled} 人`,
      action: 'activity_enrollment_new',
      unread: true,
    },
  ]);

  const conversation = await Conversation.create({
    participants: [users.demo_student_001._id, users.demo_organizer_001._id],
    lastMessage: '签到口令就是 campus2026，到现场后输入即可。',
  });
  await Message.create([
    {
      conversation: conversation._id,
      sender: users.demo_student_001._id,
      text: '老师，校园歌手大赛报名后在哪里签到？',
      readBy: [users.demo_student_001._id, users.demo_organizer_001._id],
    },
    {
      conversation: conversation._id,
      sender: users.demo_organizer_001._id,
      text: '进入活动详情页，开始后输入现场口令 campus2026 就可以。',
      readBy: [users.demo_organizer_001._id],
    },
  ]);

  await BrowsingHistory.create([
    {
      user: users.demo_student_001._id,
      kind: 'activity',
      refId: activities.singing._id,
      title: activities.singing.title,
      subtitle: `${activities.singing.date} · ${activities.singing.location}`,
      imageUrl: activities.singing.posterUrl,
    },
    {
      user: users.demo_student_001._id,
      kind: 'activity',
      refId: activities.ai._id,
      title: activities.ai.title,
      subtitle: `${activities.ai.date} · ${activities.ai.location}`,
      imageUrl: activities.ai.posterUrl,
    },
    {
      user: users.demo_student_001._id,
      kind: 'group',
      refId: groups['摄影协会']._id,
      title: '摄影协会',
      subtitle: '社团 · 摄影 / 采风',
      imageUrl: groups['摄影协会'].coverUrl,
    },
    {
      user: users.demo_student_001._id,
      kind: 'topic',
      refId: topics['校园活动']._id,
      title: '校园活动',
      subtitle: topics['校园活动'].discussions,
      imageUrl: topics['校园活动'].coverUrl,
    },
  ]);

  await Draft.create([
    {
      user: users.demo_student_001._id,
      kind: 'post',
      title: '校园歌手大赛现场体验',
      body: '准备活动结束后补充现场照片、签到体验和互动感受。',
      topic: '校园活动',
      location: '大学生活动中心礼堂',
      images: ['asset:assets/images/activity_music_thumb.png'],
      status: 'draft',
    },
    {
      user: users.demo_organizer_001._id,
      kind: 'activity',
      title: '校园读书分享会',
      body: '待确认场地、主持人和活动封面图。',
      topic: '学习讲座',
      location: '图书馆二楼研讨室',
      images: ['asset:assets/images/profile_book.png'],
      status: 'draft',
    },
  ]);
}

async function main() {
  await mongoose.connect(MONGODB_URI, { serverSelectionTimeoutMS: 3000 });
  console.log(`MongoDB connected: ${MONGODB_URI}`);

  await clearGeneratedData();
  const users = await createUsers();
  const topics = await createTopics();
  const groups = await createGroups(users);
  const activities = await createActivities(users, groups);
  const posts = await createPosts(users, groups, topics);
  await createRelations(users, activities, posts);
  await createPersonalData(users, activities, posts, groups, topics);

  const counts = {
    demoUsers: await User.countDocuments({ username: generatedUserPattern }),
    activities: await Activity.countDocuments(),
    activeEnrollments: await Enrollment.countDocuments({ status: 'registered' }),
    checkIns: await CheckIn.countDocuments(),
    posts: await Post.countDocuments(),
    groups: await Group.countDocuments(),
    topics: await Topic.countDocuments(),
    notifications: await Notification.countDocuments(),
    conversations: await Conversation.countDocuments(),
    drafts: await Draft.countDocuments(),
  };
  console.table(counts);
  console.log(`Demo login: demo_student_001 / ${PASSWORD}`);
  console.log(`Organizer login: demo_organizer_001 / ${PASSWORD}`);
  console.log(`Check-in code: ${CHECK_IN_CODE}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
