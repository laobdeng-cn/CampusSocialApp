const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema(
  {
    kind: {
      type: String,
      enum: ['post', 'activity'],
      default: 'post',
      index: true,
    },
    post: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Post',
      index: true,
    },
    activity: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Activity',
      index: true,
    },
    author: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    text: { type: String, required: true, trim: true },
    likes: { type: Number, default: 0 },
  },
  { timestamps: true }
);

commentSchema.pre('validate', function validateCommentTarget(next) {
  if (!this.post && !this.activity) {
    next(new Error('评论必须关联帖子或活动'));
    return;
  }
  if (this.post && this.activity) {
    next(new Error('评论不能同时关联帖子和活动'));
    return;
  }
  this.kind = this.activity ? 'activity' : 'post';
  next();
});

commentSchema.index({ post: 1, createdAt: -1 });
commentSchema.index({ activity: 1, createdAt: -1 });

module.exports = mongoose.model('Comment', commentSchema);
