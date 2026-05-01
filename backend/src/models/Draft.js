const mongoose = require('mongoose');

const draftSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    kind: {
      type: String,
      enum: ['post', 'activity'],
      default: 'post',
    },
    title: { type: String, required: true, trim: true },
    body: { type: String, default: '', trim: true },
    topic: { type: String, default: '校园生活', trim: true },
    location: { type: String, default: '', trim: true },
    images: { type: [String], default: [] },
    status: {
      type: String,
      enum: ['draft', 'pending'],
      default: 'draft',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Draft', draftSchema);
