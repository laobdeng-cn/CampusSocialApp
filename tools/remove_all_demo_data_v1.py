from pathlib import Path

SERVER = Path("backend/src/server.js")
text = SERVER.read_text()

old = """connectToMongo()
  .then(seedDemoData)
  .catch((error) => {
    console.warn(`Demo data seed skipped. ${error.message}`);
  })
  .finally(() => {
    app.listen(port, () => {
      console.log(`Campus Social API listening on http://localhost:${port}`);
    });
  });
"""

new = """connectToMongo()
  .then(async () => {
    if (process.env.ENABLE_DEMO_SEED === 'true') {
      await seedDemoData();
    } else {
      console.log('Demo data seed disabled.');
    }
  })
  .catch((error) => {
    console.warn(`MongoDB initialization warning. ${error.message}`);
  })
  .finally(() => {
    app.listen(port, () => {
      console.log(`Campus Social API listening on http://localhost:${port}`);
    });
  });
"""

if old in text:
    SERVER.write_text(text.replace(old, new))
    print("✅ 已关闭默认自动注入演示数据：只有 ENABLE_DEMO_SEED=true 才会 seed")
else:
    print("⚠️ server.js 启动 seed 代码未匹配，可能已经改过，跳过")
