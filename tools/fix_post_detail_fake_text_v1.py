from pathlib import Path

DETAIL = Path("frontend/frontend/lib/screens/detail_pages.dart")

text = DETAIL.read_text()

# 1. 删除帖子详情页写死的“想知道...”演示文案
old_block = """          const SizedBox(height: 16),
          Text(
            '想知道：\\n1. 通过哪个入口预约？是否需要学校账号登录？\\n2. 每天几点可以预约？能预约多久的时段？\\n3. 选座有没有什么小技巧？热门区域容易抢吗？',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
"""

if old_block in text:
    text = text.replace(old_block, "", 1)
    print("✅ 已删除帖子详情页写死的“想知道...”演示文案")
else:
    print("⚠️ 没找到精确的“想知道...”代码块，尝试按关键词检查")
    if "想知道：" in text:
        print("⚠️ 文件里仍存在“想知道：”，请手动搜索删除")
    else:
        print("✅ 文件里没有“想知道：”")

# 2. 发布帖子页不要默认填“图书馆广场”，否则不填位置也会显示假位置
old_location = "final _locationController = TextEditingController(text: '图书馆广场');"
new_location = "final _locationController = TextEditingController();"

if old_location in text:
    text = text.replace(old_location, new_location, 1)
    print("✅ 已去掉发布页默认位置：图书馆广场")
else:
    print("ℹ️ 没找到默认位置代码，可能之前已经改过")

DETAIL.write_text(text)
