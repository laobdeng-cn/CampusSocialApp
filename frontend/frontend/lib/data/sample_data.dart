import '../models/campus_models.dart';
import '../models/campus_feed.dart';

const xiaobei = CampusUser(
  name: '林小北',
  school: '计算机学院',
  major: '软件工程',
  grade: '大二',
  avatarUrl: 'asset:assets/images/avatar_xiaobei.jpg',
  bio: '热爱生活，热爱编程，期待遇见更多有趣的人。',
);

const kexin = CampusUser(
  name: '陈可欣',
  school: '设计学院',
  major: '视觉传达',
  grade: '大一',
  avatarUrl: 'asset:assets/images/kexin_avatar.png',
  bio: '摄影协会成员，喜欢记录校园里的光。',
  role: '会长',
);

const zihao = CampusUser(
  name: '王子豪',
  school: '新闻学院',
  major: '新媒体',
  grade: '大三',
  avatarUrl: 'asset:assets/images/avatar_zihao.jpg',
  bio: '校园摄影达人，常在操场追夕阳。',
);

const siyu = CampusUser(
  name: '刘思雨',
  school: '经济学院',
  major: '金融学',
  grade: '大一',
  avatarUrl: 'asset:assets/images/avatar_siyu.jpg',
  bio: '学习搭子募集，咖啡续命中。',
);

const xiaochen = CampusUser(
  name: '张晓晨',
  school: '音乐学院',
  major: '声乐',
  grade: '大二',
  avatarUrl: 'asset:assets/images/avatar_xiaochen.jpg',
  bio: '乐队主唱，校园舞台常驻。',
);

const campusUsers = [xiaobei, kexin, zihao, siyu, xiaochen];

const campusActivity = CampusActivity(
  id: 'campus_music_night',
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
  description: '用音乐点亮校园之夜！来自校内外的乐队、歌手将带来精彩演出，一起享受音乐的魅力，释放青春的热情。',
  highlights: ['多元音乐风格', '校内外嘉宾', '互动有好礼'],
  guests: [xiaochen, xiaobei, kexin],
);

const volunteerActivity = CampusActivity(
  id: 'photo_club_walk',
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
  guests: [kexin, zihao],
);

const aiTalkActivity = CampusActivity(
  id: 'ai_future_talk',
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
  guests: [xiaobei, siyu],
);

const basketballActivity = CampusActivity(
  id: 'campus_basketball_match',
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
  guests: [zihao, xiaochen],
);

const campusActivities = [
  campusActivity,
  aiTalkActivity,
  basketballActivity,
  volunteerActivity,
];

const libraryPost = CampusPost(
  author: xiaobei,
  title: '新图书馆自习位怎么预约？求攻略！',
  body: '最近想去新图书馆学习，但听说需要预约，有没有同学知道具体流程呀？入口在哪里，每天几点可以预约，热门区域会不会很快被抢完？',
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
);

const sunsetPost = CampusPost(
  author: kexin,
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
);

const reviewPost = CampusPost(
  author: kexin,
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
);

const materialPost = CampusPost(
  author: xiaobei,
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
);

const campusPosts = [sunsetPost, libraryPost, reviewPost, materialPost];

const programmingGroup = CampusGroup(
  name: '编程学习小组',
  coverUrl:
      'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80',
  iconUrl:
      'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=500&q=80',
  description: '在这里一起学习编程知识，分享学习资源，交流项目经验，共同成长。',
  members: 278,
  admins: 13,
  tags: ['编程学习', '技术交流', '项目实战', '互帮互助'],
  activities: [aiTalkActivity],
  discussions: [libraryPost, materialPost, reviewPost],
);

const campusTopic = CampusTopic(
  name: '期末复习攻略',
  coverUrl:
      'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=1200&q=80',
  description: '期末将至，如何高效复习、合理规划时间、稳住心态拿高分？分享你的方法和经验，一起上岸。',
  discussions: '3.2万',
  onlineCount: 256,
  posts: [reviewPost, materialPost, libraryPost],
  contributors: [xiaobei, kexin, zihao, siyu, xiaochen],
  relatedTopics: ['数学复习方法', '专业课重点整理', '英语提分技巧', '考前心态调整'],
);

const hotTopics = ['期末复习攻略', '我的校园日常', '考研经验分享', '校园美食打卡'];

const recentSearches = ['摄影 社团', '志愿者', '篮球赛', '校园音乐节', 'AI 讲座'];

const fallbackFeed = CampusFeed(
  users: campusUsers,
  posts: campusPosts,
  activities: campusActivities,
  groups: [programmingGroup],
  topics: [campusTopic],
);
