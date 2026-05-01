const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    username: { type: String, trim: true, unique: true, sparse: true },
    passwordHash: { type: String, default: '' },
    school: { type: String, required: true, trim: true },
    major: { type: String, required: true, trim: true },
    grade: { type: String, required: true, trim: true },
    avatarUrl: { type: String, required: true },
    bio: { type: String, default: '' },
    role: { type: String, default: '' },
    realName: { type: String, default: '' },
    studentId: { type: String, default: '' },
    campusName: { type: String, default: '' },
    campusVerified: { type: Boolean, default: false },
    campusRole: {
      type: String,
      enum: ['student', 'teacher', ''],
      default: '',
    },
    enrollmentYear: { type: String, default: '' },
    tokenVersion: { type: Number, default: 0 },
    followers: { type: Number, default: 0 },
    following: { type: Number, default: 0 },
    settings: {
      notifications: {
        messageReminder: { type: Boolean, default: true },
        activityNotice: { type: Boolean, default: true },
        systemNotice: { type: Boolean, default: true },
      },
      privacy: {
        allowSearch: { type: Boolean, default: true },
        blockStrangerComments: { type: Boolean, default: true },
        profileVisibility: { type: String, default: 'friends' },
        dmPermission: { type: String, default: 'friends_and_following' },
      },
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', userSchema);
