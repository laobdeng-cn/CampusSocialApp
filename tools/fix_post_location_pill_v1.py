from pathlib import Path

DETAIL = Path("frontend/frontend/lib/screens/detail_pages.dart")
text = DETAIL.read_text()

old = """          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Pill(
              label: post.location,
              icon: Icons.location_on,
              color: AppColors.blue,
            ),
          ),
"""

new = """          if (post.location.trim().isNotEmpty &&
              post.location.trim() != '图书馆广场') ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Pill(
                label: post.location.trim(),
                icon: Icons.location_on,
                color: AppColors.blue,
              ),
            ),
          ],
"""

if old not in text:
    print("⚠️ 没找到帖子详情位置 Pill 的精确代码块，请 grep post.location 再发我")
else:
    text = text.replace(old, new, 1)
    DETAIL.write_text(text)
    print("✅ 已修复：帖子详情页不再显示空位置 / 图书馆广场默认位置")
