import 'package:shared_preferences/shared_preferences.dart';

import '../models/campus_models.dart';

class AuthSession {
  const AuthSession._();

  static const _tokenKey = 'campus_auth_token';
  static const _userIdKey = 'campus_auth_user_id';
  static const _userNameKey = 'campus_auth_user_name';
  static const _userSchoolKey = 'campus_auth_user_school';
  static const _userMajorKey = 'campus_auth_user_major';
  static const _userGradeKey = 'campus_auth_user_grade';
  static const _userAvatarKey = 'campus_auth_user_avatar_url';
  static const _userBioKey = 'campus_auth_user_bio';
  static const _userRoleKey = 'campus_auth_user_role';
  static const _userFollowersKey = 'campus_auth_user_followers';
  static const _userFollowingKey = 'campus_auth_user_following';

  static String? token;
  static CampusUser? user;

  static bool get isLoggedIn => token?.isNotEmpty == true;

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    if (storedToken?.isNotEmpty != true) {
      token = null;
      user = null;
      return;
    }

    token = storedToken;
    user = CampusUser(
      id: prefs.getString(_userIdKey) ?? '',
      name: prefs.getString(_userNameKey) ?? '校园同学',
      school: prefs.getString(_userSchoolKey) ?? '未知学院',
      major: prefs.getString(_userMajorKey) ?? '未填写专业',
      grade: prefs.getString(_userGradeKey) ?? '未填写年级',
      avatarUrl:
          prefs.getString(_userAvatarKey) ?? 'https://i.pravatar.cc/180?img=1',
      bio: prefs.getString(_userBioKey) ?? '',
      role: prefs.getString(_userRoleKey),
      followers: prefs.getInt(_userFollowersKey) ?? 0,
      following: prefs.getInt(_userFollowingKey) ?? 0,
    );
  }

  static void set(String nextToken, CampusUser nextUser) {
    token = nextToken;
    user = nextUser;
    _persist(nextToken, nextUser);
  }

  static void updateUser(CampusUser nextUser) {
    user = nextUser;
    final currentToken = token;
    if (currentToken?.isNotEmpty == true) {
      _persist(currentToken!, nextUser);
    }
  }

  static void clear() {
    token = null;
    user = null;
    _clearStorage();
  }

  static Future<void> _persist(String nextToken, CampusUser nextUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, nextToken);
    await prefs.setString(_userIdKey, nextUser.id);
    await prefs.setString(_userNameKey, nextUser.name);
    await prefs.setString(_userSchoolKey, nextUser.school);
    await prefs.setString(_userMajorKey, nextUser.major);
    await prefs.setString(_userGradeKey, nextUser.grade);
    await prefs.setString(_userAvatarKey, nextUser.avatarUrl);
    await prefs.setString(_userBioKey, nextUser.bio);
    if (nextUser.role?.isNotEmpty == true) {
      await prefs.setString(_userRoleKey, nextUser.role!);
    } else {
      await prefs.remove(_userRoleKey);
    }
    await prefs.setInt(_userFollowersKey, nextUser.followers);
    await prefs.setInt(_userFollowingKey, nextUser.following);
  }

  static Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userSchoolKey);
    await prefs.remove(_userMajorKey);
    await prefs.remove(_userGradeKey);
    await prefs.remove(_userAvatarKey);
    await prefs.remove(_userBioKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userFollowersKey);
    await prefs.remove(_userFollowingKey);
  }
}
