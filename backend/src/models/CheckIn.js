const mongoose = require('mongoose');

const checkInSchema = new mongoose.Schema(
  {
    activity: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Activity',
      required: true,
      index: true,
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    enrollment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Enrollment',
    },
    method: {
      type: String,
      enum: ['code'],
      default: 'code',
    },
    status: {
      type: String,
      enum: ['checked_in'],
      default: 'checked_in',
    },
    code: { type: String, default: '' },
  },
  { timestamps: true }
);

checkInSchema.index({ activity: 1, user: 1 }, { unique: true });

module.exports = mongoose.model('CheckIn', checkInSchema);
