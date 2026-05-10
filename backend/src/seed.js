const dotenv = require('dotenv');
const mongoose = require('mongoose');

dotenv.config();

async function run() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    throw new Error('MONGODB_URI is not configured.');
  }

  await mongoose.connect(uri, { serverSelectionTimeoutMS: 3000 });
  console.log('Demo seed data has been removed. No records were inserted or deleted.');
}

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
