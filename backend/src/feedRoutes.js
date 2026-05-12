const express = require('express');

const { verifyToken } = require('./auth');
const { isMongoReady } = require('./db');
const Activity = require('./models/Activity');
const Post = require('./models/Post');
const CheckIn = require('./models/CheckIn');
const Enrollment = require('./models/Enrollment');
const Group = require('./models/Group');
const User = require('./models/User');
const Topic = require('./models/Topic');
const seed = require('./data/seed');

const DEMO_USER_NAMES = new Set([
  '林小北',
  '陈可欣',
  '王子豪',
  '刘思雨',
  '张晓晨',
  'user123',
]);

const DEMO_POST_TITLES = new Set([
  '校园日落拍摄地推荐',
  '新图书馆自习位怎么预约？求攻略！',
  '高效复习时间表分享，亲测有效！',
  '各科目复习资料大合集（持续更新）',
  '图书馆自习打卡',
  '食堂新品测评｜芝士焗饭绝了！',
]);

const DEMO_ACTIVITY_TITLES = new Set([
  '校园音乐之夜',
  '摄影社团采风活动',
  '设计作品分享会',
]);

function isDemoUserPayload(user) {
  if (!user) return false;
  return DEMO_USER_NAMES.has(user.name) || String(user.username || '').startsWith('seed_');
}

function isDemoPostPayload(post) {
  if (!post) return false;
  return DEMO_POST_TITLES.has(String(post.title || '').trim()) || isDemoUserPayload(post.author);
}

function isDemoActivityPayload(activity) {
  if (!activity) return false;
  return DEMO_ACTIVITY_TITLES.has(String(activity.title || '').trim());
}



const router = express.Router();

const legacyActivityTitleMap = {
  campus_music_night: '校园音乐之夜',
  ai_future_talk: 'AI 未来发展趋势讲座',
  campus_basketball_match: '校园篮球友谊赛',
  photo_club_walk: '摄影社团采风活动',
};

const MINUTE = 60 * 1000;

function readBearerToken(request) {
  const header = request.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  return scheme?.toLowerCase() === 'bearer' ? token : '';
}

async function requireAuth(request, response, next) {
  try {
    if (!isMongoReady()) {
      response.status(503).json({ message: 'MongoDB is required for this action.' });
      return;
    }

    const payload = verifyToken(readBearerToken(request));
    if (!payload?.sub) {
      response.status(401).json({ message: '请先登录' });
      return;
    }

    const user = await User.findById(payload.sub);
    if (!user || user.tokenVersion !== payload.tokenVersion) {
      response.status(401).json({ message: '登录状态已失效，请重新登录' });
      return;
    }

    request.user = user;
    next();
  } catch (error) {
    next(error);
  }
}

function publicUser(user) {
  if (!user) return null;
  const plain = typeof user.toObject === 'function' ? user.toObject() : user;
  const { passwordHash, tokenVersion, ...safeUser } = plain;
  return {
    ...safeUser,
    id: String(plain._id || plain.id || ''),
  };
}

function serializePost(post) {
  if (!post) return null;
  const plain = typeof post.toObject === 'function' ? post.toObject() : post;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    groupId: plain.group ? String(plain.group._id || plain.group.id || plain.group) : '',
    author: publicUser(plain.author),
    createdAt: plain.createdAt instanceof Date ? plain.createdAt.toISOString() : plain.createdAt,
    updatedAt: plain.updatedAt instanceof Date ? plain.updatedAt.toISOString() : plain.updatedAt,
  };
}

function parseActivitySchedule(activity) {
  const plain = typeof activity?.toObject === 'function' ? activity.toObject() : activity;
  const dateText = String(plain?.date || '');
  const timeText = String(plain?.time || '');
  const dateMatch = dateText.match(/(\d{1,2})月(\d{1,2})日/);
  const timeMatch = timeText.match(/(\d{1,2}):(\d{2})(?:\s*[-–—]\s*(\d{1,2}):(\d{2}))?/);

  if (!dateMatch || !timeMatch) return null;

  const now = new Date();
  const year = now.getFullYear();
  const month = Number(dateMatch[1]) - 1;
  const day = Number(dateMatch[2]);
  const startHour = Number(timeMatch[1]);
  const startMinute = Number(timeMatch[2]);
  const endHour = timeMatch[3] == null ? startHour + 2 : Number(timeMatch[3]);
  const endMinute = timeMatch[4] == null ? startMinute : Number(timeMatch[4]);

  const startAt = new Date(year, month, day, startHour, startMinute, 0, 0);
  const endAt = new Date(year, month, day, endHour, endMinute, 0, 0);
  if (Number.isNaN(startAt.getTime()) || Number.isNaN(endAt.getTime())) return null;

  if (endAt.getTime() <= startAt.getTime()) {
    endAt.setDate(endAt.getDate() + 1);
  }

  return {
    startAt,
    endAt,
    checkInStartAt: startAt,
    checkInEndAt: endAt,
  };
}

function buildActivityTimeline(activity, checkedIn = false) {
  const schedule = parseActivitySchedule(activity);
  if (!schedule) {
    return {
      activityStatus: checkedIn ? 'checked_in' : 'registered',
      checkInStatus: checkedIn ? 'checked_in' : 'available',
      statusText: checkedIn ? '已签到' : '可签到',
      countdownText: '',
    };
  }

  const now = Date.now();
  const startMs = schedule.startAt.getTime();
  const endMs = schedule.endAt.getTime();
  const diffMinutes = Math.max(0, Math.ceil((startMs - now) / MINUTE));
  const diffDays = Math.floor(diffMinutes / (60 * 24));
  const diffHours = Math.floor((diffMinutes % (60 * 24)) / 60);
  const diffRestMinutes = diffMinutes % 60;
  const countdownText = now < startMs
    ? diffDays > 0
      ? `距离签到开始还有 ${diffDays} 天 ${diffHours} 小时`
      : diffHours > 0
        ? `距离签到开始还有 ${diffHours} 小时 ${diffRestMinutes} 分钟`
        : `距离签到开始还有 ${diffRestMinutes} 分钟`
    : '';

  if (now > endMs) {
    return {
      startAt: schedule.startAt.toISOString(),
      endAt: schedule.endAt.toISOString(),
      checkInStartAt: schedule.checkInStartAt.toISOString(),
      checkInEndAt: schedule.checkInEndAt.toISOString(),
      activityStatus: 'ended',
      checkInStatus: 'ended',
      statusText: '活动已结束',
      countdownText: '',
    };
  }

  if (checkedIn) {
    return {
      startAt: schedule.startAt.toISOString(),
      endAt: schedule.endAt.toISOString(),
      checkInStartAt: schedule.checkInStartAt.toISOString(),
      checkInEndAt: schedule.checkInEndAt.toISOString(),
      activityStatus: 'checked_in',
      checkInStatus: 'checked_in',
      statusText: '已签到',
      countdownText: '',
    };
  }

  if (now < startMs) {
    return {
      startAt: schedule.startAt.toISOString(),
      endAt: schedule.endAt.toISOString(),
      checkInStartAt: schedule.checkInStartAt.toISOString(),
      checkInEndAt: schedule.checkInEndAt.toISOString(),
      activityStatus: 'registered',
      checkInStatus: 'not_started',
      statusText: '签到未开始',
      countdownText,
    };
  }

  return {
    startAt: schedule.startAt.toISOString(),
    endAt: schedule.endAt.toISOString(),
    checkInStartAt: schedule.checkInStartAt.toISOString(),
    checkInEndAt: schedule.checkInEndAt.toISOString(),
    activityStatus: 'checkin_available',
    checkInStatus: 'available',
    statusText: '可签到',
    countdownText: '',
  };
}

function assertCheckInWindow(activity, response) {
  const schedule = parseActivitySchedule(activity);
  if (!schedule) return true;

  const now = Date.now();
  if (now < schedule.checkInStartAt.getTime()) {
    response.status(400).json({
      message: '签到未开始，请在活动开始后再签到',
      timeline: buildActivityTimeline(activity),
    });
    return false;
  }

  if (now > schedule.checkInEndAt.getTime()) {
    response.status(400).json({
      message: '活动已结束，无法签到',
      timeline: buildActivityTimeline(activity),
    });
    return false;
  }

  return true;
}


function normalizeActivityImages(activity) {
  const plain = activity?.toObject ? activity.toObject() : activity || {};
  const raw = Array.isArray(plain.images) ? plain.images : [];
  const images = raw.map((item) => String(item || '').trim()).filter(Boolean);
  const poster = String(plain.posterUrl || '').trim();
  if (poster && !images.includes(poster)) images.unshift(poster);
  return images;
}

function serializeActivity(activity, options = {}) {
  if (!activity) return null;
  const plain = typeof activity.toObject === 'function' ? activity.toObject() : activity;
  return {
    ...plain,
    ...buildActivityTimeline(plain, options.checkedIn === true),
    id: String(plain._id || plain.id || ''),
    createdBy: publicUser(plain.createdBy),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function serializeGroup(group) {
  if (!group) return null;
  const plain = typeof group.toObject === 'function' ? group.toObject() : group;
  const pinnedIds = (plain.pinnedDiscussionIds || []).map((item) =>
    String(item?._id || item || '')
  );
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    activities: (plain.activityIds || [])
      .map((activity) => serializeActivity(activity))
      .filter(Boolean),
    discussions: (plain.discussionIds || [])
      .map((post) => serializePost(post))
      .filter(Boolean)
      .map((post) => ({
        ...post,
        pinnedInGroup: pinnedIds.includes(String(post.id)),
      })),
    announcementUpdatedBy: publicUser(plain.announcementUpdatedBy),
    pinnedDiscussionIds: pinnedIds,
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
    updatedAt: plain.updatedAt instanceof Date
      ? plain.updatedAt.toISOString()
      : plain.updatedAt,
  };
}

function serializeTopic(topic) {
  if (!topic) return null;
  const plain = typeof topic.toObject === 'function' ? topic.toObject() : topic;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    posts: (plain.postIds || []).map((post) => serializePost(post)).filter(Boolean),
    contributors: (plain.contributorIds || [])
      .map((user) => publicUser(user))
      .filter(Boolean),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
    updatedAt: plain.updatedAt instanceof Date
      ? plain.updatedAt.toISOString()
      : plain.updatedAt,
  };
}

function generateResetCheckInCode() {
  return `ACT${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
}

function serializeCheckIn(checkIn) {
  if (!checkIn) return null;
  const plain = typeof checkIn.toObject === 'function' ? checkIn.toObject() : checkIn;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    activity: serializeActivity(plain.activity, { checkedIn: true }),
    enrollment: plain.enrollment
      ? String(plain.enrollment._id || plain.enrollment.id || plain.enrollment)
      : '',
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

async function findActivityByAnyId(activityId) {
  if (!activityId) return null;

  const title = legacyActivityTitleMap[activityId];
  if (title) {
    return Activity.findOne({ title }).populate('createdBy');
  }

  if (/^[0-9a-fA-F]{24}$/.test(activityId)) {
    return Activity.findById(activityId).populate('createdBy');
  }

  return null;
}

router.use(async (request, _response, next) => {
  try {
    if (!isMongoReady()) {
      next();
      return;
    }

    const match = request.url.match(/^\/activities\/([^/?#]+)/);
    if (!match) {
      next();
      return;
    }

    const legacyId = decodeURIComponent(match[1]);
    const title = legacyActivityTitleMap[legacyId];
    if (!title) {
      next();
      return;
    }

    const activity = await Activity.findOne({ title }).select('_id').lean();
    if (activity?._id) {
      request.url = request.url.replace(
        `/activities/${encodeURIComponent(legacyId)}`,
        `/activities/${activity._id}`
      );
    }

    next();
  } catch (error) {
    next(error);
  }
});

router.get('/feed', async (_request, response, next) => {
  try {
    if (!isMongoReady()) {
      response.json({
        users: [],
        posts: [],
        activities: [],
        groups: [],
        topics: [],
      });
      return;
    }

    const [users, posts, activities, groups, topics] = await Promise.all([
      User.find().sort({ createdAt: -1 }).lean(),
      Post.find({ visibility: { $ne: 'private' } })
        .populate('author')
        .sort({ createdAt: -1 })
        .lean(),
      Activity.find({ publicDisplay: { $ne: false } })
        .populate('createdBy')
        .sort({ enrolled: -1, createdAt: -1 })
        .lean(),
      Group.find()
        .populate('announcementUpdatedBy')
        .populate({ path: 'activityIds', populate: { path: 'createdBy' } })
        .populate({ path: 'discussionIds', populate: 'author' })
        .sort({ members: -1, createdAt: -1 })
        .lean(),
      Topic.find()
        .populate({ path: 'postIds', populate: 'author' })
        .populate('contributorIds')
        .sort({ onlineCount: -1, createdAt: -1 })
        .lean(),
    ]);

    const realPosts = posts
      .map((post) => serializePost(post))
      .filter((post) => post && post.id && post.author);

    const realActivities = activities
      .map((activity) => serializeActivity(activity))
      .filter((activity) => activity && activity.id);

    response.json({
      users: users.map(publicUser),
      posts: realPosts,
      activities: realActivities,
      groups: groups.map(serializeGroup).filter(Boolean),
      topics: topics.map(serializeTopic).filter(Boolean),
    });
  } catch (error) {
    console.error('Feed route failed:', error);
    next(error);
  }
});

router.get('/me/activities', requireAuth, async (request, response, next) => {
  try {
    const [enrollments, checkIns] = await Promise.all([
      Enrollment.find({
        user: request.user._id,
        status: 'registered',
      })
        .populate({ path: 'activity', populate: { path: 'createdBy' } })
        .sort({ createdAt: -1 })
        .lean(),
      CheckIn.find({ user: request.user._id }).select('activity').lean(),
    ]);

    const checkedActivityIds = new Set(
      checkIns.map((item) => String(item.activity?._id || item.activity || ''))
    );

    response.json({
      activities: enrollments
        .map((enrollment) => serializeActivity(enrollment.activity, {
          checkedIn: checkedActivityIds.has(String(enrollment.activity?._id || '')),
        }))
        .filter(Boolean),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/me/checkins', requireAuth, async (request, response, next) => {
  try {
    const checkIns = await CheckIn.find({ user: request.user._id })
      .populate({ path: 'activity', populate: { path: 'createdBy' } })
      .populate('enrollment')
      .sort({ createdAt: -1 })
      .lean();

    response.json({
      checkIns: checkIns.map(serializeCheckIn).filter(Boolean),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/activities/:id/checkin-code', requireAuth, async (request, response, next) => {
  try {
    console.log(`[activity] get check-in code request: ${request.params.id}`);

    const activity = await findActivityByAnyId(request.params.id);
    if (!activity) {
      response.status(404).json({ message: '活动不存在' });
      return;
    }

    const ownerId = String(activity.createdBy?._id || activity.createdBy || '');
    const currentUserId = String(request.user._id || '');

    if (ownerId !== currentUserId) {
      response.status(403).json({ message: '只有活动发起人可以查看签到口令' });
      return;
    }

    response.json({
      code: String(activity.checkInCode || ''),
    });
  } catch (error) {
    console.error('[activity] get check-in code failed:', error);
    next(error);
  }
});

router.post('/activities/:id/checkin-code/reset', requireAuth, async (request, response, next) => {
  try {
    console.log(`[activity] reset check-in code request: ${request.params.id}`);

    const activity = await findActivityByAnyId(request.params.id);
    if (!activity) {
      response.status(404).json({ message: '活动不存在' });
      return;
    }

    const ownerId = String(activity.createdBy?._id || activity.createdBy || '');
    const currentUserId = String(request.user._id || '');

    if (ownerId !== currentUserId) {
      response.status(403).json({ message: '只有活动发起人可以重置签到口令' });
      return;
    }

    activity.checkInCode = generateResetCheckInCode();
    await activity.save();

    const populated = await Activity.findById(activity._id).populate('createdBy');

    console.log(
      `[activity] reset check-in code success: ${activity._id} -> ${activity.checkInCode}`
    );

    response.json({
      code: activity.checkInCode,
      activity: serializeActivity(populated),
    });
  } catch (error) {
    console.error('[activity] reset check-in code failed:', error);
    next(error);
  }
});

router.post('/activities/:id/checkins', requireAuth, async (request, response, next) => {
  try {
    const activity = await findActivityByAnyId(request.params.id);
    if (!activity) {
      response.status(404).json({ message: '活动不存在' });
      return;
    }

    const enrollment = await Enrollment.findOne({
      activity: activity._id,
      user: request.user._id,
      status: 'registered',
    });

    if (!enrollment) {
      response.status(403).json({ message: '请先报名该活动后再签到' });
      return;
    }

    let created = false;
    let checkIn = await CheckIn.findOne({
      activity: activity._id,
      user: request.user._id,
    });

    if (!checkIn && !assertCheckInWindow(activity, response)) return;

    const code = String(request.body.code || '').trim();
    const expectedCode = String(activity.checkInCode || '').trim();
    if (!checkIn && expectedCode && code.toUpperCase() !== expectedCode.toUpperCase()) {
      response.status(400).json({ message: '签到口令错误，请重新输入' });
      return;
    }

    if (!checkIn) {
      checkIn = await CheckIn.create({
        activity: activity._id,
        user: request.user._id,
        enrollment: enrollment._id,
        method: 'code',
        status: 'checked_in',
        code,
      });
      created = true;
    }

    const populated = await CheckIn.findById(checkIn._id)
      .populate({ path: 'activity', populate: { path: 'createdBy' } })
      .populate('enrollment')
      .lean();

    response.status(created ? 201 : 200).json({
      checkIn: serializeCheckIn(populated),
    });
  } catch (error) {
    if (error?.code === 11000) {
      response.status(409).json({ message: '你已经完成过该活动签到' });
      return;
    }
    next(error);
  }
});

module.exports = router;
