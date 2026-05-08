from pathlib import Path

path = Path("frontend/frontend/lib/screens/main_shell.dart")
text = path.read_text()

bak = path.with_suffix(path.suffix + ".bak_fix_duplicate_didupdate")
bak.write_text(text)
print(f"✅ 已备份: {bak}")

class_sig = "class _PostFeedCardState extends State<PostFeedCard> {"
start = text.find(class_sig)
if start < 0:
    raise SystemExit("❌ 没找到 _PostFeedCardState")

brace = text.find("{", start)
depth = 0
end = -1
for i in range(brace, len(text)):
    if text[i] == "{":
        depth += 1
    elif text[i] == "}":
        depth -= 1
        if depth == 0:
            end = i + 1
            break

if end < 0:
    raise SystemExit("❌ 没找到 _PostFeedCardState 结束位置")

block = text[start:end]
target = "  void didUpdateWidget(covariant PostFeedCard oldWidget) {"

positions = []
idx = 0
while True:
    pos = block.find(target, idx)
    if pos < 0:
        break
    positions.append(pos)
    idx = pos + len(target)

print(f"找到 didUpdateWidget 数量: {len(positions)}")

if len(positions) <= 1:
    print("✅ 没有重复，无需处理")
else:
    methods = []
    for pos in positions:
        brace = block.find("{", pos)
        depth = 0
        method_end = -1
        for i in range(brace, len(block)):
            if block[i] == "{":
                depth += 1
            elif block[i] == "}":
                depth -= 1
                if depth == 0:
                    method_end = i + 1
                    break
        methods.append((pos, method_end, block[pos:method_end]))

    # 优先保留包含 _loadFavoriteStatus 的新版
    keep_index = None
    for i, (_, _, method) in enumerate(methods):
        if "_loadFavoriteStatus" in method:
            keep_index = i
            break

    if keep_index is None:
        keep_index = len(methods) - 1

    new_block = block
    for i in reversed(range(len(methods))):
        if i == keep_index:
            continue
        s, e, _ = methods[i]
        new_block = new_block[:s] + new_block[e:]

    text = text[:start] + new_block + text[end:]
    path.write_text(text)
    print(f"✅ 已删除重复 didUpdateWidget，保留第 {keep_index + 1} 个")

print("done")
