from pathlib import Path
import re

DETAIL = Path("frontend/frontend/lib/screens/detail_pages.dart")
text = DETAIL.read_text()

# 1. 修复 _CommentTile 调用处，统一传 createdAt
text = re.sub(
    r"""_CommentTile\(
\s*user: comment\.author,
\s*text: comment\.text,
\s*likes: comment\.likes,
(?:\s*createdAt: comment\.createdAt,)?
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

# 2. 修复 _CommentTile 构造函数：增加 required this.createdAt
text = re.sub(
    r"""const _CommentTile\(\{
\s*required this\.user,
\s*required this\.text,
\s*required this\.likes,
\s*(?:this\.reply,\s*)?
\s*\}\);""",
    """const _CommentTile({
    required this.user,
    required this.text,
    required this.likes,
    required this.createdAt,
    this.reply,
  });""",
    text,
    count=1,
)

# 3. 修复字段：如果没有 createdAt 字段就补上
comment_class_start = text.find("class _CommentTile extends StatelessWidget")
if comment_class_start == -1:
    raise SystemExit("❌ 没找到 _CommentTile 类")

next_class = text.find("\nclass ", comment_class_start + 1)
if next_class == -1:
    next_class = len(text)

before = text[:comment_class_start]
block = text[comment_class_start:next_class]
after = text[next_class:]

if "final String createdAt;" not in block:
    block = block.replace(
        "  final int likes;\n",
        "  final int likes;\n  final String createdAt;\n",
        1,
    )

# 4. 修复写死评论时间
block = block.replace(
    "'05-20 14:45    回复'",
    "'${_detailFriendlyTime(createdAt)}    回复'",
)

# 5. 修复 const Text 调用动态方法的问题
block = block.replace(
    "const Text('${_detailFriendlyTime(createdAt)}    回复'",
    "Text('${_detailFriendlyTime(createdAt)}    回复'",
)
block = block.replace(
    "const Text(\n                  '${_detailFriendlyTime(createdAt)}    回复'",
    "Text(\n                  '${_detailFriendlyTime(createdAt)}    回复'",
)

text = before + block + after
DETAIL.write_text(text)
print("✅ 已修复 _CommentTile createdAt 参数和 const Text 问题")
