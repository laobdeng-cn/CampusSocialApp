const mongoose = require('mongoose');

async function connectToMongo() {
  const uri = process.env.MONGODB_URI;

  if (!uri) {
    console.log('MONGODB_URI is not set. API will serve mock data.');
    return;
  }

  mongoose.set('strictQuery', true);

  try {
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 3000,
    });
    console.log('MongoDB connected.');
  } catch (error) {
    console.warn(`MongoDB unavailable. API will serve mock data. ${error.message}`);
  }
}

function isMongoReady() {
  return mongoose.connection.readyState === 1;
}

module.exports = {
  connectToMongo,
  isMongoReady,
};
