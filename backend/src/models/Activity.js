const mongoose = require('mongoose');
const crypto = require('crypto');

function generateCheckInCode() {
  return crypto.randomInt(100000, 1000000).toString();
}

const activitySchema = new mongoose.Schema(
  {
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    group: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Group',
      index: true,
    },
    title: { type: String, required: true, trim: true },
    category: { type: String, required: true, index: true },
    posterUrl: { type: String, required: true },
    images: [{ type: String }],
    date: { type: String, required: true },
    time: { type: String, required: true },
    location: { type: String, required: true },
    host: { type: String, required: true },
    enrolled: { type: Number, default: 0 },
    capacity: { type: Number, default: 0 },
    price: { type: String, default: '免费' },
    description: { type: String, default: '' },
    checkInCode: { type: String, default: generateCheckInCode, trim: true },
    allowComments: { type: Boolean, default: true },
    publicDisplay: { type: Boolean, default: true },
    registrationDeadline: { type: String, default: '' },
    tags: [{ type: String }],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Activity', activitySchema);
