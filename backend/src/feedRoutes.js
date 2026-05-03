const express = require('express');

const { isMongoReady } = require('./db');
const Activity = require('./models/Activity');
const Post = require('./models/Post');
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

function serializePost(post) {
  if (!post) return null;
  const plain = typeof post.toObject === 'function' ? post.toObject() : post;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    author: publicUser(plain.author),
    groupId: String(plain.group?._id || plain.group || ''),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
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

    const [users, posts, activities] = await Promise.all([
      User.find().sort({ createdAt: -1 }).lean(),
      Post.find().populate('author').populate('group').sort({ createdAt: -1 }).lean(),
      Activity.find({ publicDisplay: { $ne: false } })
        .populate('createdBy')
        .sort({ createdAt: -1 })
        .lean(),
    ]);

    response.json({
      users: users.length > 0 ? users.map(publicUser) : seed.users,
      posts: posts.length > 0 ? posts.map(serializePost) : seed.posts,
      activities: activities.length > 0
        ? activities.map(serializeActivity)
        : seed.activities,
      groups: seed.groups,
      topics: seed.topics,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
