from pathlib import Path
import re

DETAIL = Path("frontend/frontend/lib/screens/detail_pages.dart")
text = DETAIL.read_text()

# 确保时间格式函数存在
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
  if (diff.inHours < 24 && now.year == time.year && now.month == time.month && now.day == time.day) {
    return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 7) return '${diff.inDays}天前';

  return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

"""

if "_detailFriendlyTime" not in text:
    text = text.replace(marker, marker + helper, 1)
    print("✅ 已添加 _detailFriendlyTime")

# 重点：把评论组件里写死的 05-20 14:45 替换成真实 comment.createdAt
before = text

text = text.replace(
    "const Text('05-20 14:45'",
    "Text(_detailFriendlyTime(comment.createdAt)"
)

text = text.replace(
    "Text('05-20 14:45'",
    "Text(_detailFriendlyTime(comment.createdAt)"
)

text = text.replace(
    "'05-20 14:45'",
    "_detailFriendlyTime(comment.createdAt)"
)

changed = before != text
DETAIL.write_text(text)

print("✅ 已替换评论固定时间" if changed else "⚠️ 没找到 05-20 14:45，请 grep 后发我")
