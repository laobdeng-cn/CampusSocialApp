from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_add_custom_emoji_panel_v1")
if not bak.exists():
    bak.write_text(text)

# 1. ChatScreenState 增加 FocusNode / 表情面板状态
text = text.replace(
"""class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  List<CampusChatMessage> _messages = const [];
""",
"""class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  List<CampusChatMessage> _messages = const [];
""",
)

if "var _showEmojiPanel = false;" not in text:
    text = text.replace(
"""  var _isLoading = false;
  var _isSending = false;
""",
"""  var _isLoading = false;
  var _isSending = false;
  var _showEmojiPanel = false;
""",
    )

# 2. initState 增加输入框监听：点输入框时隐藏表情面板
text = text.replace(
"""    _conversationId = widget.conversationId;
    _loadMessages();
""",
"""    _conversationId = widget.conversationId;
    _messageFocusNode.addListener(_handleMessageFocusChange);
    _loadMessages();
""",
)

if "void _handleMessageFocusChange()" not in text:
    marker = """  @override
  void dispose() {"""
    method = r'''  void _handleMessageFocusChange() {
    if (_messageFocusNode.hasFocus && _showEmojiPanel && mounted) {
      setState(() => _showEmojiPanel = false);
    }
  }

  void _toggleEmojiPanel() {
    FocusScope.of(context).unfocus();
    setState(() => _showEmojiPanel = !_showEmojiPanel);
  }

  void _insertEmoji(String emoji) {
    final oldValue = _messageController.value;
    final oldText = oldValue.text;
    final selection = oldValue.selection;

    final start = selection.start < 0 ? oldText.length : selection.start;
    final end = selection.end < 0 ? oldText.length : selection.end;

    final nextText = oldText.replaceRange(start, end, emoji);
    _messageController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

'''
    text = text.replace(marker, method + marker, 1)

# 3. dispose 释放 FocusNode
text = text.replace(
"""  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
""",
"""  void dispose() {
    _messageFocusNode.removeListener(_handleMessageFocusChange);
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }
""",
)

# 4. 发送成功后隐藏表情面板
text = text.replace(
"""      _messageController.clear();
      if (mounted) {
        setState(() => _messages = [..._messages, message]);
      }
""",
"""      _messageController.clear();
      if (mounted) {
        setState(() {
          _messages = [..._messages, message];
          _showEmojiPanel = false;
        });
      }
""",
)

# 5. ChatScreen 底部加入 EmojiPanel，并传入 onEmojiTap
pattern = r"""          _ChatInputBar\(
            controller: _messageController,[\s\S]*?            onSend: _sendMessage,[\s\S]*?          \),
"""
replacement = """          if (_showEmojiPanel)
            _ChatEmojiPanel(onEmojiSelected: _insertEmoji),
          _ChatInputBar(
            controller: _messageController,
            focusNode: _messageFocusNode,
            isSending: _isSending,
            onSend: _sendMessage,
            onEmojiTap: _toggleEmojiPanel,
          ),
"""

if "_ChatEmojiPanel(onEmojiSelected" not in text:
    text = re.sub(pattern, replacement, text, count=1)

# 6. _ChatInputBar 支持 focusNode / onEmojiTap
text = text.replace(
"""class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.isSending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
""",
"""class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onEmojiTap,
    required this.isSending,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onEmojiTap;
  final bool isSending;
""",
)

# 7. TextField 绑定 focusNode
text = text.replace(
"controller: controller,",
"controller: controller,\n                    focusNode: focusNode,",
1,
)

# 8. 笑脸按钮改成打开自定义面板
text = text.replace(
"_ChatCircleButton(icon: Icons.emoji_emotions_outlined, onTap: () {}),",
"_ChatCircleButton(icon: Icons.emoji_emotions_outlined, onTap: onEmojiTap),",
)

text = text.replace(
"_ChatCircleButton(icon: Icons.mood_outlined, onTap: () {}),",
"_ChatCircleButton(icon: Icons.mood_outlined, onTap: onEmojiTap),",
)

text = text.replace(
"_ChatCircleButton(icon: Icons.sentiment_satisfied_alt_rounded, onTap: () {}),",
"_ChatCircleButton(icon: Icons.sentiment_satisfied_alt_rounded, onTap: onEmojiTap),",
)

text = text.replace(
"_ChatCircleButton(icon: Icons.sentiment_satisfied_alt_rounded, onTap: onEmojiTap),",
"_ChatCircleButton(icon: Icons.sentiment_satisfied_alt_rounded, onTap: onEmojiTap),",
)

# 9. 插入自定义表情面板组件
if "class _ChatEmojiPanel extends StatelessWidget" not in text:
    marker = "class _ChatInputBar extends StatelessWidget {"
    emoji_panel = r'''
class _ChatEmojiPanel extends StatelessWidget {
  const _ChatEmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const _emojis = [
    '😀', '😄', '😁', '😂', '🤣', '😊', '😍', '😘',
    '😎', '🤔', '😳', '😭', '😡', '👍', '👏', '🙏',
    '💪', '🔥', '🎉', '✨', '🌹', '❤️', '💙', '⭐',
    '🍚', '☕', '📚', '🎧', '🏀', '⚽', '🎮', '📷',
    '😴', '🥰', '😅', '😆', '😋', '🤝', '👌', '🙌',
  ];

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: const [
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
                          style: const TextStyle(fontSize: 24),
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
    if marker not in text:
        raise SystemExit("❌ 没找到 _ChatInputBar 插入位置")
    text = text.replace(marker, emoji_panel + marker, 1)

MAIN.write_text(text)
print("✅ 已添加自定义表情面板")
