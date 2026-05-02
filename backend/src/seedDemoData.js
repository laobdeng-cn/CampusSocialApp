const { isMongoReady } = require('./db');
const Activity = require('./models/Activity');
const User = require('./models/User');
const seed = require('./data/seed');

async function seedDemoData() {
  if (!isMongoReady()) {
    console.log('MongoDB is not ready. Skip demo data seeding.');
    return;
  }

  const userIdMap = new Map();

  for (const seedUser of seed.users) {
    const username = `seed_${seedUser.id}`;
    const user = await User.findOneAndUpdate(
      { username },
      {
        $setOnInsert: {
          username,
          name: seedUser.name,
          school: seedUser.school,
          major: seedUser.major,
          grade: seedUser.grade,
          avatarUrl: seedUser.avatarUrl,
          bio: seedUser.bio || '这个同学还没有填写简介。',
          role: seedUser.role || '',
          passwordHash: '',
          campusVerified: true,
        },
      },
      { new: true, upsert: true }
    );
    userIdMap.set(seedUser.id, user._id);
  }

  const fallbackCreator = [...userIdMap.values()][0];
  if (!fallbackCreator) {
    console.log('No demo user available. Skip activity seeding.');
    return;
  }

  let createdCount = 0;
  for (const seedActivity of seed.activities) {
    const exists = await Activity.findOne({ title: seedActivity.title });
    if (exists) continue;

    const creator = userIdMap.get(seedActivity.guestIds?.[0]) || fallbackCreator;
    await Activity.create({
      createdBy: creator,
      title: seedActivity.title,
      category: seedActivity.category,
      posterUrl: seedActivity.posterUrl,
      date: seedActivity.date,
      time: seedActivity.time,
      location: seedActivity.location,
      host: seedActivity.host,
      enrolled: Number(seedActivity.enrolled || 0),
      capacity: Number(seedActivity.capacity || 0),
      price: seedActivity.price || '免费',
      description: seedActivity.description || '',
      highlights: seedActivity.highlights || [],
      tags: seedActivity.tags || [],
      checkInCode: seedActivity.checkInCode || 'MUSIC2026',
      allowComments: true,
      publicDisplay: true,
    });
    createdCount += 1;
  }

  if (createdCount > 0) {
    console.log(`Seeded ${createdCount} demo activities into MongoDB.`);
  } else {
    console.log('Demo activities already exist in MongoDB.');
  }
}

module.exports = { seedDemoData };
