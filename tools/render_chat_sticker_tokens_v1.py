from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_render_chat_sticker_tokens_v1")
if not bak.exists():
    bak.write_text(text)

def find_matching_brace(src: str, open_pos: int) -> int:
    depth = 0
    for i in range(open_pos, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    raise RuntimeError("brace not matched")

def remove_class(src: str, class_name: str) -> str:
    marker = f"class {class_name}"
    while True:
        start = src.find(marker)
        if start == -1:
            return src
        brace = src.find("{", start)
        if brace == -1:
            return src
        end = find_matching_brace(src, brace)
        src = src[:start] + src[end + 1:]

def replace_class(src: str, class_name: str, new_code: str) -> str:
    marker = f"class {class_name}"
    start = src.find(marker)
    if start == -1:
        raise SystemExit(f"❌ 没找到 {class_name}")
    brace = src.find("{", start)
    end = find_matching_brace(src, brace)
    return src[:start] + new_code + src[end + 1:]

# 1. 清理旧的表情数据/渲染类，避免重复定义
for name in ["_ChatStickerData", "_ChatStickerBook", "_StickerMessageText"]:
    text = remove_class(text, name)

# 2. 插入统一表情数据 + 气泡渲染组件
insert_pos = text.find("class _ChatEmojiPanel extends StatelessWidget")
if insert_pos == -1:
    insert_pos = text.find("class _ChatInputBar extends StatelessWidget")

if insert_pos == -1:
    raise SystemExit("❌ 没找到 _ChatEmojiPanel 或 _ChatInputBar 插入位置")

sticker_render_code = r'''
class _ChatStickerData {
  const _ChatStickerData({
    required this.token,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String token;
  final String label;
  final IconData icon;
  final Color color;
}

class _ChatStickerBook {
  static const stickers = <_ChatStickerData>[
    _ChatStickerData(
      token: '[微笑]',
      label: '微笑',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: Color(0xFF2F80ED),
    ),
    _ChatStickerData(
      token: '[大笑]',
      label: '大笑',
      icon: Icons.sentiment_very_satisfied_rounded,
      color: Color(0xFFFFA726),
    ),
    _ChatStickerData(
      token: '[难过]',
      label: '难过',
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFF6B7280),
    ),
    _ChatStickerData(
      token: '[哭泣]',
      label: '哭泣',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: Color(0xFF5B8DEF),
    ),
    _ChatStickerData(
      token: '[生气]',
      label: '生气',
      icon: Icons.mood_bad_rounded,
      color: Color(0xFFFF4D4F),
    ),
    _ChatStickerData(
      token: '[点赞]',
      label: '点赞',
      icon: Icons.thumb_up_alt_rounded,
      color: Color(0xFF1677FF),
    ),
    _ChatStickerData(
      token: '[爱心]',
      label: '爱心',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF4D6D),
    ),
    _ChatStickerData(
      token: '[星星]',
      label: '星星',
      icon: Icons.star_rounded,
      color: Color(0xFFFFA726),
    ),
    _ChatStickerData(
      token: '[鼓掌]',
      label: '鼓掌',
      icon: Icons.back_hand_rounded,
      color: Color(0xFF13C2C2),
    ),
    _ChatStickerData(
      token: '[抱拳]',
      label: '抱拳',
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFF7C4DFF),
    ),
    _ChatStickerData(
      token: '[加油]',
      label: '加油',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFF7A00),
    ),
    _ChatStickerData(
      token: '[收到]',
      label: '收到',
      icon: Icons.check_circle_rounded,
      color: Color(0xFF22C55E),
    ),
    _ChatStickerData(
      token: '[疑问]',
      label: '疑问',
      icon: Icons.help_outline_rounded,
      color: Color(0xFF64748B),
    ),
    _ChatStickerData(
      token: '[学习]',
      label: '学习',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF2F80ED),
    ),
    _ChatStickerData(
      token: '[拍照]',
      label: '拍照',
      icon: Icons.photo_camera_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _ChatStickerData(
      token: '[运动]',
      label: '运动',
      icon: Icons.sports_basketball_rounded,
      color: Color(0xFFEF4444),
    ),
    _ChatStickerData(
      token: '[游戏]',
      label: '游戏',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF6366F1),
    ),
    _ChatStickerData(
      token: '[干饭]',
      label: '干饭',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFF8A00),
    ),
    _ChatStickerData(
      token: '[咖啡]',
      label: '咖啡',
      icon: Icons.coffee_rounded,
      color: Color(0xFF8B5E3C),
    ),
    _ChatStickerData(
      token: '[晚安]',
      label: '晚安',
      icon: Icons.dark_mode_rounded,
      color: Color(0xFF475569),
    ),
  ];

  static _ChatStickerData? find(String token) {
    for (final sticker in stickers) {
      if (sticker.token == token) return sticker;
    }
    return null;
  }
}

class _StickerMessageText extends StatelessWidget {
  const _StickerMessageText({
    required this.text,
    required this.color,
    this.fontSize = 15.5,
  });

  final String text;
  final Color color;
  final double fontSize;

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\[[^\]]+\]');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: TextStyle(color: color, fontSize: fontSize, height: 1.55),
          ),
        );
      }

      final token = match.group(0) ?? '';
      final sticker = _ChatStickerBook.find(token);

      if (sticker == null) {
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(color: color, fontSize: fontSize, height: 1.55),
          ),
        );
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: sticker.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: sticker.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(sticker.icon, size: 16, color: sticker.color),
                    const SizedBox(width: 3),
                    Text(
                      sticker.label,
                      style: TextStyle(
                        color: sticker.color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: TextStyle(color: color, fontSize: fontSize, height: 1.55),
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: _buildSpans()),
    );
  }
}

'''

text = text[:insert_pos] + sticker_render_code + text[insert_pos:]

# 3. 重写接收气泡：把 Text 改成 _StickerMessageText
incoming_code = r'''class _IncomingChatBubble extends StatelessWidget {
  const _IncomingChatBubble({required this.user, required this.text});

  final CampusUser user;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampusAvatar(user: user, size: 40),
          const SizedBox(width: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.66,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _StickerMessageText(
                  text: text,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
'''

outgoing_code = r'''class _OutgoingChatBubble extends StatelessWidget {
  const _OutgoingChatBubble({
    required this.text,
    this.user,
    this.sent = false,
  });

  final CampusUser? user;
  final String text;
  final bool sent;

  CampusUser get _displayUser {
    return user ??
        AuthSession.user ??
        const CampusUser(
          name: '我',
          school: '未知学院',
          major: '未填写专业',
          grade: '未填写年级',
          avatarUrl: 'https://i.pravatar.cc/180?img=1',
          bio: '',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: sent ? 6 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.66,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF168BFF), AppColors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _StickerMessageText(
                      text: text,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CampusAvatar(user: _displayUser, size: 40),
            ],
          ),
          if (sent) ...[
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(right: 50),
              child: Text(
                '已送达',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
'''

text = replace_class(text, "_IncomingChatBubble", incoming_code)
text = replace_class(text, "_OutgoingChatBubble", outgoing_code)

MAIN.write_text(text)
print("✅ 已完成：聊天气泡 [表情] 标记渲染为图标标签")
