const mongoose = require('mongoose');

const postSchema = new mongoose.Schema(
  {
    author: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    group: { type: mongoose.Schema.Types.ObjectId, ref: 'Group', index: true },
    title: { type: String, required: true, trim: true },
    body: { type: String, required: true },
    topic: { type: String, required: true, index: true },
    images: [{ type: String }],
    location: { type: String, default: '' },
    likes: { type: Number, default: 0 },
    comments: { type: Number, default: 0 },
    saves: { type: Number, default: 0 },
    shares: { type: Number, default: 0 },
    visibility: {
      type: String,
      enum: ['public', 'friends', 'private'],
      default: 'public',
    },
    pinnedInGroup: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Post', postSchema);
