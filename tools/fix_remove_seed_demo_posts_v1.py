from pathlib import Path
import re

ROUTES = Path("backend/src/routes/index.js")

text = ROUTES.read_text()

old = """async function fromMongoOrSeed(model, seedData, options = {}) {
  if (!isMongoReady()) return seedData;

  const query = model.find();

  if (options.populate) {
    query.populate(options.populate);
  }

  const docs = await query.sort({ createdAt: -1 }).lean();
  if (docs.length === 0) return seedData;
  if (model.modelName === 'User') return docs.map(publicUser);
  if (model.modelName === 'Post') return docs.map(serializePost);
  if (model.modelName === 'Activity') return docs.map(serializeActivity);
  if (model.modelName === 'Group') return docs.map(serializeGroup);
  if (model.modelName === 'Topic') return docs.map(serializeTopic);
  return docs;
}
"""

new = """async function fromMongoOrSeed(model, seedData, options = {}) {
  // 只在 MongoDB 没连接时使用前端演示 seed。
  // 只要 MongoDB 已连接，就必须以数据库真实数据为准。
  // 否则删除完演示帖子后，/api/feed 又会把 seed 数据刷回来。
  if (!isMongoReady()) return seedData;

  const query = model.find();

  if (options.populate) {
    query.populate(options.populate);
  }

  const docs = await query.sort({ createdAt: -1 }).lean();

  if (model.modelName === 'User') return docs.map(publicUser);
  if (model.modelName === 'Post') return docs.map(serializePost);
  if (model.modelName === 'Activity') return docs.map(serializeActivity);
  if (model.modelName === 'Group') return docs.map(serializeGroup);
  if (model.modelName === 'Topic') return docs.map(serializeTopic);
  return docs;
}
"""

if old not in text:
    print("⚠️ 没找到旧版 fromMongoOrSeed，可能已经改过，跳过后端 fallback 修复")
else:
    text = text.replace(old, new)
    ROUTES.write_text(text)
    print("✅ 已修复后端：MongoDB 已连接时不再返回 seed 演示数据")
