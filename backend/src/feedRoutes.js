const express = require('express');

const { isMongoReady } = require('./db');
const Activity = require('./models/Activity');
const User = require('./models/User');
const seed = require('./data/seed');

const router = express.Router();

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

module.exports = router;
