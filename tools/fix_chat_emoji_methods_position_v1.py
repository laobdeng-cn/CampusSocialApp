from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_chat_emoji_methods_position_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 删除所有错误位置/重复位置的三个方法
patterns = [
    r"\n  void _handleMessageFocusChange\(\) \{[\s\S]*?\n  \}\n(?=\n  void _toggleEmojiPanel)",
    r"\n  void _toggleEmojiPanel\(\) \{[\s\S]*?\n  \}\n(?=\n  void _insertEmoji)",
    r"\n  void _insertEmoji\(String emoji\) \{[\s\S]*?\n  \}\n(?=\n  @override|\n  Future<void>|\n  Widget|\n  void|\n})",
]

for p in patterns:
    text = re.sub(p, "\n", text)

# 2. 确保 ChatScreenState 有 FocusNode
chat_start = text.find("class _ChatScreenState extends State<ChatScreen> {")
if chat_start == -1:
    raise SystemExit("❌ 没找到 _ChatScreenState")

load_marker = "  Future<void> _loadMessages() async {"
load_pos = text.find(load_marker, chat_start)
if load_pos == -1:
    raise SystemExit("❌ 没找到 _ChatScreenState._loadMessages")

chat_head = text[chat_start:load_pos]

if "final _messageFocusNode = FocusNode();" not in chat_head:
    text = text.replace(
        "class _ChatScreenState extends State<ChatScreen> {\n  final _messageController = TextEditingController();",
        "class _ChatScreenState extends State<ChatScreen> {\n  final _messageController = TextEditingController();\n  final _messageFocusNode = FocusNode();",
        1,
    )

# 3. 确保 ChatScreenState 有 _showEmojiPanel
chat_start = text.find("class _ChatScreenState extends State<ChatScreen> {")
load_pos = text.find(load_marker, chat_start)
chat_head = text[chat_start:load_pos]

if "var _showEmojiPanel = false;" not in chat_head:
    text = text.replace(
        "  var _isLoading = false;\n  var _isSending = false;",
        "  var _isLoading = false;\n  var _isSending = false;\n  var _showEmojiPanel = false;",
        1,
    )

# 4. 把三个方法插入到 _ChatScreenState 的 _loadMessages 前面
methods = r'''  void _handleMessageFocusChange() {
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

chat_start = text.find("class _ChatScreenState extends State<ChatScreen> {")
load_pos = text.find(load_marker, chat_start)
text = text[:load_pos] + methods + text[load_pos:]

# 5. 确保 initState 监听 FocusNode
old = """    _conversationId = widget.conversationId;
    _messageFocusNode.addListener(_handleMessageFocusChange);
    _loadMessages();
"""
if old not in text:
    text = text.replace(
"""    _conversationId = widget.conversationId;
    _loadMessages();
""",
"""    _conversationId = widget.conversationId;
    _messageFocusNode.addListener(_handleMessageFocusChange);
    _loadMessages();
""",
        1,
    )

# 6. 确保 dispose 正确释放
if "_messageFocusNode.removeListener(_handleMessageFocusChange);" not in text:
    text = text.replace(
"""  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
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
        1,
    )

MAIN.write_text(text)
print("✅ 已修复：表情面板方法已移入 _ChatScreenState")
