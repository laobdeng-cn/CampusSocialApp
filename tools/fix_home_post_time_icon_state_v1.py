from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

# 1. 增加首页通用时间格式化函数
marker = """String _shellError(Object error) {
  final text = error.toString();
  const marker = 'CampusApiException: ';
  if (text.startsWith(marker)) return text.substring(marker.length);
  return '操作失败，请确认后端服务已启动';
}
"""

helper = r"""
String _shellFriendlyTime(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '刚刚';

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final time = parsed.toLocal();
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 &&
      now.year == time.year &&
      now.month == time.month &&
      now.day == time.day) {
    return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 7) return '${diff.inDays}天前';

  return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

"""

if "_shellFriendlyTime" not in text:
    text = text.replace(marker, marker + helper, 1)
    print("✅ 已添加首页时间格式化函数")
else:
    print("ℹ️ 首页时间格式化函数已存在")

# 2. 首页 PostFeedCard：初始化图标状态
text = text.replace(
    """  late CampusPost _post = widget.post;
  var _liked = false;
  var _favorited = false;
""",
    """  late CampusPost _post = widget.post;
  late var _liked = widget.post.likes > 0;
  late var _favorited = widget.post.saves > 0;
""",
    1,
)

# 3. 修复 didUpdateWidget：刷新/重新进入后同步图标状态
pattern = r"""@override
\s*void didUpdateWidget\(covariant PostFeedCard oldWidget\) \{
.*?\n\s*\}"""

replacement = """@override
  void didUpdateWidget(covariant PostFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likes != widget.post.likes ||
        oldWidget.post.saves != widget.post.saves) {
      _post = widget.post;
      _liked = widget.post.likes > 0;
      _favorited = widget.post.saves > 0;
    }
  }"""

if "void didUpdateWidget(covariant PostFeedCard oldWidget)" in text:
    text = re.sub(pattern, replacement, text, count=1, flags=re.S)
    print("✅ 已修复 PostFeedCard didUpdateWidget 状态同步")
else:
    insert_after = """  var _isFavoriting = false;
"""
    text = text.replace(insert_after, insert_after + "\n" + replacement + "\n", 1)
    print("✅ 已新增 PostFeedCard didUpdateWidget 状态同步")

# 4. 首页帖子时间：post.createdAt -> _shellFriendlyTime(post.createdAt)
text = text.replace(
    """Text(
                      post.createdAt,""",
    """Text(
                      _shellFriendlyTime(post.createdAt),""",
)

text = text.replace(
    """Text(post.createdAt,""",
    """Text(_shellFriendlyTime(post.createdAt),""",
)

MAIN.write_text(text)
print("✅ 首页帖子时间 + 爱心/收藏图标状态补丁完成")
