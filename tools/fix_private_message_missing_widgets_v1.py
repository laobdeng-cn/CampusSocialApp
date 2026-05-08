from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_private_message_missing_widgets_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 统一私信空状态组件名，避免和项目里可能已有类冲突
text = text.replace("_EmptyStateCard(", "_PrivateEmptyStateCard(")

# 2. 插入 _PrivateEmptyStateCard
if "class _PrivateEmptyStateCard" not in text:
    marker = "class _PrivateChatEntry {"
    insert = r'''
class _PrivateEmptyStateCard extends StatelessWidget {
  const _PrivateEmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 104),
      children: [
        CampusCard(
          padding: const EdgeInsets.fromLTRB(18, 34, 18, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.muted, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

'''
    if marker not in text:
        raise SystemExit("❌ 没找到 class _PrivateChatEntry，请把 1900-2010 行发我")
    text = text.replace(marker, insert + marker, 1)

# 3. 插入 _ChatEmptyHint
if "class _ChatEmptyHint extends StatelessWidget" not in text:
    marker = "class _IncomingChatBubble extends StatelessWidget {"
    insert = r'''
class _ChatEmptyHint extends StatelessWidget {
  const _ChatEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Center(
        child: Column(
          children: const [
            Icon(Icons.forum_outlined, color: AppColors.muted, size: 42),
            SizedBox(height: 12),
            Text(
              '暂无真实聊天记录',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '发送第一条消息后，会显示在这里',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

'''
    if marker not in text:
        raise SystemExit("❌ 没找到 class _IncomingChatBubble，请把 2440-2485 行发我")
    text = text.replace(marker, insert + marker, 1)

# 4. 删除私信演示列表 _privateChatEntries
pattern = r"\nconst _privateChatEntries = \[[\s\S]*?\];\n\nclass _PrivateChatEntry"
if re.search(pattern, text):
    text = re.sub(pattern, "\nclass _PrivateChatEntry", text, count=1)

MAIN.write_text(text)
print("✅ 已补齐私信空状态组件，并删除私信演示列表")
