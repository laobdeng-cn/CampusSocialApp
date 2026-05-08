#!/usr/bin/env python3
from pathlib import Path
import re
import shutil
import sys

PROJECT = Path.home() / "Desktop" / "CampusSocialApp"
DETAIL = PROJECT / "frontend/frontend/lib/screens/detail_pages.dart"


def backup(path: Path, suffix: str) -> None:
    bak = path.with_name(path.name + suffix)
    if not bak.exists():
        shutil.copy2(path, bak)
        print(f"✅ 已备份: {bak}")
    else:
        print(f"ℹ️ 备份已存在: {bak}")


def find_class_block(text: str, class_name: str) -> tuple[int, int]:
    start = text.find(f"class {class_name}")
    if start < 0:
        raise RuntimeError(f"找不到 class {class_name}")
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"找不到 class {class_name} 的开始括号")

    depth = 0
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1
    raise RuntimeError(f"找不到 class {class_name} 的结束括号")


def main() -> None:
    if not DETAIL.exists():
        print(f"❌ 找不到文件: {DETAIL}")
        sys.exit(1)

    text = DETAIL.read_text(encoding="utf-8")
    backup(DETAIL, ".bak_real_comments_v1")

    start, end = find_class_block(text, "_PostDetailScreenState")
    block = text[start:end]
    original = block
    changed = 0

    patterns = [
        (
            r"final\s+(\w+)\s*=\s*_comments\.isEmpty\s*\?\s*[^;\n]+?\s*:\s*_comments\s*;",
            r"final \1 = _comments;",
        ),
        (
            r"final\s+(\w+)\s*=\s*_comments\.isNotEmpty\s*\?\s*_comments\s*:\s*[^;\n]+?\s*;",
            r"final \1 = _comments;",
        ),
        (
            r"final\s+(\w+)\s*=\s*_comments\.isEmpty\s*\?\s*<CampusComment>\[[\s\S]*?\]\s*:\s*_comments\s*;",
            r"final \1 = _comments;",
        ),
    ]

    for pattern, repl in patterns:
        block, n = re.subn(pattern, repl, block)
        changed += n

    loop_patterns = [
        (
            r"for\s*\(\s*final\s+(\w+)\s+in\s+_comments\.isEmpty\s*\?\s*[^)\n]+?\s*:\s*_comments\s*\)",
            r"for (final \1 in _comments)",
        ),
        (
            r"for\s*\(\s*final\s+(\w+)\s+in\s+_comments\.isNotEmpty\s*\?\s*_comments\s*:\s*[^)\n]+?\s*\)",
            r"for (final \1 in _comments)",
        ),
    ]

    for pattern, repl in loop_patterns:
        block, n = re.subn(pattern, repl, block)
        changed += n

    old_comment = "// Static fallback comments remain below if the backend is unavailable."
    if old_comment in block:
        block = block.replace(
            old_comment,
            "// 不再展示演示评论：接口为空就展示空状态，避免真实帖子下面混入假评论。",
        )
        changed += 1

    if "暂无真实评论" not in block:
        comment_title_pos = block.find("全部评论")
        if comment_title_pos >= 0:
            m = re.search(r"const\s+SizedBox\(height:\s*(?:12|14|16|18|20)\),", block[comment_title_pos:])
            if m:
                insert_at = comment_title_pos + m.end()
                empty_widget = """

          if (!_isLoadingComments && _comments.isEmpty)
            CampusCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mode_comment_outlined,
                        color: AppColors.muted,
                        size: 34,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '暂无真实评论',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '发布第一条评论后，会显示在这里',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),"""
                block = block[:insert_at] + empty_widget + block[insert_at:]
                changed += 1

    if block == original:
        print("⚠️ 没有自动命中演示评论 fallback 写法。")
        print("请把下面命令输出发给我，我按你的真实代码位置继续补：")
        print("grep -n \"全部评论\\|_comments.isEmpty\\|fallback\\|sample\\|_Comment\" frontend/frontend/lib/screens/detail_pages.dart | head -180")
    else:
        text = text[:start] + block + text[end:]
        DETAIL.write_text(text, encoding="utf-8")
        print(f"✅ 已改为帖子详情只展示真实评论，不再用演示评论兜底，共修改 {changed} 处")

    print("✅ patch done")


if __name__ == "__main__":
    main()
