from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_chat_sticker_panel_stable_v4")
if not bak.exists():
    bak.write_text(text)

def find_matching_brace(src: str, open_pos: int) -> int:
    depth = 0
    for i in range(open_pos, len(src)):
        ch = src[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
    raise RuntimeError("brace not matched")

# 1. 定位 _ChatScreenState
chat_start = text.find("class _ChatScreenState extends State<ChatScreen> {")
chat_end = text.find("\nclass _ChatHeader", chat_start)

if chat_start == -1 or chat_end == -1:
    raise SystemExit("❌ 没找到 _ChatScreenState 或 _ChatHeader")

chat = text[chat_start:chat_end]

# 2. 确保字段存在
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

# 3. 删除 ChatScreenState 里重复/旧的表情方法
chat = re.sub(
    r"\n  void _handleMessageFocusChange\(\) \{[\s\S]*?\n  \}\n\n  void _toggleEmojiPanel\(\) \{[\s\S]*?\n  \}\n\n  void _insertEmoji\(String emoji\) \{[\s\S]*?\n  \}\n",
    "\n",
    chat,
)

# 4. 插入唯一一组方法
load_marker = "  Future<void> _loadMessages() async {"
if load_marker not in chat:
    raise SystemExit("❌ 没找到 _loadMessages")

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

  void _insertEmoji(String sticker) {
    final oldValue = _messageController.value;
    final oldText = oldValue.text;
    final selection = oldValue.selection;

    final start = selection.start < 0 ? oldText.length : selection.start;
    final end = selection.end < 0 ? oldText.length : selection.end;

    final nextText = oldText.replaceRange(start, end, sticker);
    _messageController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + sticker.length),
    );
  }

'''

chat = chat.replace(load_marker, methods + load_marker, 1)

# 5. initState 监听输入框焦点
if "_messageFocusNode.addListener(_handleMessageFocusChange);" not in chat:
    chat = chat.replace(
        "_conversationId = widget.conversationId;\n    _loadMessages();",
        "_conversationId = widget.conversationId;\n    _messageFocusNode.addListener(_handleMessageFocusChange);\n    _loadMessages();",
        1,
    )

# 6. dispose 释放 focusNode
if "_messageFocusNode.dispose();" not in chat:
    chat = chat.replace(
        "_messageController.dispose();",
        "_messageFocusNode.removeListener(_handleMessageFocusChange);\n    _messageController.dispose();\n    _messageFocusNode.dispose();",
        1,
    )

# 7. 强制重写 ChatScreenState.build，保证只出现一个表情包面板
build_sig = "  Widget build(BuildContext context) {"
build_pos = chat.find(build_sig)
if build_pos == -1:
    raise SystemExit("❌ 没找到 ChatScreenState build 方法")

brace_pos = chat.find("{", build_pos)
build_end = find_matching_brace(chat, brace_pos)

new_build = r'''  Widget build(BuildContext context) {
    final messageWidgets = _messages
        .map(
          (message) => message.isMine
              ? _OutgoingChatBubble(text: message.text, sent: true)
              : _IncomingChatBubble(
                  user: widget.contact,
                  text: message.text,
                ),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _ChatHeader(
            contact: widget.contact,
            displayName: widget.displayName,
            online: widget.online,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    children: [
                      const _ChatTimeLabel(label: '最近消息'),
                      if (_messages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 120),
                          child: Column(
                            children: const [
                              Icon(
                                Icons.forum_outlined,
                                size: 48,
                                color: AppColors.muted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                '暂无真实聊天记录',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '发送第一条消息后，会显示在这里',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...messageWidgets,
                    ],
                  ),
          ),
          if (_showEmojiPanel)
            _ChatEmojiPanel(onEmojiSelected: _insertEmoji),
          _ChatInputBar(
            controller: _messageController,
            focusNode: _messageFocusNode,
            isSending: _isSending,
            onSend: _sendMessage,
            onEmojiTap: _toggleEmojiPanel,
          ),
        ],
      ),
    );
  }'''

chat = chat[:build_pos] + new_build + chat[build_end + 1:]

text = text[:chat_start] + chat + text[chat_end:]

# 8. 删除所有旧 _ChatEmojiPanel
while True:
    panel_start = text.find("class _ChatEmojiPanel extends StatelessWidget {")
    if panel_start == -1:
        break
    panel_end = text.find("\nclass _ChatInputBar extends StatelessWidget {", panel_start)
    if panel_end == -1:
        raise SystemExit("❌ 找到旧 _ChatEmojiPanel，但没找到 _ChatInputBar")
    text = text[:panel_start] + text[panel_end:]

# 9. 插入稳定文字表情包面板
input_start = text.find("class _ChatInputBar extends StatelessWidget {")
if input_start == -1:
    raise SystemExit("❌ 没找到 _ChatInputBar")

new_panel = r'''class _ChatEmojiPanel extends StatelessWidget {
  const _ChatEmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const _stickers = [
    '[微笑]', '[大笑]', '[偷笑]', '[捂脸]',
    '[点赞]', '[鼓掌]', '[抱拳]', '[加油]',
    '[收到]', '[OK]', '[谢谢]', '[辛苦了]',
    '[玫瑰]', '[爱心]', '[星星]', '[火]',
    '[学习]', '[拍照]', '[运动]', '[游戏]',
    '[干饭]', '[咖啡]', '[晚安]', '[疑问]',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 206,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
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
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                itemCount: _stickers.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 2.45,
                ),
                itemBuilder: (context, index) {
                  final sticker = _stickers[index];
                  return Material(
                    color: const Color(0xFFF5F8FC),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onEmojiSelected(sticker),
                      child: Center(
                        child: Text(
                          sticker,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
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

# 10. 重写 _ChatInputBar，确保按钮逻辑干净
input_start = text.find("class _ChatInputBar extends StatelessWidget {")
input_end = text.find("\nclass _ChatCircleButton", input_start)

if input_start == -1 or input_end == -1:
    raise SystemExit("❌ 没找到 _ChatInputBar 或 _ChatCircleButton")

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
                      onSubmitted: (_) {
                        if (!isSending) onSend();
                      },
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

MAIN.write_text(text)
print("✅ 已修复：去掉重复面板，改为稳定文字表情包，修复底部 overflow")
