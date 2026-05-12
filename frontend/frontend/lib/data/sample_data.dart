import '../models/campus_feed.dart';
import '../models/campus_models.dart';

// Production fallback data is intentionally empty.
// The app should render real records returned by the backend, or an empty state
// when the backend has no records / is unavailable.
const CampusUser campusFallbackUser = CampusUser(
  name: '校园同学',
  school: '未填写学校',
  major: '未填写专业',
  grade: '未填写年级',
  avatarUrl: 'asset:assets/images/user_profile_cover.png',
  bio: '',
);

const xiaobei = campusFallbackUser;
const kexin = campusFallbackUser;
const zihao = campusFallbackUser;
const siyu = campusFallbackUser;
const xiaochen = campusFallbackUser;

const CampusPost sunsetPost = CampusPost(
  author: campusFallbackUser,
  title: '暂无帖子',
  body: '当前还没有真实帖子数据。',
  topic: '校园讨论',
  images: <String>[],
  location: '',
  createdAt: '刚刚',
  likes: 0,
  comments: 0,
  saves: 0,
  shares: 0,
);

const CampusTopic campusTopic = CampusTopic(
  name: '校园话题',
  coverUrl: '',
  description: '',
  discussions: '0',
  onlineCount: 0,
  posts: <CampusPost>[],
  contributors: <CampusUser>[],
  relatedTopics: <String>[],
);

const CampusGroup programmingGroup = CampusGroup(
  name: '暂无推荐群组',
  coverUrl: '',
  iconUrl: '',
  description: '',
  members: 0,
  admins: 0,
  tags: <String>[],
  activities: <CampusActivity>[],
  discussions: <CampusPost>[],
);

const List<CampusUser> campusUsers = <CampusUser>[];
const List<CampusPost> campusPosts = <CampusPost>[];
const List<CampusActivity> campusActivities = <CampusActivity>[];
const List<CampusGroup> campusGroups = <CampusGroup>[];
const List<CampusTopic> campusTopics = <CampusTopic>[];

const List<String> hotTopics = <String>[];
const List<String> recentSearches = <String>[];

const fallbackFeed = CampusFeed(
  users: campusUsers,
  posts: campusPosts,
  activities: campusActivities,
  groups: campusGroups,
  topics: campusTopics,
);
