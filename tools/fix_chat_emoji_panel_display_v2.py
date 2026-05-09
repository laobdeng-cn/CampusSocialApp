from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_chat_emoji_panel_display_v2")
if not bak.exists():
    bak.write_text(text)

# 1. ChatScreen 底部只保留一个 _ChatEmojiPanel
chat_start = text.find("class _ChatScreenState extends State<ChatScreen> {")
chat_end = text.find("\nclass _ChatHeader", chat_start)

if chat_start == -1 or chat_end == -1:
    raise SystemExit("❌ 没找到 _ChatScreenState 区域")

chat = text[chat_start:chat_end]

# 删除连续/重复的 if (_showEmojiPanel) _ChatEmojiPanel(...)
chat = re.sub(
    r"(?:\s*if \(_showEmojiPanel\)\s*\n\s*_ChatEmojiPanel\(onEmojiSelected: _insertEmoji\),\s*)+",
    "\n          if (_showEmojiPanel)\n            _ChatEmojiPanel(onEmojiSelected: _insertEmoji),\n",
    chat,
)

text = text[:chat_start] + chat + text[chat_end:]

# 2. 重写 _ChatEmojiPanel，修复 emoji 字体显示
panel_start = text.find("class _ChatEmojiPanel extends StatelessWidget {")
panel_end = text.find("\nclass _ChatInputBar extends StatelessWidget {", panel_start)

if panel_start == -1 or panel_end == -1:
    raise SystemExit("❌ 没找到 _ChatEmojiPanel 或 _ChatInputBar")

new_panel = r'''class _ChatEmojiPanel extends StatelessWidget {
  const _ChatEmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const _emojis = [
    '😀', '😃', '😄', '😁', '😆', '😂', '🤣', '😊',
    '😍', '😘', '🥰', '😎', '🤔', '😳', '😭', '😡',
    '👍', '👏', '🙏', '💪', '🔥', '🎉', '✨', '❤️',
    '💙', '⭐', '📚', '🎧', '🏀', '⚽', '🎮', '📷',
    '☕', '🍚', '😴', '😅', '😋', '🤝', '👌', '🙌',
  ];

  static const _emojiTextStyle = TextStyle(
    fontSize: 25,
    height: 1,
    fontFamilyFallback: [
      'Apple Color Emoji',
      'Noto Color Emoji',
      'Segoe UI Emoji',
      'Android Emoji',
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
                itemCount: _emojis.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final emoji = _emojis[index];
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

text = text[:panel_start] + new_panel + text[panel_end:]

MAIN.write_text(text)
print("✅ 已修复：去重表情面板 + 添加 emoji 字体 fallback")
