import '../models/campus_models.dart';

class AuthSession {
  const AuthSession._();

  static String? token;
  static CampusUser? user;

  static bool get isLoggedIn => token?.isNotEmpty == true;

  static void set(String nextToken, CampusUser nextUser) {
    token = nextToken;
    user = nextUser;
  }

  static void updateUser(CampusUser nextUser) {
    user = nextUser;
  }

  static void clear() {
    token = null;
    user = null;
  }
}
