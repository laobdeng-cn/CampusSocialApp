from pathlib import Path
import re

DETAIL = Path("frontend/frontend/lib/screens/detail_pages.dart")
text = DETAIL.read_text()

# 1. 调用 _CommentTile 时传入真实评论 createdAt
before = text
text = re.sub(
    r"""_CommentTile\(
\s*user: comment\.author,
\s*text: comment\.text,
\s*likes: comment\.likes,
\s*\)""",
    """_CommentTile(
                user: comment.author,
                text: comment.text,
                likes: comment.likes,
                createdAt: comment.createdAt,
              )""",
    text,
    count=1,
)

# 2. _CommentTile 构造函数增加 createdAt
text = text.replace(
    """  const _CommentTile({
    required this.user,
    required this.text,
    required this.likes,
  });
""",
    """  const _CommentTile({
    required this.user,
    required this.text,
    required this.likes,
    required this.createdAt,
  });
""",
    1,
)

# 3. _CommentTile 字段增加 createdAt
text = text.replace(
    """  final String text;
  final int likes;
""",
    """  final String text;
  final int likes;
  final String createdAt;
""",
    1,
)

# 4. 替换写死评论时间
text = text.replace(
    "'05-20 14:45    回复'",
    "'${_detailFriendlyTime(createdAt)}    回复'",
)

text = text.replace(
    "const Text('${_detailFriendlyTime(createdAt)}    回复'",
    "Text('${_detailFriendlyTime(createdAt)}    回复'",
)

DETAIL.write_text(text)

if before == text:
    print("⚠️ 没有替换到内容，请把 _CommentTile 5193-5265 发我")
else:
    print("✅ 已修复评论时间：_CommentTile 使用 comment.createdAt")
