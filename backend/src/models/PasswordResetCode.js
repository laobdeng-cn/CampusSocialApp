const mongoose = require('mongoose');

const passwordResetCodeSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    username: { type: String, required: true, trim: true, index: true },
    codeHash: { type: String, required: true },
    attempts: { type: Number, default: 0 },
    consumedAt: { type: Date, default: null },
    expiresAt: { type: Date, required: true, expires: 0 },
  },
  { timestamps: true }
);

passwordResetCodeSchema.index({ user: 1, createdAt: -1 });
passwordResetCodeSchema.index({ username: 1, createdAt: -1 });

module.exports = mongoose.model('PasswordResetCode', passwordResetCodeSchema);
