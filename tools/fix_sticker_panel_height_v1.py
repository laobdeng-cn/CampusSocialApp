from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_sticker_panel_height_v1")
if not bak.exists():
    bak.write_text(text)

start = text.find("class _ChatEmojiPanel extends StatelessWidget")
end = text.find("class _ChatInputBar extends StatelessWidget", start)

if start == -1 or end == -1:
    raise SystemExit("❌ 没找到 _ChatEmojiPanel 或 _ChatInputBar")

before = text[:start]
panel = text[start:end]
after = text[end:]

# 1. 面板稍微压低高度，避免占据过多聊天区
panel = panel.replace("height: 236,", "height: 210,")

# 2. 面板在输入栏上方，不需要再吃底部 SafeArea
panel = panel.replace(
    "SafeArea(\n        top: false,",
    "SafeArea(\n        top: false,\n        bottom: false,",
)

# 3. 缩小一点表情卡间距和卡片纵向高度
panel = panel.replace(
    "mainAxisSpacing: 10,\n                  crossAxisSpacing: 10,\n                  childAspectRatio: 0.86,",
    "mainAxisSpacing: 8,\n                  crossAxisSpacing: 8,\n                  childAspectRatio: 0.98,",
)

# 4. 缩小图标圆和文字间距
panel = panel.replace("width: 38,", "width: 34,")
panel = panel.replace("height: 38,", "height: 34,")
panel = panel.replace("size: 23,", "size: 21,")
panel = panel.replace("const SizedBox(height: 6),", "const SizedBox(height: 4),")
panel = panel.replace("fontSize: 12,", "fontSize: 11.5,")

text = before + panel + after
MAIN.write_text(text)

print("✅ 已修复：表情面板高度、安全区和卡片间距")
