const mongoose = require('mongoose');

const groupSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    coverUrl: { type: String, required: true },
    iconUrl: { type: String, default: '' },
    members: { type: Number, default: 0 },
    admins: { type: Number, default: 0 },
    tags: [{ type: String }],
    announcementText: { type: String, default: '' },
    announcementUpdatedAt: { type: Date },
    announcementUpdatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    pinnedDiscussionIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],
    activityIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Activity' }],
    discussionIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],
    visibility: {
      type: String,
      enum: ['public', 'approval', 'private'],
      default: 'approval',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Group', groupSchema);
