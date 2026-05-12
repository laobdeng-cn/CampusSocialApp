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
const USER_PREFIX = 'paper_real_';

const maleAvatars = Array.from(
  { length: 24 },
  (_, index) => `asset:assets/images/asian_student_male_${String(index + 1).padStart(2, '0')}.png`
);
const femaleAvatars = Array.from(
  { length: 24 },
  (_, index) => `asset:assets/images/asian_student_female_${String(index + 1).padStart(2, '0')}.png`
);

const image = {
  avatars: [...maleAvatars, ...femaleAvatars],
  posts: [
    'asset:assets/images/profile_sunset.png',
    'asset:assets/images/profile_book.png',
    'asset:assets/images/profile_food_collage.png',
    'asset:assets/images/profile_design_collage.png',
    'asset:assets/images/comment_library.png',
    'asset:assets/images/comment_study.png',
    'asset:assets/images/comment_autumn.png',
    'asset:assets/images/comment_design_day.png',
  ],
  activities: [
    'asset:assets/images/activity_stage_blue.png',
    'asset:assets/images/activity_music_thumb.png',
    'asset:assets/images/activity_ai_head.png',
    'asset:assets/images/activity_ai_thumb.png',
    'asset:assets/images/activity_photo_camera.png',
    'asset:assets/images/activity_photo_thumb.png',
    'asset:assets/images/activity_basketball_court.png',
    'asset:assets/images/activity_basketball_thumb.png',
    'asset:assets/images/activity_volunteer_hands.png',
    'asset:assets/images/activity_recruit_banner.png',
    'asset:assets/images/activity_checkin_qr.png',
    'asset:assets/images/favorite_music.png',
    'asset:assets/images/favorite_topic_book.png',
  ],
};

const names = [
  '周予安', '沈清禾', '陆星野', '唐若溪', '许知远', '林嘉宁',
  '陈沐阳', '苏语桐', '何景行', '梁思南', '顾明澈', '宋栀夏',
  '蒋一鸣', '孟晚晴', '秦书航', '叶可然', '白子衿', '韩亦辰',
  '罗雨眠', '程砚秋', '魏清越', '姜南星', '邵以宁', '田泽宇',
  '潘若琳', '余舟', '黎嘉树', '夏安然', '袁子墨', '钟意',
  '范晓露', '谢听澜', '高明远', '赵云舒', '马思远', '陶芷晴',
  '曹越', '邱月白', '汪知夏', '傅云深', '董小满', '彭一诺',
  '张老师', '杨老师', '李老师', '王老师',
];

const femaleNames = new Set([
  '沈清禾',
  '唐若溪',
  '林嘉宁',
  '苏语桐',
  '宋栀夏',
  '孟晚晴',
  '叶可然',
  '白子衿',
  '罗雨眠',
  '程砚秋',
  '姜南星',
  '邵以宁',
  '潘若琳',
  '夏安然',
  '钟意',
  '范晓露',
  '谢听澜',
  '赵云舒',
  '陶芷晴',
  '邱月白',
  '汪知夏',
  '董小满',
  '杨老师',
  '李老师',
]);

function avatarForName(name, index = 0) {
  const pool = femaleNames.has(name) ? femaleAvatars : maleAvatars;
  return pool[index % pool.length];
}

const majors = [
  '计算机科学与技术', '软件工程', '数字媒体技术', '视觉传达设计',
  '人工智能', '数据科学与大数据技术', '网络与新媒体', '工商管理',
  '电子信息工程', '英语', '财务管理', '动画',
];

const topics = [
  {
    name: '校园活动报名',
    description: '讨论活动发现、报名、取消报名和名额管理体验。',
    coverUrl: image.activities[0],
    relatedTopics: ['口令签到', '活动通知', '社群活动'],
  },
  {
    name: '口令签到实践',
    description: '围绕签到口令、现场核验、重复签到拦截和签到统计。',
    coverUrl: image.activities[10],
    relatedTopics: ['报名名单', '活动测试', 'MongoDB唯一索引'],
  },
  {
    name: 'Flutter移动端',
    description: 'Flutter 页面、状态管理、图片选择和多端一致体验。',
    coverUrl: image.activities[2],
    relatedTopics: ['Dart开发', '移动端UI', '图片上传'],
  },
  {
    name: 'Node.js接口',
    description: 'Express 路由、JWT 鉴权、RESTful 接口和异常处理。',
    coverUrl: image.posts[5],
    relatedTopics: ['RESTful API', 'JWT认证', '服务端日志'],
  },
  {
    name: 'MongoDB数据模型',
    description: '用户、活动、报名、签到、通知和私信的数据关系。',
    coverUrl: image.posts[1],
    relatedTopics: ['唯一索引', '数据一致性', '集合设计'],
  },
  {
    name: '校园摄影采风',
    description: '分享校园照片、活动花絮和摄影社团采风路线。',
    coverUrl: image.activities[4],
    relatedTopics: ['校园日落', '社团活动', '图片动态'],
  },
  {
    name: '学习打卡',
    description: '图书馆、自习室、复习计划和互助资料分享。',
    coverUrl: image.posts[4],
    relatedTopics: ['资料分享', '期末复习', '读书会'],
  },
  {
    name: '社群管理',
    description: '社群公告、成员审核、置顶讨论和社群活动联动。',
    coverUrl: image.activities[9],
    relatedTopics: ['成员审核', '公告维护', '群内讨论'],
  },
  {
    name: '活动测试记录',
    description: '记录登录、报名、签到、通知和接口测试过程。',
    coverUrl: image.posts[7],
    relatedTopics: ['功能测试', '异常场景', '接口验证'],
  },
  {
    name: '校园志愿服务',
    description: '志愿招募、公益实践、社区服务和活动复盘。',
    coverUrl: image.activities[8],
    relatedTopics: ['公益活动', '报名统计', '活动复盘'],
  },
  {
    name: '运动与健康',
    description: '篮球赛、夜跑、飞盘、体测互助和运动打卡。',
    coverUrl: image.activities[6],
    relatedTopics: ['篮球友谊赛', '夜跑打卡', '社群活动'],
  },
  {
    name: '毕业设计交流',
    description: '论文写作、系统截图、测试数据和答辩准备。',
    coverUrl: image.posts[6],
    relatedTopics: ['论文截图', '系统实现', '测试结果'],
  },
];

const groupSeeds = [
  ['Flutter校园开发组', '一起打磨 Flutter 校园活动平台，交流页面、接口和测试。', ['Flutter', '移动端', '毕业设计']],
  ['活动运营中心', '发布校内活动、报名提醒和签到组织经验。', ['活动管理', '报名', '通知']],
  ['摄影协会', '记录校园活动现场、日落、人像和社团采风。', ['摄影', '外拍', '校园生活']],
  ['AI学习小组', '分享 AI 讲座、模型应用、代码实践和学习资料。', ['AI', '学习', '讲座']],
  ['图书馆自习联盟', '互相提醒座位、复习计划和资料整理。', ['自习', '资料', '打卡']],
  ['志愿服务队', '组织社区服务、校园引导和公益活动复盘。', ['志愿', '公益', '服务']],
  ['篮球与夜跑社', '篮球赛、夜跑打卡、运动搭子集合地。', ['体育', '篮球', '夜跑']],
  ['新媒体海报工坊', '活动海报、推文排版、短视频剪辑交流。', ['设计', '新媒体', '海报']],
  ['数据库设计讨论组', '围绕 MongoDB 集合、索引和接口数据一致性讨论。', ['MongoDB', '后端', '接口']],
  ['校园认证体验小队', '测试注册登录、校园认证和个人资料流程。', ['认证', '测试', '用户体验']],
];

const activitySeeds = [
  ['校园活动平台体验日', '校园活动', image.activities[0], '大学生活动中心一楼大厅', '计算机学院学生科', ['Flutter', '报名', '签到']],
  ['Flutter移动端实战工作坊', '讲座', image.activities[2], '第三教学楼 305', 'Flutter校园开发组', ['Flutter', 'Dart', '移动端']],
  ['Node.js接口设计分享会', '讲座', image.posts[5], '图书馆报告厅 B', '数据库设计讨论组', ['Node.js', 'Express', '接口']],
  ['MongoDB索引与数据模型夜谈', '学习', image.posts[1], '创新创业中心 204', '数据库设计讨论组', ['MongoDB', '索引', '数据一致性']],
  ['口令签到流程彩排', '测试', image.activities[10], '大学生活动中心签到台', '活动运营中心', ['签到', '报名名单', '通知']],
  ['校园音乐之夜志愿招募', '文艺', image.activities[1], '大学生活动中心礼堂', '校学生会文艺部', ['音乐', '志愿者', '现场']],
  ['摄影协会春日采风', '社团', image.activities[4], '南山植物园集合点', '摄影协会', ['摄影', '外拍', '社团']],
  ['AI未来趋势公开课', '讲座', image.activities[3], '图书馆报告厅 A', 'AI学习小组', ['AI', '讲座', '技术']],
  ['校园篮球友谊赛', '体育', image.activities[6], '东区篮球场', '篮球与夜跑社', ['篮球', '运动', '组队']],
  ['夜跑打卡挑战', '体育', image.activities[7], '田径场入口', '篮球与夜跑社', ['夜跑', '健康', '打卡']],
  ['社区志愿服务行动', '志愿', image.activities[8], '校门口志愿服务站', '志愿服务队', ['志愿', '社区', '公益']],
  ['活动海报设计实战', '设计', image.posts[3], '艺术楼 402', '新媒体海报工坊', ['设计', '海报', '活动宣传']],
  ['图书馆高效复习打卡', '学习', image.posts[4], '图书馆三楼自习区', '图书馆自习联盟', ['自习', '复习', '打卡']],
  ['毕业设计截图素材共创', '毕业设计', image.posts[7], '实验楼 502', 'Flutter校园开发组', ['论文截图', '测试数据', '展示']],
  ['社群管理员训练营', '社群', image.activities[9], '学生事务中心 201', '活动运营中心', ['社群', '公告', '审核']],
  ['校园认证流程体验测评', '测试', image.posts[2], '线上活动', '校园认证体验小队', ['认证', '注册登录', '用户资料']],
  ['私信与通知联动测试', '测试', image.activities[5], '实验楼 406', '计算机学院学生科', ['通知', '私信', '互动']],
  ['活动复盘圆桌会', '交流', image.activities[11], '咖啡书吧二楼', '活动运营中心', ['复盘', '评论', '沉淀']],
  ['资料分享与期末互助会', '学习', image.activities[12], '图书馆研讨室 2', '图书馆自习联盟', ['资料分享', '期末', '互助']],
  ['校园服务产品体验沙龙', '交流', image.posts[0], '创新创业中心路演厅', '计算机学院', ['产品体验', '校园服务', '反馈']],
];

const postTemplates = [
  ['今天把{topic}流程跑通了', '从浏览、报名到通知都试了一遍，感觉统一入口真的省事。图片和状态展示也比之前分散在群里清楚很多。'],
  ['关于{topic}的一点体验记录', '最明显的感受是信息不再散落在公众号和群公告里，后续如果能加推荐排序会更完整。'],
  ['{topic}页面截图准备好了', '这组截图可以放到论文实现章节里，列表、详情、表单和状态反馈都比较完整。'],
  ['有人一起参加{topic}相关活动吗', '想找几位同学一起测试报名、取消报名、签到和评论流程，顺便整理一份体验反馈。'],
  ['{topic}的数据模型这样设计合理吗', '我把用户、活动、关系记录和通知分开存，靠唯一索引控制重复提交，整体看起来比较稳。'],
  ['活动结束后的交流应该沉淀在哪里', '如果评论、照片和复盘都能关联到活动或社群，之后回看会方便很多，也更符合校园社交平台的定位。'],
  ['图片上传终于稳定了', '头像、活动封面和动态图片用统一资源路径展示，移动端页面一下子真实了不少。'],
  ['报名名单和签到名单怎么对齐', '报名关系和签到记录分开保存，再通过活动和用户做唯一约束，统计已签到和未签到会很直接。'],
];

function datePlus(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date;
}

function isoDate(days) {
  return datePlus(days).toISOString().slice(0, 10);
}

function pick(items, index) {
  return items[index % items.length];
}

function idOf(doc) {
  return doc._id;
}

async function clearPreviousGeneratedData() {
  const users = await User.find({ username: { $regex: `^${USER_PREFIX}` } }).select('_id');
  const userIds = users.map(idOf);
  const groups = await Group.find({ name: { $in: groupSeeds.map((item) => item[0]) } }).select('_id');
  const groupIds = groups.map(idOf);
  const topicsFound = await Topic.find({ name: { $in: topics.map((item) => item.name) } }).select('_id');
  const topicIds = topicsFound.map(idOf);
  const activities = await Activity.find({
    $or: [
      { createdBy: { $in: userIds } },
      { group: { $in: groupIds } },
      { title: { $in: activitySeeds.map((item) => item[0]) } },
    ],
  }).select('_id');
  const activityIds = activities.map(idOf);
  const posts = await Post.find({
    $or: [
      { author: { $in: userIds } },
      { group: { $in: groupIds } },
    ],
  }).select('_id');
  const postIds = posts.map(idOf);
  const conversations = await Conversation.find({
    participants: { $in: userIds },
  }).select('_id');
  const conversationIds = conversations.map(idOf);

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

async function main() {
  await mongoose.connect(MONGODB_URI);
  console.log(`MongoDB connected: ${MONGODB_URI}`);
  await clearPreviousGeneratedData();

  const passwordHash = hashPassword(PASSWORD);
  const users = await User.create(
    names.map((name, index) => {
      const teacher = name.endsWith('老师');
      const enrollmentYear = teacher ? '2020' : String(2022 + (index % 4));
      return {
        name,
        username: `${USER_PREFIX}${String(index + 1).padStart(3, '0')}`,
        passwordHash,
        school: '重庆移通学院',
        major: teacher ? '计算机学院' : pick(majors, index),
        grade: teacher ? '教师' : `${enrollmentYear}级`,
        avatarUrl: avatarForName(name, index),
        bio: teacher
          ? '负责校园活动组织与系统测试，关注流程闭环和数据安全。'
          : `关注${pick(topics, index).name}，常参加校园活动和社群讨论。`,
        role: teacher ? '教师' : index % 5 === 0 ? '社群管理员' : '学生',
        realName: name,
        studentId: teacher
          ? `T2026${String(index).padStart(3, '0')}`
          : `2026${String(2400 + index).padStart(4, '0')}`,
        campusName: '重庆移通学院',
        campusVerified: true,
        campusRole: teacher ? 'teacher' : 'student',
        enrollmentYear,
        settings: {
          notifications: {
            messageReminder: index % 7 !== 0,
            activityNotice: true,
            systemNotice: true,
          },
          privacy: {
            allowSearch: true,
            blockStrangerComments: index % 6 === 0,
            profileVisibility: index % 4 === 0 ? 'public' : 'friends',
            dmPermission: 'friends_and_following',
          },
        },
      };
    })
  );

  const topicDocs = await Topic.create(
    topics.map((topic, index) => ({
      ...topic,
      onlineCount: 60 + index * 13,
      discussions: '0条讨论',
    }))
  );

  const groups = await Group.create(
    groupSeeds.map(([name, description, tags], index) => ({
      name,
      description,
      coverUrl: pick([...image.activities, ...image.posts], index),
      iconUrl: pick(image.avatars, index),
      tags,
      members: 0,
      admins: 1,
      visibility: index % 3 === 0 ? 'public' : 'approval',
      announcementText: `${name} 本周会围绕论文系统主流程安排一次体验和复盘，欢迎带截图、问题和建议参加。`,
      announcementUpdatedAt: datePlus(-index - 1),
      announcementUpdatedBy: users[index % users.length]._id,
    }))
  );

  const memberships = [];
  groups.forEach((group, groupIndex) => {
    const owner = users[groupIndex % users.length];
    memberships.push({
      group: group._id,
      user: owner._id,
      role: 'owner',
      status: 'active',
    });
    for (let offset = 1; offset <= 25; offset += 1) {
      const user = users[(groupIndex * 3 + offset) % users.length];
      const role = offset % 13 === 0 ? 'admin' : 'member';
      const status = offset % 17 === 0 ? 'pending' : 'active';
      memberships.push({
        group: group._id,
        user: user._id,
        role,
        status,
        reviewedBy: status === 'active' ? owner._id : undefined,
        reviewedAt: status === 'active' ? datePlus(-offset) : undefined,
      });
    }
  });
  await GroupMembership.insertMany(memberships, { ordered: false }).catch((error) => {
    if (error?.code !== 11000) throw error;
  });

  const activeMemberships = await GroupMembership.find({ status: 'active' });
  for (const group of groups) {
    const groupMembers = activeMemberships.filter(
      (item) => String(item.group) === String(group._id)
    );
    group.members = groupMembers.length;
    group.admins = groupMembers.filter((item) =>
      ['owner', 'admin'].includes(item.role)
    ).length;
    await group.save();
  }

  const activities = await Activity.create(
    activitySeeds.map(([title, category, posterUrl, location, host, tags], index) => {
      const group = groups[index % groups.length];
      const creator = users[(index * 2 + 3) % users.length];
      return {
        createdBy: creator._id,
        group: group._id,
        title,
        category,
        posterUrl,
        images: [posterUrl, pick(image.activities, index + 3)],
        date: isoDate(index - 5),
        time: `${String(9 + (index % 10)).padStart(2, '0')}:30-${String(11 + (index % 10)).padStart(2, '0')}:30`,
        location,
        host,
        enrolled: 0,
        capacity: 80 + (index % 8) * 30,
        price: index % 6 === 0 ? '报名后免费入场' : '免费',
        description: `围绕论文中的${tags.join('、')}场景组织真实流程体验，覆盖信息发布、报名确认、现场签到、通知提醒和活动后交流。`,
        checkInCode: 'campus2026',
        allowComments: true,
        publicDisplay: true,
        registrationDeadline: isoDate(index - 6),
        tags,
      };
    })
  );

  for (let index = 0; index < activities.length; index += 1) {
    await Group.updateOne(
      { _id: groups[index % groups.length]._id },
      { $addToSet: { activityIds: activities[index]._id } }
    );
  }

  const postsPayload = [];
  for (let index = 0; index < users.length * 2; index += 1) {
    const user = users[index % users.length];
    const topic = topics[index % topics.length];
    const [titleTpl, bodyTpl] = postTemplates[index % postTemplates.length];
    const group = index % 3 === 0 ? groups[index % groups.length] : null;
    postsPayload.push({
      author: user._id,
      group: group?._id,
      title: titleTpl.replace('{topic}', topic.name),
      body: bodyTpl.replace('{topic}', topic.name),
      topic: topic.name,
      images: index % 4 === 0
        ? [pick(image.posts, index), pick(image.posts, index + 1)]
        : [pick([...image.posts, ...image.activities], index)],
      location: pick(
        ['图书馆', '大学生活动中心', '第三教学楼', '创新创业中心', '东区篮球场', '实验楼', '咖啡书吧'],
        index
      ),
      likes: 0,
      comments: 0,
      saves: 0,
      shares: 2 + (index % 18),
      visibility: 'public',
      pinnedInGroup: index % 15 === 0,
      createdAt: datePlus(-index),
      updatedAt: datePlus(-index),
    });
  }
  const posts = await Post.create(postsPayload);

  for (const group of groups) {
    const groupPosts = posts.filter((post) => String(post.group || '') === String(group._id));
    const pinned = groupPosts.filter((post) => post.pinnedInGroup).map(idOf);
    group.discussionIds = groupPosts.map(idOf);
    group.pinnedDiscussionIds = pinned.slice(0, 2);
    await group.save();
  }

  const commentTexts = [
    '这个流程很适合放到论文测试章节，状态变化很清楚。',
    '报名和通知联动比原来在群里统计方便太多了。',
    '建议再补一张活动详情截图，能把图片上传效果展示出来。',
    '我已经报名，现场签到时可以一起测重复提交。',
    '这个话题可以沉淀到社群里，后面复盘好找。',
    '如果加上浏览记录，用户回到之前看过的活动会更顺。',
  ];
  const comments = [];
  posts.forEach((post, postIndex) => {
    for (let offset = 1; offset <= 4; offset += 1) {
      const author = users[(postIndex + offset * 5) % users.length];
      if (String(author._id) === String(post.author)) continue;
      comments.push({
        kind: 'post',
        post: post._id,
        author: author._id,
        text: pick(commentTexts, postIndex + offset),
        likes: (postIndex + offset) % 9,
      });
    }
  });
  activities.forEach((activity, activityIndex) => {
    for (let offset = 1; offset <= 5; offset += 1) {
      const author = users[(activityIndex + offset * 4) % users.length];
      comments.push({
        kind: 'activity',
        activity: activity._id,
        author: author._id,
        text: pick([
          '这个活动的签到口令会提前通知吗？',
          '已报名，想看看现场报名名单统计效果。',
          '封面图很好看，适合放在论文页面运行效果里。',
          '活动结束后可以在社群里发复盘帖吗？',
          '希望提醒功能能准时推送，避免错过签到时间。',
        ], activityIndex + offset),
        likes: (activityIndex + offset) % 7,
      });
    }
  });
  await Comment.insertMany(comments);

  const likes = [];
  const favorites = [];
  const likeKeys = new Set();
  const favoriteKeys = new Set();
  posts.forEach((post, postIndex) => {
    for (let offset = 1; offset <= 14; offset += 1) {
      const user = users[(postIndex * 2 + offset) % users.length];
      if (String(user._id) === String(post.author)) continue;
      const key = `${post._id}:${user._id}`;
      if (!likeKeys.has(key)) {
        likeKeys.add(key);
        likes.push({ post: post._id, user: user._id });
      }
      if (offset % 4 === 0 && !favoriteKeys.has(key)) {
        favoriteKeys.add(key);
        favorites.push({ kind: 'post', post: post._id, user: user._id });
      }
    }
  });
  activities.forEach((activity, activityIndex) => {
    for (let offset = 1; offset <= 7; offset += 1) {
      const user = users[(activityIndex * 3 + offset) % users.length];
      const key = `${activity._id}:${user._id}`;
      if (!favoriteKeys.has(key)) {
        favoriteKeys.add(key);
        favorites.push({ kind: 'activity', activity: activity._id, user: user._id });
      }
    }
  });
  await Like.insertMany(likes, { ordered: false });
  await Favorite.insertMany(favorites, { ordered: false });

  const enrollments = [];
  activities.forEach((activity, activityIndex) => {
    const total = 18 + (activityIndex % 9) * 4;
    for (let offset = 0; offset < total; offset += 1) {
      const user = users[(activityIndex * 5 + offset) % users.length];
      enrollments.push({
        activity: activity._id,
        user: user._id,
        status: offset % 19 === 0 ? 'cancelled' : 'registered',
      });
    }
  });
  await Enrollment.insertMany(enrollments, { ordered: false }).catch((error) => {
    if (error?.code !== 11000) throw error;
  });

  const activeEnrollments = await Enrollment.find({ status: 'registered' });
  const checkIns = activeEnrollments
    .filter((_, index) => index % 3 !== 0)
    .map((enrollment, index) => ({
      activity: enrollment.activity,
      user: enrollment.user,
      enrollment: enrollment._id,
      code: 'campus2026',
      method: 'code',
      status: 'checked_in',
    }));
  await CheckIn.insertMany(checkIns, { ordered: false }).catch((error) => {
    if (error?.code !== 11000) throw error;
  });

  for (const activity of activities) {
    activity.enrolled = await Enrollment.countDocuments({
      activity: activity._id,
      status: 'registered',
    });
    await activity.save();
  }

  for (const post of posts) {
    post.likes = await Like.countDocuments({ post: post._id });
    post.comments = await Comment.countDocuments({ post: post._id });
    post.saves = await Favorite.countDocuments({ post: post._id });
    await post.save();
  }

  const follows = [];
  const followKeys = new Set();
  users.forEach((user, index) => {
    for (let offset = 1; offset <= 8; offset += 1) {
      const target = users[(index + offset * 3) % users.length];
      if (String(user._id) === String(target._id)) continue;
      const key = `${user._id}:${target._id}`;
      if (!followKeys.has(key)) {
        followKeys.add(key);
        follows.push({ follower: user._id, following: target._id });
      }
    }
  });
  await Follow.insertMany(follows, { ordered: false });

  for (const user of users) {
    user.followers = await Follow.countDocuments({ following: user._id });
    user.following = await Follow.countDocuments({ follower: user._id });
    await user.save();
  }

  for (const topicDoc of topicDocs) {
    const relatedPosts = posts.filter((post) => post.topic === topicDoc.name);
    topicDoc.postIds = relatedPosts.map(idOf);
    topicDoc.contributorIds = [
      ...new Set(relatedPosts.map((post) => String(post.author))),
    ].slice(0, 12);
    topicDoc.discussions = `${relatedPosts.length + topicDoc.onlineCount}条讨论`;
    await topicDoc.save();
  }

  const notifications = [];
  posts.slice(0, 40).forEach((post, index) => {
    const actor = users[(index + 3) % users.length];
    notifications.push({
      recipient: post.author,
      actor: actor._id,
      post: post._id,
      category: 'interaction',
      title: index % 2 === 0 ? '帖子收到点赞' : '帖子有新评论',
      firstLine: `${actor.name} ${index % 2 === 0 ? '赞了' : '评论了'}你的帖子「${post.title}」`,
      secondLine: index % 2 === 0 ? '校园动态正在被更多同学看到' : pick(commentTexts, index),
      action: index % 2 === 0 ? 'post_liked' : 'post_commented',
      unread: index % 3 !== 0,
    });
  });
  activities.slice(0, 18).forEach((activity, index) => {
    const recipient = users[(index + 6) % users.length];
    notifications.push({
      recipient: recipient._id,
      actor: activity.createdBy,
      activity: activity._id,
      category: 'notice',
      title: index % 2 === 0 ? '报名成功' : '活动提醒',
      firstLine: index % 2 === 0
        ? `你已成功报名「${activity.title}」`
        : `「${activity.title}」将在 ${activity.date} 开始`,
      secondLine: `${activity.date} ${activity.time} · ${activity.location}`,
      action: index % 2 === 0 ? 'activity_registered' : 'activity_reminder',
      unread: true,
    });
  });
  groups.forEach((group, index) => {
    notifications.push({
      recipient: users[(index + 9) % users.length]._id,
      actor: group.announcementUpdatedBy,
      group: group._id,
      category: 'notice',
      title: '社群公告更新',
      firstLine: `「${group.name}」发布了新公告`,
      secondLine: group.announcementText,
      action: 'group_announcement_updated',
      unread: index % 2 === 0,
    });
  });
  await Notification.insertMany(notifications);

  const allLocalUsers = await User.find({}).sort({ createdAt: 1 });
  for (let index = 0; index < allLocalUsers.length; index += 1) {
    allLocalUsers[index].avatarUrl = avatarForName(
      allLocalUsers[index].name,
      index
    );
    await allLocalUsers[index].save();
  }
  const seedActors = users.length > 0 ? users : allLocalUsers;
  const messageCenterNotifications = [];

  allLocalUsers.forEach((recipient, recipientIndex) => {
    for (let offset = 0; offset < 6; offset += 1) {
      const actor = seedActors[(recipientIndex + offset + 2) % seedActors.length];
      const post = posts[(recipientIndex * 3 + offset) % posts.length];
      if (!actor || !post || String(actor._id) === String(recipient._id)) continue;
      messageCenterNotifications.push({
        recipient: recipient._id,
        actor: actor._id,
        post: post._id,
        category: 'interaction',
        title: pick(['帖子收到点赞', '帖子有新评论', '新粉丝提醒'], offset),
        firstLine: pick([
          `${actor.name} 赞了你的帖子「${post.title}」`,
          `${actor.name} 评论了你的帖子「${post.title}」`,
          `${actor.name} 关注了你，想继续交流校园活动经验`,
        ], offset),
        secondLine: pick([
          '这条动态正在被更多同学看到',
          '建议把这段体验补充到活动复盘里',
          '可以从个人主页进入私信沟通',
        ], recipientIndex + offset),
        action: pick(['message_center_seed_post_liked', 'message_center_seed_post_commented', 'message_center_seed_followed'], offset),
        unread: offset < 4,
      });
    }

    for (let offset = 0; offset < 5; offset += 1) {
      const actor = seedActors[(recipientIndex + offset + 8) % seedActors.length];
      const activity = activities[(recipientIndex * 2 + offset) % activities.length];
      const group = groups[(recipientIndex + offset) % groups.length];
      if (!activity || !group) continue;
      messageCenterNotifications.push({
        recipient: recipient._id,
        actor: actor?._id,
        activity: offset % 2 === 0 ? activity._id : undefined,
        group: offset % 2 === 1 ? group._id : undefined,
        category: 'notice',
        title: pick(['报名成功', '签到提醒', '社群公告更新', '活动变更', '入群申请已通过'], offset),
        firstLine: pick([
          `你已成功报名「${activity.title}」`,
          `「${activity.title}」签到将在活动开始后开放`,
          `「${group.name}」发布了新的活动组织公告`,
          `「${activity.title}」时间地点信息已更新`,
          `你已加入「${group.name}」`,
        ], offset),
        secondLine: pick([
          `${activity.date} ${activity.time} · ${activity.location}`,
          `现场口令：${activity.checkInCode}`,
          group.announcementText,
          '请重新查看活动详情，避免错过现场安排',
          '现在可以参与社群讨论和活动报名了',
        ], offset),
        action: pick([
          'message_center_seed_activity_registered',
          'message_center_seed_activity_checkin',
          'message_center_seed_group_announcement',
          'message_center_seed_activity_updated',
          'message_center_seed_group_join_approved',
        ], offset),
        unread: offset < 3,
      });
    }
  });
  await Notification.insertMany(messageCenterNotifications);

  const conversations = [];
  const conversationPairs = new Set();
  for (let index = 0; index < 22; index += 1) {
    const a = users[index % users.length];
    const b = users[(index * 4 + 7) % users.length];
    if (String(a._id) === String(b._id)) continue;
    const pairKey = [String(a._id), String(b._id)].sort().join(':');
    if (conversationPairs.has(pairKey)) continue;
    conversationPairs.add(pairKey);
    conversations.push({
      participants: [a._id, b._id],
      lastMessage: pick([
        '明天活动现场我负责签到台。',
        '这张截图可以放进论文运行效果里。',
        '报名名单我看到了，人数够了。',
        '社群公告已经更新，记得看一下。',
      ], index),
    });
  }

  allLocalUsers.forEach((user, userIndex) => {
    for (let offset = 0; offset < 4; offset += 1) {
      const target = seedActors[(userIndex * 5 + offset + 3) % seedActors.length];
      if (!target || String(user._id) === String(target._id)) continue;
      const pairKey = [String(user._id), String(target._id)].sort().join(':');
      if (conversationPairs.has(pairKey)) continue;
      conversationPairs.add(pairKey);
      conversations.push({
        participants: [user._id, target._id],
        lastMessage: pick([
          '活动报名已经确认，记得看通知。',
          '这张页面截图很适合放到论文里。',
          '我把签到口令和现场流程发你了。',
          '社群公告更新了，晚点一起看一下。',
        ], userIndex + offset),
      });
    }
  });
  const conversationDocs = await Conversation.create(conversations);
  const messages = [];
  conversationDocs.forEach((conversation, index) => {
    const [a, b] = conversation.participants;
    for (let offset = 0; offset < 5; offset += 1) {
      const sender = offset % 2 === 0 ? a : b;
      messages.push({
        conversation: conversation._id,
        sender,
        text: pick([
          '这个活动的签到口令确认了吗？',
          '确认了，现场会在签到台展示。',
          '我把活动封面图也补上了。',
          '很好，首页信息流看起来更真实。',
          '后面再补一组测试截图就完整了。',
        ], index + offset),
        readBy: offset < 3 ? [a, b] : [sender],
      });
    }
  });
  await Message.insertMany(messages);

  const histories = [];
  users.slice(0, 32).forEach((user, userIndex) => {
    for (let offset = 0; offset < 8; offset += 1) {
      const kindIndex = (userIndex + offset) % 4;
      if (kindIndex === 0) {
        const post = posts[(userIndex + offset) % posts.length];
        histories.push({
          user: user._id,
          kind: 'post',
          refId: post._id,
          title: post.title,
          subtitle: `${post.topic} · ${post.likes}赞`,
          imageUrl: post.images[0] || '',
        });
      } else if (kindIndex === 1) {
        const activity = activities[(userIndex + offset) % activities.length];
        histories.push({
          user: user._id,
          kind: 'activity',
          refId: activity._id,
          title: activity.title,
          subtitle: `${activity.date} · ${activity.location}`,
          imageUrl: activity.posterUrl,
        });
      } else if (kindIndex === 2) {
        const group = groups[(userIndex + offset) % groups.length];
        histories.push({
          user: user._id,
          kind: 'group',
          refId: group._id,
          title: group.name,
          subtitle: `${group.members}人 · ${group.tags.join(' / ')}`,
          imageUrl: group.coverUrl,
        });
      } else {
        const topic = topicDocs[(userIndex + offset) % topicDocs.length];
        histories.push({
          user: user._id,
          kind: 'topic',
          refId: topic._id,
          title: topic.name,
          subtitle: topic.discussions,
          imageUrl: topic.coverUrl,
        });
      }
    }
  });
  await BrowsingHistory.insertMany(histories);

  const drafts = users.slice(0, 18).flatMap((user, index) => ([
    {
      user: user._id,
      kind: 'post',
      title: `关于${pick(topics, index).name}的体验补充`,
      body: '准备再补几张页面截图和一段活动现场反馈。',
      topic: pick(topics, index).name,
      location: pick(['图书馆', '实验楼', '大学生活动中心'], index),
      images: [pick(image.posts, index)],
      status: 'draft',
    },
    {
      user: user._id,
      kind: 'activity',
      title: `${pick(groupSeeds, index)[0]}下周活动策划`,
      body: '待确认场地、名额、签到口令和通知文案。',
      topic: '活动策划',
      location: pick(['线上活动', '创新创业中心', '学生事务中心'], index),
      images: [pick(image.activities, index)],
      status: index % 3 === 0 ? 'pending' : 'draft',
    },
  ]));
  await Draft.insertMany(drafts);

  const counts = {
    users: await User.countDocuments(),
    generatedUsers: await User.countDocuments({ username: { $regex: `^${USER_PREFIX}` } }),
    posts: await Post.countDocuments(),
    activities: await Activity.countDocuments(),
    groups: await Group.countDocuments(),
    topics: await Topic.countDocuments(),
    comments: await Comment.countDocuments(),
    likes: await Like.countDocuments(),
    favorites: await Favorite.countDocuments(),
    enrollments: await Enrollment.countDocuments(),
    checkins: await CheckIn.countDocuments(),
    memberships: await GroupMembership.countDocuments(),
    follows: await Follow.countDocuments(),
    notifications: await Notification.countDocuments(),
    conversations: await Conversation.countDocuments(),
    messages: await Message.countDocuments(),
    histories: await BrowsingHistory.countDocuments(),
    drafts: await Draft.countDocuments(),
  };

  console.table(counts);
  console.log(`Generated login examples: ${USER_PREFIX}001 / ${PASSWORD}, ${USER_PREFIX}010 / ${PASSWORD}`);
  await mongoose.disconnect();
}

main().catch(async (error) => {
  console.error(error);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
