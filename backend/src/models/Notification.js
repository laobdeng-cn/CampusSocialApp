const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    actor: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    post: { type: mongoose.Schema.Types.ObjectId, ref: 'Post' },
    activity: { type: mongoose.Schema.Types.ObjectId, ref: 'Activity' },
    category: {
      type: String,
      enum: ['interaction', 'notice'],
      required: true,
      index: true,
    },
    title: { type: String, required: true, trim: true },
    firstLine: { type: String, required: true, trim: true },
    secondLine: { type: String, default: '' },
    action: { type: String, default: '' },
    unread: { type: Boolean, default: true, index: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Notification', notificationSchema);
