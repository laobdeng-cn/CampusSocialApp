from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_chat_emoji_panel_codepoints_v3")
if not bak.exists():
    bak.write_text(text)

# 1. ChatScreenState 里只保留一个表情面板调用
chat_start = text.find("class _ChatScreenState extends State<ChatScreen> {")
chat_end = text.find("\nclass _ChatHeader", chat_start)

if chat_start == -1 or chat_end == -1:
    raise SystemExit("❌ 没找到 _ChatScreenState / _ChatHeader")

chat = text[chat_start:chat_end]

# 删除 ChatScreenState 内所有表情面板调用
chat = re.sub(
    r"\s*if \(_showEmojiPanel\)\s*\n\s*_ChatEmojiPanel\(onEmojiSelected: _insertEmoji\),",
    "",
    chat,
)

# 在 _ChatInputBar 前插入唯一一个
input_pos = chat.find("          _ChatInputBar(")
if input_pos == -1:
    raise SystemExit("❌ ChatScreenState 里没找到 _ChatInputBar 调用")

chat = (
    chat[:input_pos]
    + "          if (_showEmojiPanel)\n"
      "            _ChatEmojiPanel(onEmojiSelected: _insertEmoji),\n"
    + chat[input_pos:]
)

text = text[:chat_start] + chat + text[chat_end:]

# 2. 删除所有旧的 _ChatEmojiPanel 定义
while True:
    panel_start = text.find("class _ChatEmojiPanel extends StatelessWidget {")
    if panel_start == -1:
        break

    panel_end = text.find("\nclass _ChatInputBar extends StatelessWidget {", panel_start)
    if panel_end == -1:
        raise SystemExit("❌ 找到 _ChatEmojiPanel，但没找到后面的 _ChatInputBar")

    text = text[:panel_start] + text[panel_end:]

# 3. 插入新的 codePoint 版本表情面板
input_start = text.find("class _ChatInputBar extends StatelessWidget {")
if input_start == -1:
    raise SystemExit("❌ 没找到 _ChatInputBar")

new_panel = r'''class _ChatEmojiPanel extends StatelessWidget {
  const _ChatEmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const _emojiCodePoints = [
    0x1F600, 0x1F603, 0x1F604, 0x1F601, 0x1F606, 0x1F602, 0x1F923, 0x1F60A,
    0x1F60D, 0x1F618, 0x1F970, 0x1F60E, 0x1F914, 0x1F633, 0x1F62D, 0x1F621,
    0x1F44D, 0x1F44F, 0x1F64F, 0x1F4AA, 0x1F525, 0x1F389, 0x2728, 0x2B50,
    0x1F4DA, 0x1F3A7, 0x1F3C0, 0x26BD, 0x1F3AE, 0x1F4F7, 0x2615, 0x1F35A,
    0x1F634, 0x1F605, 0x1F60B, 0x1F91D, 0x1F44C, 0x1F64C, 0x1F44B, 0x1F609,
  ];

  String _emojiAt(int index) {
    return String.fromCharCode(_emojiCodePoints[index]);
  }

  static const _emojiTextStyle = TextStyle(
    fontSize: 25,
    height: 1,
    fontFamilyFallback: [
      '.AppleSystemUIFont',
      'Apple Color Emoji',
      'Noto Color Emoji',
      'Segoe UI Emoji',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 248,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text(
                    '常用表情',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '点击插入',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                itemCount: _emojiCodePoints.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final emoji = _emojiAt(index);
                  return Material(
                    color: const Color(0xFFF5F8FC),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onEmojiSelected(emoji),
                      child: Center(
                        child: Text(
                          emoji,
                          textAlign: TextAlign.center,
                          style: _emojiTextStyle,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

'''

text = text[:input_start] + new_panel + text[input_start:]

# 4. 输入框 TextField 也加 emoji 字体 fallback，避免插入后还是方框
text = text.replace(
    "decoration: const InputDecoration(\n                        hintText: '输入消息...',",
    "style: const TextStyle(\n                        fontFamilyFallback: [\n                          '.AppleSystemUIFont',\n                          'Apple Color Emoji',\n                          'Noto Color Emoji',\n                          'Segoe UI Emoji',\n                        ],\n                      ),\n                      decoration: const InputDecoration(\n                        hintText: '输入消息...',",
    1,
)

MAIN.write_text(text)
print("✅ 已修复：表情面板去重 + emoji 改为 codePoint 生成 + 输入框增加 emoji 字体 fallback")
