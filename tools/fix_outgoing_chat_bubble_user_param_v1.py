from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_outgoing_chat_bubble_user_param_v1")
if not bak.exists():
    bak.write_text(text)

old = """  Widget build(BuildContext context) {
    final messageWidgets = _messages
"""

new = """  Widget build(BuildContext context) {
    final currentUser =
        AuthSession.user ??
        const CampusUser(
          name: '我',
          school: '未知学院',
          major: '未填写专业',
          grade: '未填写年级',
          avatarUrl: 'https://i.pravatar.cc/180?img=1',
          bio: '',
        );

    final messageWidgets = _messages
"""

if old in text and "final currentUser =" not in text[text.find("class _ChatScreenState"):text.find("class _ChatHeader")]:
    text = text.replace(old, new, 1)

text = text.replace(
    "_OutgoingChatBubble(text: message.text, sent: true)",
    "_OutgoingChatBubble(user: currentUser, text: message.text, sent: true)",
)

# 兼容如果还有旧 const 调用
text = text.replace(
    "const _OutgoingChatBubble(text:",
    "_OutgoingChatBubble(user: currentUser, text:",
)

MAIN.write_text(text)
print("✅ 已修复 _OutgoingChatBubble 缺少 user 参数")
