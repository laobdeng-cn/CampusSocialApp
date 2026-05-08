from pathlib import Path

ROOT = Path.home() / "Desktop" / "CampusSocialApp"
DETAIL = ROOT / "frontend/frontend/lib/screens/detail_pages.dart"

text = DETAIL.read_text()

backup = DETAIL.with_suffix(DETAIL.suffix + ".bak_post_detail_favorite_state_v1")
backup.write_text(text)
print(f"✅ 已备份: {backup}")

def replace_once(src: str, old: str, new: str, name: str) -> str:
    if new in src:
        print(f"✅ {name} 已存在，跳过")
        return src
    if old not in src:
        raise SystemExit(f"❌ 没找到替换点: {name}")
    print(f"✅ patch: {name}")
    return src.replace(old, new, 1)

def find_method(src: str, signature: str):
    start = src.find(signature)
    if start < 0:
        raise SystemExit(f"❌ 没找到方法: {signature}")

    brace = src.find("{", start)
    if brace < 0:
        raise SystemExit(f"❌ 没找到方法开始大括号: {signature}")

    depth = 0
    for i in range(brace, len(src)):
        ch = src[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1

    raise SystemExit(f"❌ 没找到方法结束大括号: {signature}")

# 1. 增加收藏状态字段
text = replace_once(
    text,
    """  var _isFollowingAuthor = false;
  late bool _authorFollowed = widget.post.author.followedByMe;
""",
    """  var _isFollowingAuthor = false;
  var _postFavorited = false;
  late bool _authorFollowed = widget.post.author.followedByMe;
""",
    "PostDetailScreen 增加 _postFavorited 字段",
)

# 2. initState 里加载收藏状态
text = replace_once(
    text,
    """    _loadComments();
""",
    """    _loadFavoriteStatus();
    _loadComments();
""",
    "initState 加载收藏状态",
)

# 3. 增加 _loadFavoriteStatus 方法
if "Future<void> _loadFavoriteStatus() async" not in text:
    marker = "  Future<void> _toggleLike() async {"
    method = """  Future<void> _loadFavoriteStatus() async {
    if (_post.id.isEmpty) return;
    try {
      final favorites = await CampusRepository.instance.fetchFavorites();
      if (!mounted) return;

      final favorited = favorites.any((record) {
        return record.kind == 'post' && record.post.id == _post.id;
      });

      setState(() => _postFavorited = favorited);
    } catch (_) {
      // 收藏状态加载失败不影响详情页主流程。
    }
  }

"""
    if marker not in text:
        raise SystemExit("❌ 没找到 _toggleLike 插入点")
    text = text.replace(marker, method + marker, 1)
    print("✅ patch: 增加 _loadFavoriteStatus 方法")
else:
    print("✅ _loadFavoriteStatus 已存在，跳过")

# 4. 替换 _toggleFavorite 方法
new_toggle = """  Future<void> _toggleFavorite() async {
    if (_isFavoriting) return;

    final wasFavorited = _postFavorited;
    setState(() => _isFavoriting = true);

    try {
      final post = await CampusRepository.instance.togglePostFavorite(_post);
      if (!mounted) return;

      setState(() {
        _post = post;
        _postFavorited = !wasFavorited;
      });

      _showMessage(context, _postFavorited ? '已收藏' : '已取消收藏');
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isFavoriting = false);
    }
  }"""

start, end = find_method(text, "  Future<void> _toggleFavorite() async {")
old_toggle = text[start:end]
if old_toggle != new_toggle:
    text = text[:start] + new_toggle + text[end:]
    print("✅ patch: 替换 PostDetailScreen _toggleFavorite")
else:
    print("✅ _toggleFavorite 已是目标版本，跳过")

# 5. 收藏按钮图标改成状态绑定
old_star = """              _ActionStat(
                icon: _isFavoriting
                    ? Icons.hourglass_top_rounded
                    : Icons.star_border_rounded,
                value: post.saves,
                onTap: _isFavoriting ? null : _toggleFavorite,
              ),
"""

new_star = """              _ActionStat(
                icon: _isFavoriting
                    ? Icons.hourglass_top_rounded
                    : (_postFavorited
                          ? Icons.star_rounded
                          : Icons.star_border_rounded),
                value: post.saves,
                color: _postFavorited ? AppColors.orange : AppColors.text,
                onTap: _isFavoriting ? null : _toggleFavorite,
              ),
"""

text = replace_once(
    text,
    old_star,
    new_star,
    "收藏按钮图标/颜色绑定 _postFavorited",
)

DETAIL.write_text(text)
print("✅ post detail favorite state patch done")
