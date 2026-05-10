import '../models/campus_feed.dart';
import '../models/campus_models.dart';

// Production fallback data is intentionally empty.
// The app should render real records returned by the backend, or an empty state
// when the backend has no records / is unavailable.
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
