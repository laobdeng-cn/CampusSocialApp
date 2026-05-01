const mongoose = require('mongoose');

const enrollmentSchema = new mongoose.Schema(
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
    status: {
      type: String,
      enum: ['registered', 'cancelled'],
      default: 'registered',
      index: true,
    },
  },
  { timestamps: true }
);

enrollmentSchema.index({ activity: 1, user: 1 }, { unique: true });

module.exports = mongoose.model('Enrollment', enrollmentSchema);
