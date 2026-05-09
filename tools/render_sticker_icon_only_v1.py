from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_render_sticker_icon_only_v1")
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

# 删除旧的 _StickerMessageText
text = remove_class(text, "_StickerMessageText")

insert_pos = text.find("class _ChatEmojiPanel extends StatelessWidget")
if insert_pos == -1:
    insert_pos = text.find("class _ChatInputBar extends StatelessWidget")

if insert_pos == -1:
    raise SystemExit("❌ 没找到 _ChatEmojiPanel 或 _ChatInputBar 插入位置")

new_class = r'''
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
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sticker.color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sticker.color.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  sticker.icon,
                  size: 18,
                  color: sticker.color,
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

text = text[:insert_pos] + new_class + text[insert_pos:]

MAIN.write_text(text)
print("✅ 已修改：聊天气泡里的 [表情] 只显示图标，不显示文字")
