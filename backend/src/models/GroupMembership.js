const mongoose = require('mongoose');

const groupMembershipSchema = new mongoose.Schema(
  {
    group: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Group',
      required: true,
      index: true,
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    role: {
      type: String,
      enum: ['member', 'admin', 'owner'],
      default: 'member',
    },
  },
  { timestamps: true }
);

groupMembershipSchema.index({ group: 1, user: 1 }, { unique: true });

module.exports = mongoose.model('GroupMembership', groupMembershipSchema);
