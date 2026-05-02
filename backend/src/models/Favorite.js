const mongoose = require('mongoose');

const favoriteSchema = new mongoose.Schema(
  {
    kind: {
      type: String,
      enum: ['post', 'activity'],
      default: 'post',
      index: true,
    },
    post: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', index: true },
    activity: { type: mongoose.Schema.Types.ObjectId, ref: 'Activity', index: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  },
  { timestamps: true }
);

favoriteSchema.index(
  { post: 1, user: 1 },
  { unique: true, partialFilterExpression: { post: { $exists: true } } }
);
favoriteSchema.index(
  { activity: 1, user: 1 },
  { unique: true, partialFilterExpression: { activity: { $exists: true } } }
);

module.exports = mongoose.model('Favorite', favoriteSchema);
