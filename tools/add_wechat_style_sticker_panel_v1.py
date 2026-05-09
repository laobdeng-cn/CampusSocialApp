from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_add_wechat_style_sticker_panel_v1")
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

# 清理旧组件，避免重复定义
for name in [
    "_ChatStickerData",
    "_ChatStickerBook",
    "_StickerMessageText",
    "_ChatEmojiPanel",
]:
    text = remove_class(text, name)

# 1. 插入表情数据 + 气泡渲染组件，放在 _ChatInputBar 前
input_marker = "class _ChatInputBar extends StatelessWidget"
input_pos = text.find(input_marker)
if input_pos == -1:
    raise SystemExit("❌ 没找到 _ChatInputBar")

sticker_code = r'''
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
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: sticker.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: sticker.color.withValues(alpha: 0.20),
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
                    ),
                  ),
                ],
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

class _ChatEmojiPanel extends StatelessWidget {
  const _ChatEmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 236,
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
                    '表情包',
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
                itemCount: _ChatStickerBook.stickers.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.86,
                ),
                itemBuilder: (context, index) {
                  final sticker = _ChatStickerBook.stickers[index];
                  return Material(
                    color: const Color(0xFFF5F8FC),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onEmojiSelected(sticker.token),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sticker.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              sticker.icon,
                              color: sticker.color,
                              size: 23,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sticker.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

text = text[:input_pos] + sticker_code + text[input_pos:]

# 2. 重写聊天气泡，让 [微笑] 这类标记显示成自定义表情标签
incoming = r'''class _IncomingChatBubble extends StatelessWidget {
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

outgoing = r'''class _OutgoingChatBubble extends StatelessWidget {
  const _OutgoingChatBubble({
    required this.user,
    required this.text,
    this.sent = false,
  });

  final CampusUser user;
  final String text;
  final bool sent;

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
              CampusAvatar(user: user, size: 40),
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

text = replace_class(text, "_IncomingChatBubble", incoming)
text = replace_class(text, "_OutgoingChatBubble", outgoing)

# 3. 确保旧调用都带 user 参数
if "_OutgoingChatBubble(text:" in text:
    text = text.replace(
        "_OutgoingChatBubble(text:",
        "_OutgoingChatBubble(user: currentUser, text:",
    )

if "const _OutgoingChatBubble(text:" in text:
    text = text.replace(
        "const _OutgoingChatBubble(text:",
        "_OutgoingChatBubble(user: currentUser, text:",
    )

# 4. 发送后自动收起表情面板
text = text.replace(
"""      if (mounted) {
        setState(() => _messages = [..._messages, message]);
      }
""",
"""      if (mounted) {
        setState(() {
          _messages = [..._messages, message];
          _showEmojiPanel = false;
        });
      }
""",
)

MAIN.write_text(text)
print("✅ 已完成：微信式自定义表情包面板 + 聊天气泡表情渲染")
