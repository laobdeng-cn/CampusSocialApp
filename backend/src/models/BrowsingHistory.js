const mongoose = require('mongoose');

const browsingHistorySchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    kind: {
      type: String,
      enum: ['post', 'activity', 'group', 'topic', 'user'],
      required: true,
    },
    refId: { type: mongoose.Schema.Types.ObjectId, index: true },
    title: { type: String, required: true, trim: true },
    subtitle: { type: String, default: '', trim: true },
    imageUrl: { type: String, default: '' },
  },
  { timestamps: true }
);

browsingHistorySchema.index({ user: 1, kind: 1, refId: 1 });

module.exports = mongoose.model('BrowsingHistory', browsingHistorySchema);
