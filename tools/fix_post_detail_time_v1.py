from pathlib import Path

DETAIL = Path("frontend/frontend/lib/screens/detail_pages.dart")
text = DETAIL.read_text()

# 1. 在 _friendlyError 后面加一个详情页时间格式化函数
marker = """String _friendlyError(Object error) {
  final text = error.toString();
  const marker = 'CampusApiException: ';
  if (text.startsWith(marker)) return text.substring(marker.length);
  return '操作失败，请确认后端服务已启动';
}
"""

helper = r"""
String _detailFriendlyTime(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '刚刚';

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final time = parsed.toLocal();
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 && now.day == time.day) {
    return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 7) return '${diff.inDays}天前';

  return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

"""

if marker in text and "_detailFriendlyTime" not in text:
    text = text.replace(marker, marker + helper, 1)
    print("✅ 已添加详情页时间格式化函数")
else:
    print("ℹ️ 时间格式化函数可能已存在，跳过添加")

# 2. 帖子详情顶部时间
text = text.replace(
    "'${post.createdAt} · 来自 社区'",
    "'${_detailFriendlyTime(post.createdAt)} · 来自 社区'",
)

# 3. 评论时间：把常见 comment.createdAt 直接显示改成友好时间
text = text.replace(
    "comment.createdAt,",
    "_detailFriendlyTime(comment.createdAt),",
)

# 4. 如果还存在 Text(comment.createdAt)，也替换
text = text.replace(
    "Text(comment.createdAt",
    "Text(_detailFriendlyTime(comment.createdAt)",
)

DETAIL.write_text(text)
print("✅ 帖子详情时间格式收尾补丁完成")
