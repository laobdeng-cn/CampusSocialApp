const crypto = require('crypto');
const express = require('express');

const { hashPassword } = require('../auth');
const { isMongoReady } = require('../db');
const PasswordResetCode = require('../models/PasswordResetCode');
const User = require('../models/User');

const router = express.Router();
const RESET_CODE_TTL_MS = 1000 * 60 * 10;
const MAX_RESET_ATTEMPTS = 5;

function normalizeUsername(value) {
  return String(value || '').trim();
}

function createResetCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function hashResetCode(username, code) {
  return crypto
    .createHmac('sha256', process.env.AUTH_TOKEN_SECRET || 'campus-social-local-dev-secret')
    .update(`${normalizeUsername(username)}:${String(code).trim()}`)
    .digest('hex');
}

function shouldExposeDevCode() {
  return process.env.NODE_ENV !== 'production';
}

router.post('/forgot-password', async (request, response, next) => {
  try {
    if (!isMongoReady()) {
      response.status(503).json({ message: 'MongoDB is required for password reset.' });
      return;
    }

    const username = normalizeUsername(request.body.username);
    if (!username) {
      response.status(400).json({ message: '请输入注册手机号' });
      return;
    }

    const user = await User.findOne({ username });
    if (!user) {
      response.json({
        ok: true,
        message: '如果该手机号已注册，验证码将发送到对应账号。',
      });
      return;
    }

    const code = createResetCode();
    await PasswordResetCode.updateMany(
      { user: user._id, consumedAt: null },
      { $set: { consumedAt: new Date() } }
    );
    await PasswordResetCode.create({
      user: user._id,
      username,
      codeHash: hashResetCode(username, code),
      expiresAt: new Date(Date.now() + RESET_CODE_TTL_MS),
    });

    console.log(`[password-reset] ${username} reset code: ${code}`);

    response.json({
      ok: true,
      message: shouldExposeDevCode()
        ? `验证码已生成：${code}`
        : '如果该手机号已注册，验证码将发送到对应账号。',
      devCode: shouldExposeDevCode() ? code : undefined,
      expiresInSeconds: RESET_CODE_TTL_MS / 1000,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/reset-password', async (request, response, next) => {
  try {
    if (!isMongoReady()) {
      response.status(503).json({ message: 'MongoDB is required for password reset.' });
      return;
    }

    const username = normalizeUsername(request.body.username);
    const code = String(request.body.code || '').trim();
    const password = String(request.body.password || '');

    if (!username || !code || !password) {
      response.status(400).json({ message: '手机号、验证码和新密码不能为空' });
      return;
    }
    if (password.length < 6) {
      response.status(400).json({ message: '新密码至少需要 6 位' });
      return;
    }

    const user = await User.findOne({ username });
    if (!user) {
      response.status(400).json({ message: '验证码无效或已过期' });
      return;
    }

    const resetRecord = await PasswordResetCode.findOne({
      user: user._id,
      username,
      consumedAt: null,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    if (!resetRecord) {
      response.status(400).json({ message: '验证码无效或已过期' });
      return;
    }
    if (resetRecord.attempts >= MAX_RESET_ATTEMPTS) {
      resetRecord.consumedAt = new Date();
      await resetRecord.save();
      response.status(400).json({ message: '验证码错误次数过多，请重新获取' });
      return;
    }

    const expectedHash = hashResetCode(username, code);
    if (resetRecord.codeHash !== expectedHash) {
      resetRecord.attempts += 1;
      await resetRecord.save();
      response.status(400).json({ message: '验证码错误' });
      return;
    }

    user.passwordHash = hashPassword(password);
    user.tokenVersion += 1;
    resetRecord.consumedAt = new Date();

    await Promise.all([user.save(), resetRecord.save()]);

    response.json({ ok: true, message: '密码已重置，请使用新密码登录' });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
