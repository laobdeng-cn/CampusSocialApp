class CampusUser {
  const CampusUser({
    required this.name,
    required this.school,
    required this.major,
    required this.grade,
    required this.avatarUrl,
    required this.bio,
    this.id = '',
    this.role,
    this.followers = 0,
    this.following = 0,
    this.followedAt = '',
    this.followsMe = false,
    this.followedByMe = false,
  });

  final String id;
  final String name;
  final String school;
  final String major;
  final String grade;
  final String avatarUrl;
  final String bio;
  final String? role;
  final int followers;
  final int following;
  final String followedAt;
  final bool followsMe;
  final bool followedByMe;

  factory CampusUser.fromJson(Map<String, dynamic> json) {
    return CampusUser(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      name: _readString(json, 'name', fallback: '校园同学'),
      school: _readString(json, 'school', fallback: '未知学院'),
      major: _readString(json, 'major', fallback: '未填写专业'),
      grade: _readString(json, 'grade', fallback: '未填写年级'),
      avatarUrl: _readString(
        json,
        'avatarUrl',
        fallback: 'https://i.pravatar.cc/180?img=1',
      ),
      bio: _readString(json, 'bio'),
      role: _readNullableString(json, 'role'),
      followers: _readInt(json, 'followers'),
      following: _readInt(json, 'following'),
      followedAt: _readString(json, 'followedAt'),
      followsMe: json['followsMe'] == true,
      followedByMe: json['followedByMe'] == true,
    );
  }

  CampusUser copyWith({
    String? id,
    String? name,
    String? school,
    String? major,
    String? grade,
    String? avatarUrl,
    String? bio,
    String? role,
    int? followers,
    int? following,
    String? followedAt,
    bool? followsMe,
    bool? followedByMe,
  }) {
    return CampusUser(
      id: id ?? this.id,
      name: name ?? this.name,
      school: school ?? this.school,
      major: major ?? this.major,
      grade: grade ?? this.grade,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      followedAt: followedAt ?? this.followedAt,
      followsMe: followsMe ?? this.followsMe,
      followedByMe: followedByMe ?? this.followedByMe,
    );
  }
}

class CampusUserSettings {
  const CampusUserSettings({
    required this.messageReminder,
    required this.activityNotice,
    required this.systemNotice,
    required this.allowSearch,
    required this.blockStrangerComments,
    this.profileVisibility = 'friends',
    this.dmPermission = 'friends_and_following',
  });

  final bool messageReminder;
  final bool activityNotice;
  final bool systemNotice;
  final bool allowSearch;
  final bool blockStrangerComments;
  final String profileVisibility;
  final String dmPermission;

  factory CampusUserSettings.defaults() {
    return const CampusUserSettings(
      messageReminder: true,
      activityNotice: true,
      systemNotice: true,
      allowSearch: true,
      blockStrangerComments: true,
    );
  }

  factory CampusUserSettings.fromJson(Map<String, dynamic> json) {
    final notifications =
        _readMap(json, 'notifications') ?? const <String, dynamic>{};
    final privacy = _readMap(json, 'privacy') ?? const <String, dynamic>{};
    return CampusUserSettings(
      messageReminder: notifications['messageReminder'] != false,
      activityNotice: notifications['activityNotice'] != false,
      systemNotice: notifications['systemNotice'] != false,
      allowSearch: privacy['allowSearch'] != false,
      blockStrangerComments: privacy['blockStrangerComments'] != false,
      profileVisibility: _readString(
        privacy,
        'profileVisibility',
        fallback: 'friends',
      ),
      dmPermission: _readString(
        privacy,
        'dmPermission',
        fallback: 'friends_and_following',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications': {
        'messageReminder': messageReminder,
        'activityNotice': activityNotice,
        'systemNotice': systemNotice,
      },
      'privacy': {
        'allowSearch': allowSearch,
        'blockStrangerComments': blockStrangerComments,
        'profileVisibility': profileVisibility,
        'dmPermission': dmPermission,
      },
    };
  }

  CampusUserSettings copyWith({
    bool? messageReminder,
    bool? activityNotice,
    bool? systemNotice,
    bool? allowSearch,
    bool? blockStrangerComments,
    String? profileVisibility,
    String? dmPermission,
  }) {
    return CampusUserSettings(
      messageReminder: messageReminder ?? this.messageReminder,
      activityNotice: activityNotice ?? this.activityNotice,
      systemNotice: systemNotice ?? this.systemNotice,
      allowSearch: allowSearch ?? this.allowSearch,
      blockStrangerComments:
          blockStrangerComments ?? this.blockStrangerComments,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      dmPermission: dmPermission ?? this.dmPermission,
    );
  }
}

class CampusPost {
  const CampusPost({
    required this.author,
    required this.title,
    required this.body,
    required this.topic,
    required this.images,
    required this.location,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    this.id = '',
    this.groupId = '',
    this.isPinned = false,
    this.pinnedInGroup = false,
  });

  final String id;
  final String groupId;
  final CampusUser author;
  final String title;
  final String body;
  final String topic;
  final List<String> images;
  final String location;
  final String createdAt;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
  final bool isPinned;
  final bool pinnedInGroup;

  factory CampusPost.fromJson(Map<String, dynamic> json) {
    final authorJson = _readMap(json, 'author');

    return CampusPost(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      groupId: _readString(json, 'groupId'),
      author: authorJson == null
          ? const CampusUser(
              name: '校园同学',
              school: '未知学院',
              major: '未填写专业',
              grade: '未填写年级',
              avatarUrl: 'https://i.pravatar.cc/180?img=1',
              bio: '',
            )
          : CampusUser.fromJson(authorJson),
      title: _readString(json, 'title', fallback: '未命名帖子'),
      body: _readString(json, 'body'),
      topic: _readString(json, 'topic', fallback: '校园讨论'),
      images: _readStringList(json, 'images'),
      location: _readString(json, 'location'),
      createdAt: _readString(json, 'createdAt', fallback: '刚刚'),
      likes: _readInt(json, 'likes'),
      comments: _readInt(json, 'comments'),
      saves: _readInt(json, 'saves'),
      shares: _readInt(json, 'shares'),
      isPinned: json['isPinned'] == true,
      pinnedInGroup: json['pinnedInGroup'] == true,
    );
  }

  CampusPost copyWith({
    String? id,
    String? groupId,
    CampusUser? author,
    String? title,
    String? body,
    String? topic,
    List<String>? images,
    String? location,
    String? createdAt,
    int? likes,
    int? comments,
    int? saves,
    int? shares,
    bool? isPinned,
    bool? pinnedInGroup,
  }) {
    return CampusPost(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      author: author ?? this.author,
      title: title ?? this.title,
      body: body ?? this.body,
      topic: topic ?? this.topic,
      images: images ?? this.images,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      saves: saves ?? this.saves,
      shares: shares ?? this.shares,
      isPinned: isPinned ?? this.isPinned,
      pinnedInGroup: pinnedInGroup ?? this.pinnedInGroup,
    );
  }
}

class CampusComment {
  const CampusComment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.likes,
  });

  final String id;
  final CampusUser author;
  final String text;
  final String createdAt;
  final int likes;

  factory CampusComment.fromJson(Map<String, dynamic> json) {
    final authorJson = _readMap(json, 'author');
    return CampusComment(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      author: authorJson == null
          ? const CampusUser(
              name: '校园同学',
              school: '未知学院',
              major: '未填写专业',
              grade: '未填写年级',
              avatarUrl: 'https://i.pravatar.cc/180?img=1',
              bio: '',
            )
          : CampusUser.fromJson(authorJson),
      text: _readString(json, 'text'),
      createdAt: _readString(json, 'createdAt', fallback: '刚刚'),
      likes: _readInt(json, 'likes'),
    );
  }
}

class CampusMyCommentRecord {
  const CampusMyCommentRecord({
    required this.id,
    required this.text,
    required this.likes,
    required this.createdAt,
    required this.post,
  });

  final String id;
  final String text;
  final int likes;
  final String createdAt;
  final CampusPost post;

  factory CampusMyCommentRecord.fromJson(Map<String, dynamic> json) {
    final postJson = _readMap(json, 'post');
    return CampusMyCommentRecord(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      text: _readString(json, 'text'),
      likes: _readInt(json, 'likes'),
      createdAt: _readString(json, 'createdAt', fallback: '刚刚'),
      post: postJson == null
          ? CampusPost.fromJson(const {})
          : CampusPost.fromJson(postJson),
    );
  }
}

class CampusActivity {
  const CampusActivity({
    this.id = '',
    required this.title,
    required this.category,
    required this.posterUrl,
    this.images = const [],
    required this.date,
    required this.time,
    required this.location,
    required this.host,
    required this.enrolled,
    required this.capacity,
    required this.price,
    required this.description,
    required this.highlights,
    required this.guests,
    this.activityStatus = '',
    this.checkInStatus = '',
    this.statusText = '',
    this.countdownText = '',
    this.startAt = '',
    this.endAt = '',
    this.checkInStartAt = '',
    this.checkInEndAt = '',
    this.isFavorited = false,
  });

  final String id;
  final String title;
  final String category;
  final String posterUrl;
  final List<String> images;
  final String date;
  final String time;
  final String location;
  final String host;
  final int enrolled;
  final int capacity;
  final String price;
  final String description;
  final List<String> highlights;
  final List<CampusUser> guests;

  /// 后端活动状态机字段
  /// registered / checkin_available / checked_in / ended
  final String activityStatus;

  /// not_started / available / checked_in / ended
  final String checkInStatus;

  final String statusText;
  final String countdownText;
  final String startAt;
  final String endAt;
  final String checkInStartAt;
  final String checkInEndAt;
  final bool isFavorited;

  bool get isCheckInNotStarted => checkInStatus == 'not_started';
  bool get isCheckInAvailable =>
      checkInStatus == 'available' || activityStatus == 'checkin_available';
  bool get isCheckedIn =>
      checkInStatus == 'checked_in' || activityStatus == 'checked_in';
  bool get isEnded => checkInStatus == 'ended' || activityStatus == 'ended';

  factory CampusActivity.fromJson(Map<String, dynamic> json) {
    final highlights = _readStringList(json, 'highlights');
    final tags = _readStringList(json, 'tags');

    final activityImages = _readStringList(json, 'images');
    final posterFromJson = _readString(
      json,
      'posterUrl',
      fallback: activityImages.isNotEmpty
          ? activityImages.first
          : 'https://images.unsplash.com/photo-1523580494863-6f3031224c94?auto=format&fit=crop&w=900&q=80',
    );
    final mergedImages = <String>[
      if (posterFromJson.trim().isNotEmpty) posterFromJson,
      ...activityImages.where(
        (url) => url.trim().isNotEmpty && url != posterFromJson,
      ),
    ];

    return CampusActivity(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      title: _readString(json, 'title', fallback: '未命名活动'),
      category: _readString(json, 'category', fallback: '校园活动'),
      posterUrl: posterFromJson,
      images: mergedImages,
      date: _readString(json, 'date', fallback: '时间待定'),
      time: _readString(json, 'time', fallback: ''),
      location: _readString(json, 'location', fallback: '地点待定'),
      host: _readString(json, 'host', fallback: '校园组织'),
      enrolled: _readInt(json, 'enrolled'),
      capacity: _readInt(json, 'capacity', fallback: 100),
      price: _readString(json, 'price', fallback: '免费'),
      description: _readString(json, 'description'),
      highlights: highlights.isEmpty ? tags : highlights,
      guests: _readMapList(
        json,
        'guests',
      ).map(CampusUser.fromJson).toList(growable: false),
      activityStatus: _readString(json, 'activityStatus'),
      checkInStatus: _readString(json, 'checkInStatus'),
      statusText: _readString(json, 'statusText'),
      countdownText: _readString(json, 'countdownText'),
      startAt: _readString(json, 'startAt'),
      endAt: _readString(json, 'endAt'),
      checkInStartAt: _readString(json, 'checkInStartAt'),
      checkInEndAt: _readString(json, 'checkInEndAt'),
      isFavorited:
          json['isFavorited'] == true ||
          json['favorited'] == true ||
          json['favorite'] == true,
    );
  }

  CampusActivity copyWith({
    String? id,
    String? posterUrl,
    String? date,
    String? time,
    String? location,
    int? enrolled,
    List<String>? highlights,
    List<String>? images,
    List<CampusUser>? guests,
    String? activityStatus,
    String? checkInStatus,
    String? statusText,
    String? countdownText,
    String? startAt,
    String? endAt,
    String? checkInStartAt,
    String? checkInEndAt,
    bool? isFavorited,
  }) {
    return CampusActivity(
      id: id ?? this.id,
      title: title,
      category: category,
      posterUrl: posterUrl ?? this.posterUrl,
      images: images ?? this.images,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      host: host,
      enrolled: enrolled ?? this.enrolled,
      capacity: capacity,
      price: price,
      description: description,
      highlights: highlights ?? this.highlights,
      guests: guests ?? this.guests,
      activityStatus: activityStatus ?? this.activityStatus,
      checkInStatus: checkInStatus ?? this.checkInStatus,
      statusText: statusText ?? this.statusText,
      countdownText: countdownText ?? this.countdownText,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      checkInStartAt: checkInStartAt ?? this.checkInStartAt,
      checkInEndAt: checkInEndAt ?? this.checkInEndAt,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }
}

class CampusCheckInRecord {
  const CampusCheckInRecord({
    required this.id,
    required this.activity,
    required this.checkedAt,
    required this.status,
  });

  final String id;
  final CampusActivity activity;
  final String checkedAt;
  final String status;

  factory CampusCheckInRecord.fromJson(Map<String, dynamic> json) {
    final activityJson = json['activity'];
    return CampusCheckInRecord(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      activity: activityJson is Map<String, dynamic>
          ? CampusActivity.fromJson(activityJson)
          : activityJson is Map
          ? CampusActivity.fromJson(activityJson.cast<String, dynamic>())
          : CampusActivity.fromJson(const {}),
      checkedAt: _readString(json, 'createdAt', fallback: '刚刚'),
      status: _readString(json, 'status', fallback: 'checked_in'),
    );
  }
}

class CampusActivityEnrollment {
  const CampusActivityEnrollment({
    required this.id,
    required this.status,
    required this.createdAt,
    this.checkedIn = false,
    this.checkedAt = '',
    this.checkInStatus = '',
    required this.user,
  });

  final String id;
  final String status;
  final String createdAt;
  final bool checkedIn;
  final String checkedAt;
  final String checkInStatus;
  final CampusUser user;

  factory CampusActivityEnrollment.fromJson(Map<String, dynamic> json) {
    final userJson = _readMap(json, 'user');
    final status = _readString(json, 'status', fallback: 'registered');
    final checkInStatus = _readString(json, 'checkInStatus', fallback: status);
    final checkedIn =
        json['checkedIn'] == true ||
        status == 'checked_in' ||
        checkInStatus == 'checked_in';

    return CampusActivityEnrollment(
      id: _readString(json, 'id'),
      status: status,
      createdAt: _readString(json, 'createdAt'),
      checkedIn: checkedIn,
      checkedAt: _readString(json, 'checkedAt'),
      checkInStatus: checkInStatus,
      user: userJson == null
          ? CampusUser.fromJson(const {})
          : CampusUser.fromJson(userJson),
    );
  }
}

class CampusFavoriteRecord {
  const CampusFavoriteRecord({
    required this.id,
    required this.kind,
    required this.post,
    required this.activity,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final CampusPost post;
  final CampusActivity activity;
  final String createdAt;

  factory CampusFavoriteRecord.fromJson(Map<String, dynamic> json) {
    final postJson = _readMap(json, 'post');
    final activityJson = _readMap(json, 'activity');
    return CampusFavoriteRecord(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      kind: _readString(json, 'kind', fallback: 'post'),
      post: postJson == null
          ? CampusPost.fromJson(const {})
          : CampusPost.fromJson(postJson),
      activity: activityJson == null
          ? CampusActivity.fromJson(const {})
          : CampusActivity.fromJson(activityJson),
      createdAt: _readString(json, 'createdAt', fallback: '刚刚'),
    );
  }
}

class CampusHistoryRecord {
  const CampusHistoryRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.updatedAt,
  });

  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String updatedAt;

  factory CampusHistoryRecord.fromJson(Map<String, dynamic> json) {
    return CampusHistoryRecord(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      kind: _readString(json, 'kind', fallback: 'post'),
      title: _readString(json, 'title', fallback: '浏览记录'),
      subtitle: _readString(json, 'subtitle'),
      imageUrl: _readString(json, 'imageUrl'),
      updatedAt: _readString(
        json,
        'updatedAt',
        fallback: _readString(json, 'createdAt', fallback: '刚刚'),
      ),
    );
  }
}

class CampusDraft {
  const CampusDraft({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.topic,
    required this.location,
    required this.images,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String topic;
  final String location;
  final List<String> images;
  final String status;
  final String updatedAt;

  factory CampusDraft.fromJson(Map<String, dynamic> json) {
    return CampusDraft(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      kind: _readString(json, 'kind', fallback: 'post'),
      title: _readString(json, 'title', fallback: '未命名草稿'),
      body: _readString(json, 'body'),
      topic: _readString(json, 'topic', fallback: '校园生活'),
      location: _readString(json, 'location'),
      images: _readStringList(json, 'images'),
      status: _readString(json, 'status', fallback: 'draft'),
      updatedAt: _readString(
        json,
        'updatedAt',
        fallback: _readString(json, 'createdAt', fallback: '刚刚'),
      ),
    );
  }
}

class CampusLikeRecord {
  const CampusLikeRecord({
    required this.id,
    required this.user,
    required this.post,
    required this.actionText,
    required this.createdAt,
  });

  final String id;
  final CampusUser user;
  final CampusPost post;
  final String actionText;
  final String createdAt;

  factory CampusLikeRecord.fromJson(Map<String, dynamic> json) {
    final userJson = _readMap(json, 'user');
    final postJson = _readMap(json, 'post');
    return CampusLikeRecord(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      user: userJson == null
          ? const CampusUser(
              name: '校园同学',
              school: '未知学院',
              major: '未填写专业',
              grade: '未填写年级',
              avatarUrl: 'https://i.pravatar.cc/180?img=1',
              bio: '',
            )
          : CampusUser.fromJson(userJson),
      post: postJson == null
          ? CampusPost.fromJson(const {})
          : CampusPost.fromJson(postJson),
      actionText: _readString(json, 'actionText', fallback: '赞了你的帖子'),
      createdAt: _readString(json, 'createdAt', fallback: '刚刚'),
    );
  }
}

class CampusNotificationRecord {
  const CampusNotificationRecord({
    required this.id,
    required this.category,
    required this.title,
    required this.firstLine,
    required this.secondLine,
    required this.action,
    required this.createdAt,
    required this.unread,
    this.actor,
    this.post,
    this.activity,
    this.group,
  });

  final String id;
  final String category;
  final String title;
  final String firstLine;
  final String secondLine;
  final String action;
  final String createdAt;
  final bool unread;
  final CampusUser? actor;
  final CampusPost? post;
  final CampusActivity? activity;
  final CampusGroup? group;

  factory CampusNotificationRecord.fromJson(Map<String, dynamic> json) {
    final actorJson = _readMap(json, 'actor');
    final postJson = _readMap(json, 'post');
    final activityJson = _readMap(json, 'activity');
    final groupJson = _readMap(json, 'group');
    return CampusNotificationRecord(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      category: _readString(json, 'category', fallback: 'notice'),
      title: _readString(json, 'title', fallback: '通知'),
      firstLine: _readString(json, 'firstLine'),
      secondLine: _readString(json, 'secondLine'),
      action: _readString(json, 'action'),
      createdAt: _readString(json, 'createdAt', fallback: '刚刚'),
      unread: json['unread'] == true,
      actor: actorJson == null ? null : CampusUser.fromJson(actorJson),
      post: postJson == null ? null : CampusPost.fromJson(postJson),
      activity: activityJson == null
          ? null
          : CampusActivity.fromJson(activityJson),
      group: groupJson == null ? null : CampusGroup.fromJson(groupJson),
    );
  }
}

class CampusConversation {
  const CampusConversation({
    required this.id,
    required this.contact,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });

  final String id;
  final CampusUser contact;
  final String lastMessage;
  final int unreadCount;
  final String updatedAt;

  factory CampusConversation.fromJson(Map<String, dynamic> json) {
    final contactJson = _readMap(json, 'contact');
    return CampusConversation(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      contact: contactJson == null
          ? const CampusUser(
              name: '校园同学',
              school: '未知学院',
              major: '未填写专业',
              grade: '未填写年级',
              avatarUrl: 'https://i.pravatar.cc/180?img=1',
              bio: '',
            )
          : CampusUser.fromJson(contactJson),
      lastMessage: _readString(json, 'lastMessage'),
      unreadCount: _readInt(json, 'unreadCount'),
      updatedAt: _readString(json, 'updatedAt', fallback: '刚刚'),
    );
  }
}

class CampusChatMessage {
  const CampusChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final CampusUser sender;
  final String text;
  final String createdAt;
  final bool isMine;

  factory CampusChatMessage.fromJson(Map<String, dynamic> json) {
    final senderJson = _readMap(json, 'sender');
    return CampusChatMessage(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      sender: senderJson == null
          ? const CampusUser(
              name: '校园同学',
              school: '未知学院',
              major: '未填写专业',
              grade: '未填写年级',
              avatarUrl: 'https://i.pravatar.cc/180?img=1',
              bio: '',
            )
          : CampusUser.fromJson(senderJson),
      text: _readString(json, 'text'),
      createdAt: _readString(json, 'createdAt', fallback: '刚刚'),
      isMine: json['isMine'] == true,
    );
  }
}

class CampusGroup {
  const CampusGroup({
    this.id = '',
    required this.name,
    required this.coverUrl,
    required this.iconUrl,
    required this.description,
    required this.members,
    required this.admins,
    required this.tags,
    required this.activities,
    required this.discussions,
    this.announcementText = '',
    this.announcementUpdatedAt = '',
    this.announcementUpdatedBy,
    this.pinnedDiscussionIds = const [],
    this.visibility = 'approval',
    this.joined = false,
    this.membershipRole = '',
    this.membershipId = '',
    this.membershipStatus = '',
    this.canManage = false,
  });

  final String id;
  final String name;
  final String coverUrl;
  final String iconUrl;
  final String description;
  final int members;
  final int admins;
  final List<String> tags;
  final List<CampusActivity> activities;
  final List<CampusPost> discussions;
  final String announcementText;
  final String announcementUpdatedAt;
  final CampusUser? announcementUpdatedBy;
  final List<String> pinnedDiscussionIds;
  final String visibility;
  final bool joined;
  final String membershipRole;
  final String membershipId;
  final String membershipStatus;
  final bool canManage;

  factory CampusGroup.fromJson(Map<String, dynamic> json) {
    return CampusGroup(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      name: _readString(json, 'name', fallback: '校园群组'),
      coverUrl: _readString(
        json,
        'coverUrl',
        fallback:
            'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80',
      ),
      iconUrl: _readString(
        json,
        'iconUrl',
        fallback:
            'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=500&q=80',
      ),
      description: _readString(json, 'description'),
      members: _readInt(json, 'members'),
      admins: _readInt(json, 'admins'),
      tags: _readStringList(json, 'tags'),
      activities: _readMapList(
        json,
        'activities',
      ).map(CampusActivity.fromJson).toList(growable: false),
      discussions: _readMapList(
        json,
        'discussions',
      ).map(CampusPost.fromJson).toList(growable: false),
      announcementText: _readString(json, 'announcementText'),
      announcementUpdatedAt: _readString(json, 'announcementUpdatedAt'),
      announcementUpdatedBy: _readMap(json, 'announcementUpdatedBy') == null
          ? null
          : CampusUser.fromJson(_readMap(json, 'announcementUpdatedBy')!),
      pinnedDiscussionIds: _readStringList(json, 'pinnedDiscussionIds'),
      visibility: _readString(json, 'visibility', fallback: 'approval'),
      joined: json['joined'] == true,
      membershipRole: _readString(json, 'membershipRole'),
      membershipId: _readString(json, 'membershipId'),
      membershipStatus: _readString(json, 'membershipStatus'),
      canManage: json['canManage'] == true,
    );
  }

  CampusGroup copyWith({
    String? id,
    String? name,
    String? coverUrl,
    String? iconUrl,
    String? description,
    int? members,
    int? admins,
    List<String>? tags,
    List<CampusActivity>? activities,
    List<CampusPost>? discussions,
    String? announcementText,
    String? announcementUpdatedAt,
    CampusUser? announcementUpdatedBy,
    List<String>? pinnedDiscussionIds,
    String? visibility,
    bool? joined,
    String? membershipRole,
    String? membershipId,
    String? membershipStatus,
    bool? canManage,
  }) {
    return CampusGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      tags: tags ?? this.tags,
      activities: activities ?? this.activities,
      discussions: discussions ?? this.discussions,
      announcementText: announcementText ?? this.announcementText,
      announcementUpdatedAt:
          announcementUpdatedAt ?? this.announcementUpdatedAt,
      announcementUpdatedBy:
          announcementUpdatedBy ?? this.announcementUpdatedBy,
      pinnedDiscussionIds: pinnedDiscussionIds ?? this.pinnedDiscussionIds,
      visibility: visibility ?? this.visibility,
      joined: joined ?? this.joined,
      membershipRole: membershipRole ?? this.membershipRole,
      membershipId: membershipId ?? this.membershipId,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      canManage: canManage ?? this.canManage,
    );
  }
}

class CampusGroupMember {
  const CampusGroupMember({
    required this.id,
    required this.user,
    required this.role,
    required this.status,
    required this.createdAt,
    this.reviewedAt = '',
    this.reviewedBy,
  });

  final String id;
  final CampusUser user;
  final String role;
  final String status;
  final String createdAt;
  final String reviewedAt;
  final CampusUser? reviewedBy;

  factory CampusGroupMember.fromJson(Map<String, dynamic> json) {
    final userJson = _readMap(json, 'user');
    final reviewedByJson = _readMap(json, 'reviewedBy');
    return CampusGroupMember(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      user: userJson == null
          ? const CampusUser(
              name: '校园同学',
              school: '未知学院',
              major: '未填写专业',
              grade: '未填写年级',
              avatarUrl: 'https://i.pravatar.cc/180?img=1',
              bio: '',
            )
          : CampusUser.fromJson(userJson),
      role: _readString(json, 'role', fallback: 'member'),
      status: _readString(json, 'status', fallback: 'active'),
      createdAt: _readString(json, 'createdAt', fallback: '刚刚'),
      reviewedAt: _readString(json, 'reviewedAt'),
      reviewedBy: reviewedByJson == null
          ? null
          : CampusUser.fromJson(reviewedByJson),
    );
  }
}

class CampusTopic {
  const CampusTopic({
    this.id = '',
    required this.name,
    required this.coverUrl,
    required this.description,
    required this.discussions,
    required this.onlineCount,
    required this.posts,
    required this.contributors,
    required this.relatedTopics,
  });

  final String id;
  final String name;
  final String coverUrl;
  final String description;
  final String discussions;
  final int onlineCount;
  final List<CampusPost> posts;
  final List<CampusUser> contributors;
  final List<String> relatedTopics;

  factory CampusTopic.fromJson(Map<String, dynamic> json) {
    return CampusTopic(
      id: _readString(json, 'id', fallback: _readString(json, '_id')),
      name: _readString(json, 'name', fallback: '校园话题'),
      coverUrl: _readString(
        json,
        'coverUrl',
        fallback:
            'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=1200&q=80',
      ),
      description: _readString(json, 'description'),
      discussions: _readString(json, 'discussions', fallback: '0'),
      onlineCount: _readInt(json, 'onlineCount'),
      posts: _readMapList(
        json,
        'posts',
      ).map(CampusPost.fromJson).toList(growable: false),
      contributors: _readMapList(
        json,
        'contributors',
      ).map(CampusUser.fromJson).toList(growable: false),
      relatedTopics: _readStringList(json, 'relatedTopics'),
    );
  }

  CampusTopic copyWith({
    String? id,
    List<CampusPost>? posts,
    List<CampusUser>? contributors,
  }) {
    return CampusTopic(
      id: id ?? this.id,
      name: name,
      coverUrl: coverUrl,
      description: description,
      discussions: discussions,
      onlineCount: onlineCount,
      posts: posts ?? this.posts,
      contributors: contributors ?? this.contributors,
      relatedTopics: relatedTopics,
    );
  }
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  return fallback;
}

String? _readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int _readInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return value
      .whereType<Object>()
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic>? _readMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

List<Map<String, dynamic>> _readMapList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList(growable: false);
}
