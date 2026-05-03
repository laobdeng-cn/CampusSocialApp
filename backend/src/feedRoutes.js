const express = require('express');

const { verifyToken } = require('./auth');
const { isMongoReady } = require('./db');
const Activity = require('./models/Activity');
const CheckIn = require('./models/CheckIn');
const Enrollment = require('./models/Enrollment');
const User = require('./models/User');
const seed = require('./data/seed');

const router = express.Router();

const legacyActivityTitleMap = {
  campus_music_night: '校园音乐之夜',
  ai_future_talk: 'AI 未来发展趋势讲座',
  campus_basketball_match: '校园篮球友谊赛',
  photo_club_walk: '摄影社团采风活动',
};

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

function serializeActivity(activity) {
  if (!activity) return null;
  const plain = typeof activity.toObject === 'function' ? activity.toObject() : activity;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    createdBy: publicUser(plain.createdBy),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function serializeCheckIn(checkIn) {
  if (!checkIn) return null;
  const plain = typeof checkIn.toObject === 'function' ? checkIn.toObject() : checkIn;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    activity: serializeActivity(plain.activity),
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
      response.json(seed);
      return;
    }

    const [users, activities] = await Promise.all([
      User.find().sort({ createdAt: -1 }).lean(),
      Activity.find({ publicDisplay: { $ne: false } })
        .populate('createdBy')
        .sort({ enrolled: -1, createdAt: -1 })
        .lean(),
    ]);

    const realActivities = activities
      .map(serializeActivity)
      .filter((activity) => activity && activity.id);

    response.json({
      users: users.length > 0 ? users.map(publicUser) : seed.users,
      posts: seed.posts,
      activities: realActivities.length > 0 ? realActivities : seed.activities,
      groups: seed.groups,
      topics: seed.topics,
    });
  } catch (error) {
    console.error('Feed route failed:', error);
    next(error);
  }
});

router.get('/me/activities', requireAuth, async (request, response, next) => {
  try {
    const enrollments = await Enrollment.find({
      user: request.user._id,
      status: 'registered',
    })
      .populate({ path: 'activity', populate: { path: 'createdBy' } })
      .sort({ createdAt: -1 })
      .lean();

    response.json({
      activities: enrollments
        .map((enrollment) => serializeActivity(enrollment.activity))
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

    const code = String(request.body.code || '').trim();
    const expectedCode = String(activity.checkInCode || '').trim();
    if (expectedCode && code.toUpperCase() !== expectedCode.toUpperCase()) {
      response.status(400).json({ message: '签到口令错误，请重新输入' });
      return;
    }

    let created = false;
    let checkIn = await CheckIn.findOne({
      activity: activity._id,
      user: request.user._id,
    });

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
