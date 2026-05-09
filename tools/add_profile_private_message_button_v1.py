from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_add_profile_private_message_button_v1")
if not bak.exists():
    bak.write_text(text)

start = text.find("class _UserProfileHeader extends StatelessWidget {")
end = text.find("\nString _profileBioFor", start)

if start == -1 or end == -1:
    raise SystemExit("❌ 没找到 _UserProfileHeader，请把该类完整代码发我")

header = text[start:end]

# 1. 给 _UserProfileHeader 增加打开私信方法
if "Future<void> _openPrivateChat(BuildContext context)" not in header:
    marker = "  final VoidCallback? onChanged;\n"
    method = r'''
  bool get _isCurrentUser {
    final authUser = AuthSession.user;
    if (authUser == null) return false;

    final currentId = authUser.id.trim();
    final targetId = user.id.trim();
    if (currentId.isNotEmpty && targetId.isNotEmpty) {
      return currentId == targetId;
    }

    return authUser.name.trim() == user.name.trim();
  }

  Future<void> _openPrivateChat(BuildContext context) async {
    if (_isCurrentUser) {
      _showShellMessage(context, '不能给自己发私信');
      return;
    }

    try {
      final conversation = await CampusRepository.instance.startConversation(user);
      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            contact: conversation.contact.id.isEmpty
                ? user
                : conversation.contact,
            conversationId: conversation.id,
            displayName: user.name,
            online: true,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            contact: user,
            displayName: user.name,
            online: true,
          ),
        ),
      );
      _showShellMessage(context, _shellError(error));
    }
  }

'''
    if marker not in header:
        raise SystemExit("❌ 没找到 onChanged 字段位置")
    header = header.replace(marker, marker + method, 1)

# 2. 把原来的单个关注按钮，替换成关注 + 私信纵向按钮组
old = """          Positioned(
            top: panelTop + 24,
            right: sidePadding,
            child: _ProfileFollowButton(user: user, onChanged: onChanged),
          ),"""

new = """          Positioned(
            top: panelTop + 24,
            right: sidePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileFollowButton(user: user, onChanged: onChanged),
                if (!_isCurrentUser) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 104,
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed: () => _openPrivateChat(context),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                      label: const Text('私信'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: BorderSide(
                          color: AppColors.blue.withValues(alpha: 0.72),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),"""

if old not in header:
    raise SystemExit("❌ 没找到关注按钮 Positioned，请把 _UserProfileHeader 当前代码发我")

header = header.replace(old, new, 1)

# 3. 右侧有两个按钮后，认证标签稍微往左收，避免被按钮压住
header = header.replace(
    "right: sidePadding,\n            child: Wrap(",
    "right: 138,\n            child: Wrap(",
    1,
)

text = text[:start] + header + text[end:]
MAIN.write_text(text)

print("✅ 已在关注按钮下面增加私信按钮")
