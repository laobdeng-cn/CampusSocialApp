const express = require('express');

const { hashPassword, signToken, verifyPassword, verifyToken } = require('../auth');
const { isMongoReady } = require('../db');
const Activity = require('../models/Activity');
const BrowsingHistory = require('../models/BrowsingHistory');
const CheckIn = require('../models/CheckIn');
const Comment = require('../models/Comment');
const Conversation = require('../models/Conversation');
const Draft = require('../models/Draft');
const Enrollment = require('../models/Enrollment');
const Favorite = require('../models/Favorite');
const Follow = require('../models/Follow');
const Group = require('../models/Group');
const GroupMembership = require('../models/GroupMembership');
const Like = require('../models/Like');
const Message = require('../models/Message');
const Notification = require('../models/Notification');
const Post = require('../models/Post');
const Topic = require('../models/Topic');
const User = require('../models/User');
const seed = require('../data/seed');

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
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function serializeGroup(group) {
  if (!group) return null;
  const plain = typeof group.toObject === 'function' ? group.toObject() : group;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    activities: (plain.activityIds || plain.activities || [])
      .map(serializeActivity)
      .filter(Boolean),
    discussions: (plain.discussionIds || plain.discussions || [])
      .map(serializePost)
      .filter(Boolean),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function serializeTopic(topic) {
  if (!topic) return null;
  const plain = typeof topic.toObject === 'function' ? topic.toObject() : topic;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    posts: (plain.postIds || plain.posts || [])
      .map(serializePost)
      .filter(Boolean),
    contributors: (plain.contributorIds || plain.contributors || [])
      .map(publicUser)
      .filter(Boolean),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function serializeFollowUser(user, options = {}) {
  return {
    ...publicUser(user),
    followedAt: options.followedAt,
    followsMe: options.followsMe === true,
    followedByMe: options.followedByMe === true,
  };
}

function serializeCheckIn(checkIn) {
  if (!checkIn) return null;
  const plain = typeof checkIn.toObject === 'function' ? checkIn.toObject() : checkIn;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    activity: serializeActivity(plain.activity),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function serializeComment(comment) {
  if (!comment) return null;
  const plain = typeof comment.toObject === 'function' ? comment.toObject() : comment;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    author: publicUser(plain.author),
    post: serializePost(plain.post),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function serializeNotification(notification) {
  if (!notification) return null;
  const plain = typeof notification.toObject === 'function'
    ? notification.toObject()
    : notification;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    actor: publicUser(plain.actor),
    post: serializePost(plain.post),
    activity: serializeActivity(plain.activity),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function defaultSettings(settings = {}) {
  return {
    notifications: {
      messageReminder: settings.notifications?.messageReminder !== false,
      activityNotice: settings.notifications?.activityNotice !== false,
      systemNotice: settings.notifications?.systemNotice !== false,
    },
    privacy: {
      allowSearch: settings.privacy?.allowSearch !== false,
      blockStrangerComments: settings.privacy?.blockStrangerComments !== false,
      profileVisibility: settings.privacy?.profileVisibility || 'friends',
      dmPermission: settings.privacy?.dmPermission || 'friends_and_following',
    },
  };
}

function serializeHistory(history) {
  if (!history) return null;
  const plain = typeof history.toObject === 'function' ? history.toObject() : history;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
    updatedAt: plain.updatedAt instanceof Date
      ? plain.updatedAt.toISOString()
      : plain.updatedAt,
  };
}

function serializeDraft(draft) {
  if (!draft) return null;
  const plain = typeof draft.toObject === 'function' ? draft.toObject() : draft;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
    updatedAt: plain.updatedAt instanceof Date
      ? plain.updatedAt.toISOString()
      : plain.updatedAt,
  };
}

function serializeMessage(message, currentUserId) {
  if (!message) return null;
  const plain = typeof message.toObject === 'function' ? message.toObject() : message;
  return {
    ...plain,
    id: String(plain._id || plain.id || ''),
    sender: publicUser(plain.sender),
    isMine: String(plain.sender?._id || plain.sender || '') === String(currentUserId),
    createdAt: plain.createdAt instanceof Date
      ? plain.createdAt.toISOString()
      : plain.createdAt,
  };
}

function serializeConversation(conversation, currentUserId, unreadCount = 0) {
  if (!conversation) return null;
  const plain = typeof conversation.toObject === 'function'
    ? conversation.toObject()
    : conversation;
  const participants = Array.isArray(plain.participants) ? plain.participants : [];
  const contact = participants.find(
    (participant) => String(participant?._id || participant) !== String(currentUserId)
  );

  return {
    id: String(plain._id || plain.id || ''),
    contact: publicUser(contact),
    lastMessage: plain.lastMessage || '',
    unreadCount,
    updatedAt: plain.updatedAt instanceof Date
      ? plain.updatedAt.toISOString()
      : plain.updatedAt,
  };
}

async function findPostOr404(postId, response) {
  const post = await Post.findById(postId).populate('author');
  if (!post) {
    response.status(404).json({ message: '帖子不存在' });
    return null;
  }
  return post;
}

async function findActivityOr404(activityId, response) {
  const activity = await Activity.findById(activityId);
  if (!activity) {
    response.status(404).json({ message: '活动不存在' });
    return null;
  }
  return activity;
}

async function findUserOr404(userId, response) {
  const user = await User.findById(userId);
  if (!user) {
    response.status(404).json({ message: '用户不存在' });
    return null;
  }
  return user;
}

async function findGroupOr404(groupId, response) {
  const group = await Group.findById(groupId)
    .populate('activityIds')
    .populate({ path: 'discussionIds', populate: 'author' });
  if (!group) {
    response.status(404).json({ message: '社群不存在' });
    return null;
  }
  return group;
}

async function findConversationOr404(conversationId, userId, response) {
  const conversation = await Conversation.findOne({
    _id: conversationId,
    participants: userId,
  }).populate('participants');
  if (!conversation) {
    response.status(404).json({ message: '会话不存在' });
    return null;
  }
  return conversation;
}

function readBearerToken(request) {
  const header = request.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  return scheme?.toLowerCase() === 'bearer' ? token : '';
}

async function requireAuth(request, response, next) {
  try {
    if (!isMongoReady()) {
      response.status(503).json({ message: 'MongoDB is required for authentication.' });
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

function issueAuthResponse(response, user) {
  const token = signToken({
    sub: String(user._id),
    username: user.username,
    tokenVersion: user.tokenVersion,
  });
  response.json({
    token,
    user: publicUser(user),
  });
}

async function fromMongoOrSeed(model, seedData, options = {}) {
  if (!isMongoReady()) return seedData;

  const query = model.find();

  if (options.populate) {
    query.populate(options.populate);
  }

  const docs = await query.sort({ createdAt: -1 }).lean();
  if (docs.length === 0) return seedData;
  if (model.modelName === 'User') return docs.map(publicUser);
  if (model.modelName === 'Post') return docs.map(serializePost);
  if (model.modelName === 'Activity') return docs.map(serializeActivity);
  if (model.modelName === 'Group') return docs.map(serializeGroup);
  if (model.modelName === 'Topic') return docs.map(serializeTopic);
  return docs;
}

async function getFeedData() {
  const [users, posts, activities, groups, topics] = await Promise.all([
    fromMongoOrSeed(User, seed.users),
    fromMongoOrSeed(Post, seed.posts, { populate: 'author' }),
    fromMongoOrSeed(Activity, seed.activities),
    fromMongoOrSeed(Group, seed.groups, {
      populate: ['activityIds', { path: 'discussionIds', populate: 'author' }],
    }),
    fromMongoOrSeed(Topic, seed.topics, {
      populate: [
        { path: 'postIds', populate: 'author' },
        'contributorIds',
      ],
    }),
  ]);

  return {
    users,
    posts,
    activities,
    groups,
    topics,
  };
}

router.post('/auth/register', async (request, response, next) => {
  try {
    if (!isMongoReady()) {
      response.status(503).json({ message: 'MongoDB is required for registration.' });
      return;
    }

    const username = String(request.body.username || '').trim();
    const password = String(request.body.password || '');
    const name = String(request.body.name || '').trim();

    if (!username || !password || !name) {
      response.status(400).json({ message: '手机号、密码和昵称不能为空' });
      return;
    }
    if (password.length < 6) {
      response.status(400).json({ message: '密码至少需要 6 位' });
      return;
    }

    const exists = await User.findOne({ username });
    if (exists) {
      response.status(409).json({ message: '该手机号已注册' });
      return;
    }

    const user = await User.create({
      username,
      passwordHash: hashPassword(password),
      name,
      school: '未认证学校',
      major: '待认证专业',
      grade: '待认证',
      avatarUrl: 'https://i.pravatar.cc/180?img=12',
      bio: '这个同学还没有填写简介。',
    });

    response.status(201);
    issueAuthResponse(response, user);
  } catch (error) {
    next(error);
  }
});

router.post('/auth/login', async (request, response, next) => {
  try {
    if (!isMongoReady()) {
      response.status(503).json({ message: 'MongoDB is required for login.' });
      return;
    }

    const username = String(request.body.username || '').trim();
    const password = String(request.body.password || '');
    const user = await User.findOne({ username });

    if (!user || !verifyPassword(password, user.passwordHash)) {
      response.status(401).json({ message: '手机号或密码错误' });
      return;
    }

    issueAuthResponse(response, user);
  } catch (error) {
    next(error);
  }
});

router.get('/me', requireAuth, async (request, response) => {
  response.json({ user: publicUser(request.user) });
});

router.patch('/me/profile', requireAuth, async (request, response, next) => {
  try {
    const editableFields = ['name', 'school', 'major', 'grade', 'bio', 'avatarUrl', 'role'];
    for (const field of editableFields) {
      if (Object.prototype.hasOwnProperty.call(request.body, field)) {
        request.user[field] = String(request.body[field] || '').trim();
      }
    }

    if (!request.user.name || !request.user.school || !request.user.major || !request.user.grade) {
      response.status(400).json({ message: '昵称、学校、专业和年级不能为空' });
      return;
    }

    await request.user.save();
    response.json({ user: publicUser(request.user) });
  } catch (error) {
    next(error);
  }
});

router.get('/me/settings', requireAuth, async (request, response) => {
  response.json({ settings: defaultSettings(request.user.settings) });
});

router.patch('/me/settings', requireAuth, async (request, response, next) => {
  try {
    const nextSettings = defaultSettings(request.user.settings);
    const notifications = request.body.notifications || {};
    const privacy = request.body.privacy || {};

    for (const key of ['messageReminder', 'activityNotice', 'systemNotice']) {
      if (typeof notifications[key] === 'boolean') {
        nextSettings.notifications[key] = notifications[key];
      }
    }
    for (const key of ['allowSearch', 'blockStrangerComments']) {
      if (typeof privacy[key] === 'boolean') {
        nextSettings.privacy[key] = privacy[key];
      }
    }
    for (const key of ['profileVisibility', 'dmPermission']) {
      if (typeof privacy[key] === 'string' && privacy[key].trim()) {
        nextSettings.privacy[key] = privacy[key].trim();
      }
    }

    request.user.settings = nextSettings;
    await request.user.save();
    response.json({ settings: defaultSettings(request.user.settings) });
  } catch (error) {
    next(error);
  }
});

router.post('/auth/campus-verify', requireAuth, async (request, response, next) => {
  try {
    const realName = String(request.body.realName || '').trim();
    const campusName = String(request.body.campusName || '').trim();
    const studentId = String(request.body.studentId || '').trim();
    const major = String(request.body.major || '').trim();
    const enrollmentYear = String(request.body.enrollmentYear || '').trim();
    const campusRole = String(request.body.campusRole || 'student').trim();

    if (!realName || !campusName || !studentId || !major || !enrollmentYear) {
      response.status(400).json({ message: '请完整填写校园认证信息' });
      return;
    }

    request.user.realName = realName;
    request.user.campusName = campusName;
    request.user.studentId = studentId;
    request.user.school = campusName;
    request.user.major = major;
    request.user.grade = `${enrollmentYear}级`;
    request.user.campusRole = campusRole === 'teacher' ? 'teacher' : 'student';
    request.user.role = request.user.campusRole === 'teacher' ? '教师' : '学生';
    request.user.enrollmentYear = enrollmentYear;
    request.user.campusVerified = true;

    await request.user.save();
    response.json({ user: publicUser(request.user) });
  } catch (error) {
    next(error);
  }
});

router.get('/users', async (_request, response, next) => {
  try {
    response.json(await fromMongoOrSeed(User, seed.users));
  } catch (error) {
    next(error);
  }
});

router.get('/posts', async (_request, response, next) => {
  try {
    response.json(await fromMongoOrSeed(Post, seed.posts, { populate: 'author' }));
  } catch (error) {
    next(error);
  }
});

router.get('/me/posts', requireAuth, async (request, response, next) => {
  try {
    const posts = await Post.find({ author: request.user._id })
      .populate('author')
      .sort({ createdAt: -1 })
      .lean();
    response.json({ posts: posts.map(serializePost) });
  } catch (error) {
    next(error);
  }
});

router.get('/me/comments', requireAuth, async (request, response, next) => {
  try {
    const comments = await Comment.find({ author: request.user._id })
      .populate('author')
      .populate({ path: 'post', populate: 'author' })
      .sort({ createdAt: -1 })
      .lean();
    response.json({
      comments: comments.filter((comment) => comment.post).map(serializeComment),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/posts', requireAuth, async (request, response, next) => {
  try {
    const title = String(request.body.title || '').trim();
    const body = String(request.body.body || '').trim();
    const topic = String(request.body.topic || '校园生活').trim();
    const location = String(request.body.location || '').trim();
    const images = Array.isArray(request.body.images)
      ? request.body.images.filter((item) => typeof item === 'string' && item.trim())
      : [];

    if (!title || !body) {
      response.status(400).json({ message: '标题和内容不能为空' });
      return;
    }

    const post = await Post.create({
      author: request.user._id,
      title,
      body,
      topic,
      location,
      images,
    });

    const populated = await Post.findById(post._id).populate('author');
    response.status(201).json({ post: serializePost(populated) });
  } catch (error) {
    next(error);
  }
});

router.post('/posts/:id/like', requireAuth, async (request, response, next) => {
  try {
    const post = await findPostOr404(request.params.id, response);
    if (!post) return;

    const existing = await Like.findOne({ post: post._id, user: request.user._id });
    const liked = !existing;
    if (existing) {
      await existing.deleteOne();
      post.likes = Math.max(0, post.likes - 1);
    } else {
      await Like.create({ post: post._id, user: request.user._id });
      post.likes += 1;
    }

    await post.save();
    await post.populate('author');
    response.json({ liked, post: serializePost(post) });
  } catch (error) {
    next(error);
  }
});

router.post('/posts/:id/favorite', requireAuth, async (request, response, next) => {
  try {
    const post = await findPostOr404(request.params.id, response);
    if (!post) return;

    const existing = await Favorite.findOne({ post: post._id, user: request.user._id });
    const favorited = !existing;
    if (existing) {
      await existing.deleteOne();
      post.saves = Math.max(0, post.saves - 1);
    } else {
      await Favorite.create({ post: post._id, user: request.user._id });
      post.saves += 1;
    }

    await post.save();
    await post.populate('author');
    response.json({ favorited, post: serializePost(post) });
  } catch (error) {
    next(error);
  }
});

router.patch('/posts/:id', requireAuth, async (request, response, next) => {
  try {
    const post = await Post.findOne({ _id: request.params.id, author: request.user._id });
    if (!post) {
      response.status(404).json({ message: '帖子不存在或无权编辑' });
      return;
    }

    for (const field of ['title', 'body', 'topic', 'location', 'visibility']) {
      if (Object.prototype.hasOwnProperty.call(request.body, field)) {
        post[field] = String(request.body[field] || '').trim();
      }
    }
    if (Array.isArray(request.body.images)) {
      post.images = request.body.images.filter((item) => typeof item === 'string' && item.trim());
    }
    if (!post.title || !post.body) {
      response.status(400).json({ message: '标题和内容不能为空' });
      return;
    }

    await post.save();
    await post.populate('author');
    response.json({ post: serializePost(post) });
  } catch (error) {
    next(error);
  }
});

router.delete('/posts/:id', requireAuth, async (request, response, next) => {
  try {
    const post = await Post.findOne({ _id: request.params.id, author: request.user._id });
    if (!post) {
      response.status(404).json({ message: '帖子不存在或无权删除' });
      return;
    }

    await Promise.all([
      Comment.deleteMany({ post: post._id }),
      Like.deleteMany({ post: post._id }),
      Favorite.deleteMany({ post: post._id }),
      Notification.deleteMany({ post: post._id }),
      BrowsingHistory.deleteMany({ kind: 'post', refId: post._id }),
      Group.updateMany({ discussionIds: post._id }, { $pull: { discussionIds: post._id } }),
      Topic.updateMany({ postIds: post._id }, { $pull: { postIds: post._id } }),
      post.deleteOne(),
    ]);

    response.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

router.get('/me/favorites', requireAuth, async (request, response, next) => {
  try {
    const favorites = await Favorite.find({ user: request.user._id })
      .populate({ path: 'post', populate: 'author' })
      .sort({ createdAt: -1 })
      .lean();

    response.json({
      favorites: favorites
        .filter((favorite) => favorite.post)
        .map((favorite) => ({
          id: String(favorite._id),
          kind: 'post',
          post: serializePost(favorite.post),
          createdAt: favorite.createdAt instanceof Date
            ? favorite.createdAt.toISOString()
            : favorite.createdAt,
        })),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/me/history', requireAuth, async (request, response, next) => {
  try {
    const records = await BrowsingHistory.find({ user: request.user._id })
      .sort({ updatedAt: -1 })
      .limit(80)
      .lean();
    response.json({ history: records.map(serializeHistory) });
  } catch (error) {
    next(error);
  }
});

router.post('/me/history', requireAuth, async (request, response, next) => {
  try {
    const kind = String(request.body.kind || '').trim();
    const title = String(request.body.title || '').trim();
    const refId = String(request.body.refId || '').trim() || undefined;

    if (!['post', 'activity', 'group', 'topic', 'user'].includes(kind) || !title) {
      response.status(400).json({ message: '浏览记录类型和标题不能为空' });
      return;
    }

    const payload = {
      user: request.user._id,
      kind,
      title,
      subtitle: String(request.body.subtitle || '').trim(),
      imageUrl: String(request.body.imageUrl || '').trim(),
    };
    if (refId) payload.refId = refId;

    const query = refId
      ? { user: request.user._id, kind, refId }
      : { user: request.user._id, kind, title };
    const record = await BrowsingHistory.findOneAndUpdate(
      query,
      { $set: payload },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    );

    response.status(201).json({ history: serializeHistory(record) });
  } catch (error) {
    next(error);
  }
});

router.delete('/me/history', requireAuth, async (request, response, next) => {
  try {
    await BrowsingHistory.deleteMany({ user: request.user._id });
    response.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

router.get('/me/drafts', requireAuth, async (request, response, next) => {
  try {
    const drafts = await Draft.find({ user: request.user._id })
      .sort({ updatedAt: -1 })
      .lean();
    response.json({ drafts: drafts.map(serializeDraft) });
  } catch (error) {
    next(error);
  }
});

router.post('/me/drafts', requireAuth, async (request, response, next) => {
  try {
    const title = String(request.body.title || '').trim();
    if (!title) {
      response.status(400).json({ message: '草稿标题不能为空' });
      return;
    }

    const draft = await Draft.create({
      user: request.user._id,
      kind: request.body.kind === 'activity' ? 'activity' : 'post',
      title,
      body: String(request.body.body || '').trim(),
      topic: String(request.body.topic || '校园生活').trim(),
      location: String(request.body.location || '').trim(),
      images: Array.isArray(request.body.images)
        ? request.body.images.filter((item) => typeof item === 'string' && item.trim())
        : [],
      status: request.body.status === 'pending' ? 'pending' : 'draft',
    });

    response.status(201).json({ draft: serializeDraft(draft) });
  } catch (error) {
    next(error);
  }
});

router.patch('/me/drafts/:id', requireAuth, async (request, response, next) => {
  try {
    const draft = await Draft.findOne({ _id: request.params.id, user: request.user._id });
    if (!draft) {
      response.status(404).json({ message: '草稿不存在' });
      return;
    }

    for (const field of ['title', 'body', 'topic', 'location']) {
      if (Object.prototype.hasOwnProperty.call(request.body, field)) {
        draft[field] = String(request.body[field] || '').trim();
      }
    }
    if (request.body.kind === 'activity' || request.body.kind === 'post') {
      draft.kind = request.body.kind;
    }
    if (request.body.status === 'pending' || request.body.status === 'draft') {
      draft.status = request.body.status;
    }
    if (Array.isArray(request.body.images)) {
      draft.images = request.body.images.filter((item) => typeof item === 'string' && item.trim());
    }

    if (!draft.title) {
      response.status(400).json({ message: '草稿标题不能为空' });
      return;
    }

    await draft.save();
    response.json({ draft: serializeDraft(draft) });
  } catch (error) {
    next(error);
  }
});

router.delete('/me/drafts/:id', requireAuth, async (request, response, next) => {
  try {
    const result = await Draft.deleteOne({ _id: request.params.id, user: request.user._id });
    if (result.deletedCount === 0) {
      response.status(404).json({ message: '草稿不存在' });
      return;
    }
    response.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

router.get('/posts/:id/comments', async (request, response, next) => {
  try {
    const comments = await Comment.find({ post: request.params.id })
      .populate('author')
      .sort({ createdAt: -1 })
      .lean();
    response.json({
      comments: comments.map(serializeComment),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/posts/:id/comments', requireAuth, async (request, response, next) => {
  try {
    const text = String(request.body.text || '').trim();
    if (!text) {
      response.status(400).json({ message: '评论内容不能为空' });
      return;
    }

    const post = await findPostOr404(request.params.id, response);
    if (!post) return;

    const comment = await Comment.create({
      post: post._id,
      author: request.user._id,
      text,
    });
    post.comments += 1;
    await post.save();
    await comment.populate('author');
    await post.populate('author');

    response.status(201).json({
      comment: serializeComment(comment),
      post: serializePost(post),
    });
  } catch (error) {
    next(error);
  }
});

router.delete('/comments/:id', requireAuth, async (request, response, next) => {
  try {
    const comment = await Comment.findOne({
      _id: request.params.id,
      author: request.user._id,
    });
    if (!comment) {
      response.status(404).json({ message: '评论不存在或无权删除' });
      return;
    }

    const post = await Post.findById(comment.post);
    await comment.deleteOne();
    if (post) {
      post.comments = Math.max(0, post.comments - 1);
      await post.save();
    }

    response.json({ ok: true, post: serializePost(post) });
  } catch (error) {
    next(error);
  }
});

router.post('/activities/:id/join', requireAuth, async (request, response, next) => {
  try {
    const activity = await findActivityOr404(request.params.id, response);
    if (!activity) return;

    let enrollment = await Enrollment.findOne({
      activity: activity._id,
      user: request.user._id,
    });
    const wasRegistered = enrollment?.status === 'registered';

    if (!enrollment) {
      enrollment = await Enrollment.create({
        activity: activity._id,
        user: request.user._id,
      });
    } else {
      enrollment.status = 'registered';
      await enrollment.save();
    }

    if (!wasRegistered) {
      activity.enrolled = Math.min(activity.capacity || Number.MAX_SAFE_INTEGER, activity.enrolled + 1);
      await activity.save();
    }

    response.json({
      registered: true,
      enrollment: {
        id: String(enrollment._id),
        status: enrollment.status,
      },
      activity: serializeActivity(activity),
    });
  } catch (error) {
    next(error);
  }
});

router.delete('/activities/:id/join', requireAuth, async (request, response, next) => {
  try {
    const activity = await findActivityOr404(request.params.id, response);
    if (!activity) return;

    const enrollment = await Enrollment.findOne({
      activity: activity._id,
      user: request.user._id,
    });

    if (enrollment?.status === 'registered') {
      enrollment.status = 'cancelled';
      await enrollment.save();
      activity.enrolled = Math.max(0, activity.enrolled - 1);
      await activity.save();
    }

    response.json({
      registered: false,
      activity: serializeActivity(activity),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/me/activities', requireAuth, async (request, response, next) => {
  try {
    const enrollments = await Enrollment.find({
      user: request.user._id,
      status: 'registered',
    })
      .populate('activity')
      .sort({ updatedAt: -1 })
      .lean();

    response.json({
      activities: enrollments
        .filter((enrollment) => enrollment.activity)
        .map((enrollment) => ({
          ...serializeActivity(enrollment.activity),
          enrollmentId: String(enrollment._id),
          enrollmentStatus: enrollment.status,
        })),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/activities/:id/checkins', requireAuth, async (request, response, next) => {
  try {
    const activity = await findActivityOr404(request.params.id, response);
    if (!activity) return;

    const inputCode = String(request.body.code || '').trim();
    if (!inputCode) {
      response.status(400).json({ message: '请输入签到口令' });
      return;
    }

    const expectedCode = String(activity.checkInCode || '').trim();
    if (inputCode.toUpperCase() !== expectedCode.toUpperCase()) {
      response.status(400).json({ message: '签到口令不正确' });
      return;
    }

    const enrollment = await Enrollment.findOne({
      activity: activity._id,
      user: request.user._id,
      status: 'registered',
    });
    if (!enrollment) {
      response.status(400).json({ message: '请先报名该活动后再签到' });
      return;
    }

    let checkIn = await CheckIn.findOne({
      activity: activity._id,
      user: request.user._id,
    });
    let created = false;
    if (!checkIn) {
      checkIn = await CheckIn.create({
        activity: activity._id,
        user: request.user._id,
        enrollment: enrollment._id,
        code: inputCode,
      });
      created = true;
    }

    await checkIn.populate('activity');
    response.status(created ? 201 : 200);
    response.json({ checkIn: serializeCheckIn(checkIn) });
  } catch (error) {
    next(error);
  }
});

router.get('/me/checkins', requireAuth, async (request, response, next) => {
  try {
    const checkIns = await CheckIn.find({ user: request.user._id })
      .populate('activity')
      .sort({ createdAt: -1 })
      .lean();

    response.json({
      checkIns: checkIns.map(serializeCheckIn),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/me/following', requireAuth, async (request, response, next) => {
  try {
    const follows = await Follow.find({ follower: request.user._id })
      .populate('following')
      .sort({ createdAt: -1 })
      .lean();
    const followingIds = follows
      .map((follow) => follow.following?._id)
      .filter(Boolean);
    const mutuals = await Follow.find({
      follower: { $in: followingIds },
      following: request.user._id,
    }).lean();
    const mutualIds = new Set(mutuals.map((follow) => String(follow.follower)));

    response.json({
      users: follows
        .filter((follow) => follow.following)
        .map((follow) =>
          serializeFollowUser(follow.following, {
            followedAt: follow.createdAt,
            followedByMe: true,
            followsMe: mutualIds.has(String(follow.following._id)),
          })
        ),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/me/followers', requireAuth, async (request, response, next) => {
  try {
    const follows = await Follow.find({ following: request.user._id })
      .populate('follower')
      .sort({ createdAt: -1 })
      .lean();
    const followerIds = follows
      .map((follow) => follow.follower?._id)
      .filter(Boolean);
    const followingBack = await Follow.find({
      follower: request.user._id,
      following: { $in: followerIds },
    }).lean();
    const followingBackIds = new Set(
      followingBack.map((follow) => String(follow.following))
    );

    response.json({
      users: follows
        .filter((follow) => follow.follower)
        .map((follow) =>
          serializeFollowUser(follow.follower, {
            followedAt: follow.createdAt,
            followsMe: true,
            followedByMe: followingBackIds.has(String(follow.follower._id)),
          })
        ),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/users/:id/follow', requireAuth, async (request, response, next) => {
  try {
    const target = await findUserOr404(request.params.id, response);
    if (!target) return;
    if (String(target._id) === String(request.user._id)) {
      response.status(400).json({ message: '不能关注自己' });
      return;
    }

    const existing = await Follow.findOne({
      follower: request.user._id,
      following: target._id,
    });
    if (!existing) {
      await Follow.create({
        follower: request.user._id,
        following: target._id,
      });
      request.user.following += 1;
      target.followers += 1;
      await Promise.all([request.user.save(), target.save()]);
    }

    const followsMe = await Follow.exists({
      follower: target._id,
      following: request.user._id,
    });
    response.json({
      followed: true,
      user: serializeFollowUser(target, {
        followedByMe: true,
        followsMe: Boolean(followsMe),
      }),
      me: publicUser(request.user),
    });
  } catch (error) {
    next(error);
  }
});

router.delete('/users/:id/follow', requireAuth, async (request, response, next) => {
  try {
    const target = await findUserOr404(request.params.id, response);
    if (!target) return;

    const existing = await Follow.findOne({
      follower: request.user._id,
      following: target._id,
    });
    if (existing) {
      await existing.deleteOne();
      request.user.following = Math.max(0, request.user.following - 1);
      target.followers = Math.max(0, target.followers - 1);
      await Promise.all([request.user.save(), target.save()]);
    }

    const followsMe = await Follow.exists({
      follower: target._id,
      following: request.user._id,
    });
    response.json({
      followed: false,
      user: serializeFollowUser(target, {
        followedByMe: false,
        followsMe: Boolean(followsMe),
      }),
      me: publicUser(request.user),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/me/likes-received', requireAuth, async (request, response, next) => {
  try {
    const myPosts = await Post.find({ author: request.user._id }).select('_id');
    const postIds = myPosts.map((post) => post._id);
    const likes = await Like.find({
      post: { $in: postIds },
      user: { $ne: request.user._id },
    })
      .populate('user')
      .populate('post')
      .sort({ createdAt: -1 })
      .lean();

    response.json({
      records: likes
        .filter((like) => like.user && like.post)
        .map((like) => ({
          id: String(like._id),
          user: publicUser(like.user),
          post: serializePost(like.post),
          actionText: '赞了你的帖子',
          createdAt: like.createdAt instanceof Date
            ? like.createdAt.toISOString()
            : like.createdAt,
        })),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/me/notifications', requireAuth, async (request, response, next) => {
  try {
    const category = String(request.query.category || '').trim();
    const filter = { recipient: request.user._id };
    if (category === 'interaction' || category === 'notice') {
      filter.category = category;
    }

    const notifications = await Notification.find(filter)
      .populate('actor')
      .populate('post')
      .populate('activity')
      .sort({ createdAt: -1 })
      .lean();

    response.json({
      notifications: notifications.map(serializeNotification),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/me/notifications/read-all', requireAuth, async (request, response, next) => {
  try {
    await Notification.updateMany(
      { recipient: request.user._id, unread: true },
      { $set: { unread: false } }
    );
    response.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

router.get('/me/conversations', requireAuth, async (request, response, next) => {
  try {
    const conversations = await Conversation.find({
      participants: request.user._id,
    })
      .populate('participants')
      .sort({ updatedAt: -1 })
      .lean();

    const unreadCounts = await Promise.all(
      conversations.map((conversation) =>
        Message.countDocuments({
          conversation: conversation._id,
          sender: { $ne: request.user._id },
          readBy: { $ne: request.user._id },
        })
      )
    );

    response.json({
      conversations: conversations.map((conversation, index) =>
        serializeConversation(conversation, request.user._id, unreadCounts[index])
      ),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/conversations/:id/messages', requireAuth, async (request, response, next) => {
  try {
    const conversation = await findConversationOr404(
      request.params.id,
      request.user._id,
      response
    );
    if (!conversation) return;

    await Message.updateMany(
      {
        conversation: conversation._id,
        sender: { $ne: request.user._id },
        readBy: { $ne: request.user._id },
      },
      { $addToSet: { readBy: request.user._id } }
    );

    const messages = await Message.find({ conversation: conversation._id })
      .populate('sender')
      .sort({ createdAt: 1 })
      .lean();

    response.json({
      conversation: serializeConversation(conversation, request.user._id),
      messages: messages.map((message) =>
        serializeMessage(message, request.user._id)
      ),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/conversations/:id/messages', requireAuth, async (request, response, next) => {
  try {
    const text = String(request.body.text || '').trim();
    if (!text) {
      response.status(400).json({ message: '消息内容不能为空' });
      return;
    }

    const conversation = await findConversationOr404(
      request.params.id,
      request.user._id,
      response
    );
    if (!conversation) return;

    const message = await Message.create({
      conversation: conversation._id,
      sender: request.user._id,
      text,
      readBy: [request.user._id],
    });
    conversation.lastMessage = text;
    await conversation.save();
    await message.populate('sender');

    response.status(201).json({
      message: serializeMessage(message, request.user._id),
      conversation: serializeConversation(conversation, request.user._id),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/me/groups', requireAuth, async (request, response, next) => {
  try {
    const memberships = await GroupMembership.find({ user: request.user._id })
      .populate({
        path: 'group',
        populate: [
          'activityIds',
          { path: 'discussionIds', populate: 'author' },
        ],
      })
      .sort({ updatedAt: -1 })
      .lean();

    response.json({
      groups: memberships
        .filter((membership) => membership.group)
        .map((membership) => ({
          ...serializeGroup(membership.group),
          joined: true,
          membershipRole: membership.role,
          membershipId: String(membership._id),
        })),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/groups/:id/join', requireAuth, async (request, response, next) => {
  try {
    const group = await findGroupOr404(request.params.id, response);
    if (!group) return;

    const existing = await GroupMembership.findOne({
      group: group._id,
      user: request.user._id,
    });
    if (!existing) {
      await GroupMembership.create({ group: group._id, user: request.user._id });
      group.members += 1;
      await group.save();
      await group.populate('activityIds');
      await group.populate({ path: 'discussionIds', populate: 'author' });
    }

    response.json({ joined: true, group: { ...serializeGroup(group), joined: true } });
  } catch (error) {
    next(error);
  }
});

router.delete('/groups/:id/join', requireAuth, async (request, response, next) => {
  try {
    const group = await findGroupOr404(request.params.id, response);
    if (!group) return;

    const existing = await GroupMembership.findOne({
      group: group._id,
      user: request.user._id,
    });
    if (existing) {
      await existing.deleteOne();
      group.members = Math.max(0, group.members - 1);
      await group.save();
      await group.populate('activityIds');
      await group.populate({ path: 'discussionIds', populate: 'author' });
    }

    response.json({ joined: false, group: { ...serializeGroup(group), joined: false } });
  } catch (error) {
    next(error);
  }
});

router.get('/groups/:id', async (request, response, next) => {
  try {
    const group = await findGroupOr404(request.params.id, response);
    if (!group) return;
    response.json({ group: serializeGroup(group) });
  } catch (error) {
    next(error);
  }
});

router.get('/topics/:id', async (request, response, next) => {
  try {
    const topic = await Topic.findById(request.params.id)
      .populate({ path: 'postIds', populate: 'author' })
      .populate('contributorIds');
    if (!topic) {
      response.status(404).json({ message: '话题不存在' });
      return;
    }
    response.json({ topic: serializeTopic(topic) });
  } catch (error) {
    next(error);
  }
});

router.get('/activities', async (_request, response, next) => {
  try {
    response.json(await fromMongoOrSeed(Activity, seed.activities));
  } catch (error) {
    next(error);
  }
});

router.get('/groups', async (_request, response, next) => {
  try {
    response.json(await fromMongoOrSeed(Group, seed.groups, {
      populate: ['activityIds', { path: 'discussionIds', populate: 'author' }],
    }));
  } catch (error) {
    next(error);
  }
});

router.get('/topics', async (_request, response, next) => {
  try {
    response.json(await fromMongoOrSeed(Topic, seed.topics, {
      populate: [
        { path: 'postIds', populate: 'author' },
        'contributorIds',
      ],
    }));
  } catch (error) {
    next(error);
  }
});

router.get('/feed', async (_request, response, next) => {
  try {
    response.json(await getFeedData());
  } catch (error) {
    next(error);
  }
});

router.get('/search', async (request, response, next) => {
  try {
    const query = String(request.query.q || '').trim().toLowerCase();
    const tokens = query.split(/\s+/).filter(Boolean);
    const includesQuery = (value) => {
      const normalized = String(value).toLowerCase();
      return tokens.some((token) => normalized.includes(token));
    };

    if (!query) {
      response.json({
        users: [],
        posts: [],
        activities: [],
        groups: [],
        topics: [],
      });
      return;
    }

    const feed = await getFeedData();

    response.json({
      users: feed.users.filter((user) =>
        [user.name, user.school, user.major, user.bio].some(includesQuery)
      ),
      posts: feed.posts.filter((post) =>
        [post.title, post.body, post.topic, post.location].some(includesQuery)
      ),
      activities: feed.activities.filter((activity) =>
        [activity.title, activity.category, activity.location, activity.host].some(includesQuery)
      ),
      groups: feed.groups.filter((group) =>
        [group.name, group.description, ...(group.tags || [])].some(includesQuery)
      ),
      topics: feed.topics.filter((topic) =>
        [topic.name, topic.description, ...(topic.relatedTopics || [])].some(includesQuery)
      ),
    });
  } catch (error) {
    next(error);
  }
});

router.use((error, _request, response, _next) => {
  console.error(error);
  response.status(500).json({
    message: 'Internal server error',
  });
});

module.exports = router;
