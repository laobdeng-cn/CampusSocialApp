const users = [
  {
    id: 'u_xiaobei',
    name: '林小北',
    school: '计算机学院',
    major: '软件工程',
    grade: '大二',
    avatarUrl: 'https://i.pravatar.cc/180?img=12',
    bio: '热爱生活，热爱编程，期待遇见更多有趣的人。',
  },
  {
    id: 'u_kexin',
    name: '陈可欣',
    school: '设计学院',
    major: '视觉传达',
    grade: '大一',
    avatarUrl: 'https://i.pravatar.cc/180?img=47',
    bio: '摄影协会成员，喜欢记录校园里的光。',
    role: '会长',
  },
  {
    id: 'u_zihao',
    name: '王子豪',
    school: '新闻学院',
    major: '新媒体',
    grade: '大三',
    avatarUrl: 'https://i.pravatar.cc/180?img=11',
    bio: '校园摄影达人，常在操场追夕阳。',
  },
  {
    id: 'u_siyu',
    name: '刘思雨',
    school: '经济学院',
    major: '金融学',
    grade: '大一',
    avatarUrl: 'https://i.pravatar.cc/180?img=32',
    bio: '学习搭子募集，咖啡续命中。',
  },
  {
    id: 'u_xiaochen',
    name: '张晓晨',
    school: '音乐学院',
    major: '声乐',
    grade: '大二',
    avatarUrl: 'https://i.pravatar.cc/180?img=59',
    bio: '乐队主唱，校园舞台常驻。',
  },
];

const activities = [
  {
    id: 'a_music_night',
    title: '校园音乐之夜',
    category: '文艺演出',
    posterUrl: 'asset:assets/images/activity_music_thumb.png',
    date: '6月15日（周六）',
    time: '19:00 - 21:30',
    location: '大学生活动中心 · 多功能厅',
    host: '校学生会文艺部',
    enrolled: 356,
    capacity: 500,
    price: '免费',
    description:
      '用音乐点亮校园之夜！来自校内外的乐队、歌手将带来精彩演出，一起享受音乐的魅力。',
    highlights: ['多元音乐风格', '校内外嘉宾', '互动有好礼'],
    guestIds: ['u_xiaochen', 'u_xiaobei', 'u_kexin'],
    tags: ['文艺演出', '音乐', '校园文化'],
  },
  {
    id: 'a_ai_talk',
    title: 'AI 未来发展趋势讲座',
    category: '科技讲座',
    posterUrl: 'asset:assets/images/activity_ai_thumb.png',
    date: '5月28日（周三）',
    time: '19:00',
    location: '图书馆报告厅',
    host: '计算机学院科协',
    enrolled: 188,
    capacity: 260,
    price: '免费',
    description: '从大模型应用、AI 产品设计到校园创新实践，聊聊普通同学能抓住的机会。',
    highlights: ['案例拆解', '问答交流', '资料包'],
    guestIds: ['u_xiaobei', 'u_siyu'],
    tags: ['AI', '科技讲座'],
  },
  {
    id: 'a_basketball',
    title: '校园篮球友谊赛',
    category: '体育',
    posterUrl: 'asset:assets/images/activity_basketball_thumb.png',
    date: '5月30日（周四）',
    time: '16:30',
    location: '西区篮球场',
    host: '体育部',
    enrolled: 112,
    capacity: 160,
    price: '免费',
    description: '轻松友谊赛，欢迎组队报名，也可以来现场为同学加油。',
    highlights: ['自由组队', '现场补位', '奖品鼓励'],
    guestIds: ['u_zihao', 'u_xiaochen'],
    tags: ['篮球', '体育'],
  },
  {
    id: 'a_photo_walk',
    title: '摄影社团采风活动',
    category: '社团活动',
    posterUrl: 'asset:assets/images/activity_photo_thumb.png',
    date: '6月1日（周六）',
    time: '09:00',
    location: '东湖公园',
    host: '摄影协会',
    enrolled: 78,
    capacity: 120,
    price: '免费',
    description: '跟着摄影协会一起寻找校园里的新鲜角度，适合零基础同学参加。',
    highlights: ['实拍教学', '作品点评', '结识同好'],
    guestIds: ['u_kexin', 'u_zihao'],
    tags: ['摄影', '社团活动'],
  },
];

const posts = [
  {
    id: 'p_sunset',
    authorId: 'u_kexin',
    title: '校园日落拍摄地推荐',
    body: '今天的晚霞也太美了！在图书馆顶楼拍到的，分享给大家几个适合拍照的小位置。',
    topic: '摄影作品分享',
    images: [
      'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=900&q=80',
    ],
    location: '校园阳台',
    createdAt: '2小时前',
    likes: 128,
    comments: 23,
    saves: 31,
    shares: 9,
  },
  {
    id: 'p_library',
    authorId: 'u_xiaobei',
    title: '新图书馆自习位怎么预约？求攻略！',
    body: '最近想去新图书馆学习，但听说需要预约，有没有同学知道具体流程呀？',
    topic: '期末复习攻略',
    images: [
      'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1498243691581-b145c3f54a5a?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1516979187457-637abb4f9353?auto=format&fit=crop&w=900&q=80',
    ],
    location: '西区图书馆',
    createdAt: '05-20 14:32',
    likes: 86,
    comments: 63,
    saves: 42,
    shares: 12,
  },
  {
    id: 'p_review_plan',
    authorId: 'u_kexin',
    title: '高效复习时间表分享，亲测有效！',
    body: '根据课程难度和自身情况制定了这份时间表，实测有效。大家可以根据自己的节奏调整。',
    topic: '时间规划',
    images: [
      'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80',
    ],
    location: '自习室',
    createdAt: '今天 10:20',
    likes: 128,
    comments: 86,
    saves: 53,
    shares: 18,
    isPinned: true,
  },
  {
    id: 'p_materials',
    authorId: 'u_xiaobei',
    title: '各科目复习资料大合集（持续更新）',
    body: '整理了一些我用过的网课、书籍和题库资源，希望对大家有帮助。',
    topic: '资料分享',
    images: [
      'https://images.unsplash.com/photo-1516979187457-637abb4f9353?auto=format&fit=crop&w=900&q=80',
    ],
    location: '线上',
    createdAt: '昨天 21:00',
    likes: 102,
    comments: 63,
    saves: 80,
    shares: 21,
  },
];

const groups = [
  {
    id: 'g_programming',
    name: '编程学习小组',
    description: '一起学习编程知识，分享学习资源，交流项目经验，共同成长。',
    coverUrl:
      'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80',
    iconUrl:
      'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=500&q=80',
    members: 278,
    admins: 13,
    tags: ['编程学习', '技术交流', '项目实战', '互帮互助'],
    activityIds: ['a_ai_talk', 'a_music_night'],
    discussionIds: ['p_library', 'p_materials', 'p_review_plan'],
  },
];

const topics = [
  {
    id: 't_exam_review',
    name: '期末复习攻略',
    coverUrl:
      'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=1200&q=80',
    description: '分享复习方法、资料和经验，互相帮助，一起上岸。',
    discussions: '3.2万',
    onlineCount: 256,
    postIds: ['p_review_plan', 'p_materials', 'p_library'],
    contributorIds: ['u_xiaobei', 'u_kexin', 'u_zihao', 'u_siyu', 'u_xiaochen'],
    relatedTopics: ['数学复习方法', '专业课重点整理', '英语提分技巧', '考前心态调整'],
  },
  {
    id: 't_photo_share',
    name: '摄影作品分享',
    coverUrl:
      'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=1200&q=80',
    description: '分享校园光影、拍摄机位和后期心得。',
    discussions: '1.8万',
    onlineCount: 98,
    postIds: ['p_sunset'],
    contributorIds: ['u_kexin', 'u_zihao'],
    relatedTopics: ['摄影社团招新', '日落机位', '校园建筑'],
  },
];

function byId(collection, id) {
  return collection.find((item) => item.id === id);
}

function hydratePost(post) {
  return {
    ...post,
    author: byId(users, post.authorId),
  };
}

const hydratedPosts = posts.map(hydratePost);

function hydrateActivity(activity) {
  return {
    ...activity,
    guests: activity.guestIds.map((id) => byId(users, id)).filter(Boolean),
  };
}

const hydratedActivities = activities.map(hydrateActivity);

function hydrateGroup(group) {
  return {
    ...group,
    activities: group.activityIds.map((id) => byId(hydratedActivities, id)).filter(Boolean),
    discussions: group.discussionIds.map((id) => byId(hydratedPosts, id)).filter(Boolean),
  };
}

function hydrateTopic(topic) {
  return {
    ...topic,
    posts: topic.postIds.map((id) => byId(hydratedPosts, id)).filter(Boolean),
    contributors: topic.contributorIds.map((id) => byId(users, id)).filter(Boolean),
  };
}

module.exports = {
  users,
  activities: hydratedActivities,
  posts: hydratedPosts,
  groups: groups.map(hydrateGroup),
  topics: topics.map(hydrateTopic),
};
