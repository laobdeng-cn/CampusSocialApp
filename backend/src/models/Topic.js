const mongoose = require('mongoose');

const topicSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, unique: true, trim: true },
    coverUrl: { type: String, default: '' },
    description: { type: String, default: '' },
    discussions: { type: String, default: '0' },
    onlineCount: { type: Number, default: 0 },
    postIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],
    contributorIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    relatedTopics: [{ type: String }],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Topic', topicSchema);
