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


def find_matching(text: str, open_pos: int, open_ch: str, close_ch: str) -> int:
    depth = 0
    quote = None
    escape = False
    for i in range(open_pos, len(text)):
        ch = text[i]
        if quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            continue
        if ch in ("'", '"'):
            quote = ch
            continue
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return i
    return -1


def previous_non_ws(text: str, pos: int) -> int:
    i = pos - 1
    while i >= 0 and text[i].isspace():
        i -= 1
    return i


def next_non_ws(text: str, pos: int) -> int:
    i = pos
    while i < len(text) and text[i].isspace():
        i += 1
    return i


def find_start_of_widget_invocation(text: str, hit: int) -> int:
    # 向前找最近的 widget/function 调用开头，比如 _CommentTile( / Padding( / const _CommentTile(
    i = hit
    while i > 0:
        j = text.rfind("(", 0, i)
        if j < 0:
            break
        # 找调用名开头
        k = previous_non_ws(text, j)
        name_end = k + 1
        while k >= 0 and (text[k].isalnum() or text[k] == "_" or text[k] == "."):
            k -= 1
        name_start = k + 1
        # 允许前面有 const/new
        c = previous_non_ws(text, name_start)
        const_start = name_start
        if c >= 0:
            word_end = c + 1
            while c >= 0 and (text[c].isalpha() or text[c] == "_"):
                c -= 1
            word = text[c + 1:word_end]
            if word in ("const", "new"):
                const_start = c + 1
        name = text[name_start:name_end]
        if name.endswith(("Tile", "Card", "Comment", "Row", "View")) or name.startswith("_"):
            return const_start
        i = j
    # 保底：删到当前行开头
    return text.rfind("\n", 0, hit) + 1


def remove_widget_containing(text: str, keyword: str) -> tuple[str, int]:
    count = 0
    pos = 0
    while True:
        hit = text.find(keyword, pos)
        if hit < 0:
            break
        start = find_start_of_widget_invocation(text, hit)
        paren = text.find("(", start, hit + 1)
        if paren < 0:
            pos = hit + len(keyword)
            continue
        end_paren = find_matching(text, paren, "(", ")")
        if end_paren < 0:
            pos = hit + len(keyword)
            continue
        end = end_paren + 1
        # 吃掉后面的逗号和空白换行
        while end < len(text) and text[end].isspace():
            end += 1
        if end < len(text) and text[end] == ",":
            end += 1
        while end < len(text) and text[end] in " \t\r\n":
            end += 1
        text = text[:start] + text[end:]
        count += 1
        pos = start
    return text, count


def replace_comment_fallbacks(block: str) -> tuple[str, int]:
    changed = 0

    # 1. 常见变量兜底：final displayComments = _comments.isEmpty ? demo : _comments;
    patterns = [
        (
            r"final\s+([A-Za-z_]\w*)\s*=\s*_comments\.isEmpty\s*\?[\s\S]{0,1600}?:\s*_comments\s*;",
            r"final \1 = _comments;",
        ),
        (
            r"final\s+([A-Za-z_]\w*)\s*=\s*_comments\.isNotEmpty\s*\?\s*_comments\s*:[\s\S]{0,1600}?;",
            r"final \1 = _comments;",
        ),
        (
            r"final\s+([A-Za-z_]\w*)\s*=\s*_comments\.isEmpty\s*\?\s*const\s*<CampusComment>\[[\s\S]{0,2000}?\]\s*:\s*_comments\s*;",
            r"final \1 = _comments;",
        ),
    ]
    for pat, repl in patterns:
        block, n = re.subn(pat, repl, block)
        changed += n

    # 2. 直接 for 循环兜底。
    patterns2 = [
        (
            r"for\s*\(\s*final\s+([A-Za-z_]\w*)\s+in\s+_comments\.isEmpty\s*\?[\s\S]{0,1600}?:\s*_comments\s*\)",
            r"for (final \1 in _comments)",
        ),
        (
            r"for\s*\(\s*final\s+([A-Za-z_]\w*)\s+in\s+_comments\.isNotEmpty\s*\?\s*_comments\s*:[\s\S]{0,1600}?\)",
            r"for (final \1 in _comments)",
        ),
    ]
    for pat, repl in patterns2:
        block, n = re.subn(pat, repl, block)
        changed += n

    # 3. 如果演示评论是直接硬编码 widget，按名字精确移除。
    for name in ("陈可欣", "王子豪", "刘思雨"):
        block, n = remove_widget_containing(block, name)
        changed += n

    # 4. 更粗暴但安全地移除明显的“假评论常量列表”片段，只在详情页 state block 内。
    fake_phrases = [
        "我上周刚预约过",
        "入口找到了，超方便",
        "每天早上 8:00 可以预约",
        "推荐 3 楼和 5 楼的自习区",
    ]
    for phrase in fake_phrases:
        block, n = remove_widget_containing(block, phrase)
        changed += n

    return block, changed


def main() -> None:
    if not DETAIL.exists():
        print(f"❌ 找不到文件: {DETAIL}")
        sys.exit(1)

    text = DETAIL.read_text(encoding="utf-8")
    backup(DETAIL, ".bak_real_comments_v2")

    start, end = find_class_block(text, "_PostDetailScreenState")
    block = text[start:end]
    before = block

    block, changed = replace_comment_fallbacks(block)

    # 确保有空状态，但不能再继续渲染假评论。
    if "暂无真实评论" not in block:
        pos = block.find("全部评论")
        if pos >= 0:
            m = re.search(r"const\s+SizedBox\(height:\s*(?:8|10|12|14|16|18|20)\),", block[pos:])
            if m:
                insert_at = pos + m.end()
                empty = """
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
                block = block[:insert_at] + empty + block[insert_at:]
                changed += 1

    # 如果仍然存在三个演示人名，打印定位，便于手动收尾。
    remaining = [name for name in ("陈可欣", "王子豪", "刘思雨") if name in block]

    if block != before:
        text = text[:start] + block + text[end:]
        DETAIL.write_text(text, encoding="utf-8")
        print(f"✅ 已处理帖子详情演示评论残留，共修改 {changed} 处")
    else:
        print("⚠️ 本次没有改动，可能当前代码结构和预期不同。")

    if remaining:
        print(f"⚠️ 仍检测到演示评论关键词: {remaining}")
        print("请运行：")
        print("grep -n \"陈可欣\\|王子豪\\|刘思雨\\|我上周刚预约过\\|每天早上 8:00\" frontend/frontend/lib/screens/detail_pages.dart")
    else:
        print("✅ 已确认 PostDetailScreenState 内不再包含 陈可欣/王子豪/刘思雨 演示评论")

    print("✅ patch done")


if __name__ == "__main__":
    main()
