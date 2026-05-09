from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_emoji_button_no_response_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 确保 ChatScreenState 里有表情状态和方法
chat_start = text.find("class _ChatScreenState extends State<ChatScreen> {")
if chat_start == -1:
    raise SystemExit("❌ 没找到 _ChatScreenState")

chat_end = text.find("\nclass _ChatHeader", chat_start)
chat = text[chat_start:chat_end]

if "final _messageFocusNode = FocusNode();" not in chat:
    chat = chat.replace(
        "final _messageController = TextEditingController();",
        "final _messageController = TextEditingController();\n  final _messageFocusNode = FocusNode();",
        1,
    )

if "var _showEmojiPanel = false;" not in chat:
    chat = chat.replace(
        "var _isSending = false;",
        "var _isSending = false;\n  var _showEmojiPanel = false;",
        1,
    )

# 删除 ChatScreenState 内旧的重复方法，重新插入一组
chat = re.sub(
    r"\n  void _handleMessageFocusChange\(\) \{[\s\S]*?\n  \}\n\n  void _toggleEmojiPanel\(\) \{[\s\S]*?\n  \}\n\n  void _insertEmoji\(String emoji\) \{[\s\S]*?\n  \}\n",
    "\n",
    chat,
)

methods = r'''
  void _handleMessageFocusChange() {
    if (_messageFocusNode.hasFocus && _showEmojiPanel && mounted) {
      setState(() {
        _showEmojiPanel = false;
      });
    }
  }

  void _toggleEmojiPanel() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmojiPanel = !_showEmojiPanel;
    });
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

load_marker = "  Future<void> _loadMessages() async {"
if load_marker not in chat:
    raise SystemExit("❌ ChatScreenState 里没找到 _loadMessages")
chat = chat.replace(load_marker, methods + load_marker, 1)

# initState 监听
if "_messageFocusNode.addListener(_handleMessageFocusChange);" not in chat:
    chat = chat.replace(
        "_conversationId = widget.conversationId;\n    _loadMessages();",
        "_conversationId = widget.conversationId;\n    _messageFocusNode.addListener(_handleMessageFocusChange);\n    _loadMessages();",
        1,
    )

# dispose 释放
if "_messageFocusNode.dispose();" not in chat:
    chat = chat.replace(
        "_messageController.dispose();",
        "_messageFocusNode.removeListener(_handleMessageFocusChange);\n    _messageController.dispose();\n    _messageFocusNode.dispose();",
        1,
    )

text = text[:chat_start] + chat + text[chat_end:]

# 2. 强制让 ChatScreen 底部显示表情面板 + 新输入栏参数
old_call_re = re.compile(
    r"          _ChatInputBar\([\s\S]*?          \),",
    re.MULTILINE,
)

new_call = """          if (_showEmojiPanel)
            _ChatEmojiPanel(onEmojiSelected: _insertEmoji),
          _ChatInputBar(
            controller: _messageController,
            focusNode: _messageFocusNode,
            isSending: _isSending,
            onSend: _sendMessage,
            onEmojiTap: _toggleEmojiPanel,
          ),"""

# 只替换 ChatScreenState 内的第一个 _ChatInputBar
chat_start = text.find("class _ChatScreenState extends State<ChatScreen> {")
chat_end = text.find("\nclass _ChatHeader", chat_start)
before = text[:chat_start]
chat = text[chat_start:chat_end]
after = text[chat_end:]

if "_ChatEmojiPanel(onEmojiSelected: _insertEmoji)" not in chat:
    chat = old_call_re.sub(new_call, chat, count=1)
else:
    chat = old_call_re.sub(new_call, chat, count=1)

text = before + chat + after

# 3. 重写 _ChatInputBar，确保笑脸按钮一定触发 onEmojiTap
input_start = text.find("class _ChatInputBar extends StatelessWidget {")
if input_start == -1:
    raise SystemExit("❌ 没找到 _ChatInputBar")

input_end = text.find("\nclass _ChatCircleButton", input_start)
if input_end == -1:
    raise SystemExit("❌ 没找到 _ChatCircleButton，无法定位 _ChatInputBar 结束位置")

new_input = r'''class _ChatInputBar extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          _ChatCircleButton(icon: Icons.mic_none_rounded, onTap: () {}),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => isSending ? null : onSend(),
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: TextStyle(color: AppColors.muted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onEmojiTap,
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: AppColors.text,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    splashRadius: 20,
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.image_outlined,
                      color: AppColors.text,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isSending ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(isSending ? '发送中' : '发送'),
            ),
          ),
        ],
      ),
    );
  }
}

'''

text = text[:input_start] + new_input + text[input_end:]

# 4. 如果没有表情面板组件，补一个
if "class _ChatEmojiPanel extends StatelessWidget" not in text:
    marker = "class _ChatInputBar extends StatelessWidget {"
    panel = r'''class _ChatEmojiPanel extends StatelessWidget {
  const _ChatEmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const _emojis = [
    '😀', '😄', '😁', '😂', '🤣', '😊', '😍', '😘',
    '😎', '🤔', '😳', '😭', '😡', '👍', '👏', '🙏',
    '💪', '🔥', '🎉', '✨', '🌹', '❤️', '💙', '⭐',
    '📚', '🎧', '🏀', '⚽', '🎮', '📷', '☕', '🍚',
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
    text = text.replace(marker, panel + marker, 1)

MAIN.write_text(text)
print("✅ 已强制修复：笑脸按钮点击会打开自定义表情面板")
