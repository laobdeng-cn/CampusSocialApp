from pathlib import Path

ROOT = Path.home() / "Desktop" / "CampusSocialApp"
MAIN = ROOT / "frontend/frontend/lib/screens/main_shell.dart"
DETAIL = ROOT / "frontend/frontend/lib/screens/detail_pages.dart"

def backup(path: Path, suffix: str):
    bak = path.with_suffix(path.suffix + suffix)
    bak.write_text(path.read_text())
    print(f"✅ 已备份: {bak}")

def find_method(src: str, signature: str, start_at: int = 0):
    start = src.find(signature, start_at)
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

def find_class_block(src: str, class_signature: str):
    start = src.find(class_signature)
    if start < 0:
        raise SystemExit(f"❌ 没找到类: {class_signature}")

    brace = src.find("{", start)
    if brace < 0:
        raise SystemExit(f"❌ 没找到类开始大括号: {class_signature}")

    depth = 0
    for i in range(brace, len(src)):
        ch = src[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1

    raise SystemExit(f"❌ 没找到类结束大括号: {class_signature}")

def replace_once(src: str, old: str, new: str, name: str) -> str:
    if old not in src:
        if new in src:
            print(f"✅ {name} 已是目标状态，跳过")
            return src
        raise SystemExit(f"❌ 没找到替换点: {name}")
    print(f"✅ patch: {name}")
    return src.replace(old, new, 1)

# =========================
# 1. 修首页 PostFeedCard：爱心/收藏状态
# =========================
main = MAIN.read_text()
backup(MAIN, ".bak_post_like_favorite_sync_v1")

if "import 'dart:async';" not in main[:300]:
    main = "import 'dart:async';\n\n" + main
    print("✅ patch: main_shell.dart 添加 dart:async")

if "campus_event_bus.dart" not in main:
    main = main.replace(
        "import '../repositories/campus_repository.dart';",
        "import '../repositories/campus_repository.dart';\nimport '../repositories/campus_event_bus.dart';",
        1,
    )
    print("✅ patch: main_shell.dart 添加 campus_event_bus import")

state_sig = "class _PostFeedCardState extends State<PostFeedCard> {"
state_start, state_end = find_class_block(main, state_sig)
block = main[state_start:state_end]

if "StreamSubscription<CampusDataEvent>? _subscription;" not in block:
    block = block.replace(
        "  var _isFavoriting = false;\n",
        "  var _isFavoriting = false;\n  StreamSubscription<CampusDataEvent>? _subscription;\n",
        1,
    )
    print("✅ patch: PostFeedCard 添加事件订阅字段")

if "Future<void> _loadFavoriteStatus() async" not in block:
    insert_before = "  Future<void> _toggleLike() async {"
    methods = """  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;

      if (event.type == CampusEventType.postChanged &&
          (event.refId.isEmpty || event.refId == _post.id)) {
        final payload = event.payload;
        if (payload is CampusPost) {
          setState(() => _post = payload);
        }
        _loadFavoriteStatus();
        return;
      }

      if (event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.profileChanged) {
        _loadFavoriteStatus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PostFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likes != widget.post.likes ||
        oldWidget.post.comments != widget.post.comments ||
        oldWidget.post.saves != widget.post.saves ||
        oldWidget.post.title != widget.post.title ||
        oldWidget.post.body != widget.post.body) {
      _post = widget.post;
      _liked = false;
      _loadFavoriteStatus();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFavoriteStatus() async {
    final id = _post.id;
    if (id.isEmpty) return;

    try {
      final favorites = await CampusRepository.instance.fetchFavorites();
      if (!mounted || _post.id != id) return;

      final favorited = favorites.any((record) {
        return record.kind == 'post' && record.post.id == id;
      });

      if (_favorited != favorited) {
        setState(() => _favorited = favorited);
      }
    } catch (_) {
      // 收藏状态加载失败不影响首页卡片主流程。
    }
  }

"""
    if insert_before not in block:
        raise SystemExit("❌ PostFeedCard 没找到 _toggleLike 插入点")
    block = block.replace(insert_before, methods + insert_before, 1)
    print("✅ patch: PostFeedCard 添加 init/didUpdate/dispose/_loadFavoriteStatus")
else:
    print("✅ PostFeedCard 收藏状态加载方法已存在，跳过")

new_feed_like = """  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final previousPost = _post;
    final previousLiked = _liked;
    final nextLiked = !previousLiked;

    setState(() {
      _isLiking = true;
      _liked = nextLiked;
      final nextLikes = _post.likes + (nextLiked ? 1 : -1);
      _post = _post.copyWith(likes: nextLikes < 0 ? 0 : nextLikes);
    });

    try {
      final post = await CampusRepository.instance.togglePostLike(previousPost);
      if (!mounted) return;

      setState(() {
        _post = post;
        if (post.likes > previousPost.likes) {
          _liked = true;
        } else if (post.likes < previousPost.likes) {
          _liked = false;
        } else {
          _liked = nextLiked;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _post = previousPost;
        _liked = previousLiked;
      });
      _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }"""

m_start, m_end = find_method(block, "  Future<void> _toggleLike() async {")
if block[m_start:m_end] != new_feed_like:
    block = block[:m_start] + new_feed_like + block[m_end:]
    print("✅ patch: PostFeedCard 替换 _toggleLike")
else:
    print("✅ PostFeedCard _toggleLike 已是目标版本")

new_feed_fav = """  Future<void> _toggleFavorite() async {
    if (_isFavoriting) return;

    final previousPost = _post;
    final previousFavorited = _favorited;
    final nextFavorited = !previousFavorited;

    setState(() {
      _isFavoriting = true;
      _favorited = nextFavorited;
      final nextSaves = _post.saves + (nextFavorited ? 1 : -1);
      _post = _post.copyWith(saves: nextSaves < 0 ? 0 : nextSaves);
    });

    try {
      final post = await CampusRepository.instance.togglePostFavorite(
        previousPost,
      );
      if (!mounted) return;

      setState(() {
        _post = post;
        if (post.saves > previousPost.saves) {
          _favorited = true;
        } else if (post.saves < previousPost.saves) {
          _favorited = false;
        } else {
          _favorited = nextFavorited;
        }
      });

      _showShellMessage(context, _favorited ? '已收藏' : '已取消收藏');
      _loadFavoriteStatus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _post = previousPost;
        _favorited = previousFavorited;
      });
      _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isFavoriting = false);
    }
  }"""

m_start, m_end = find_method(block, "  Future<void> _toggleFavorite() async {")
if block[m_start:m_end] != new_feed_fav:
    block = block[:m_start] + new_feed_fav + block[m_end:]
    print("✅ patch: PostFeedCard 替换 _toggleFavorite")
else:
    print("✅ PostFeedCard _toggleFavorite 已是目标版本")

main = main[:state_start] + block + main[state_end:]
MAIN.write_text(main)

# =========================
# 2. 修帖子详情 PostDetailScreen：爱心状态
# =========================
detail = DETAIL.read_text()
backup(DETAIL, ".bak_post_detail_like_state_v1")

detail_start, detail_end = find_class_block(
    detail,
    "class _PostDetailScreenState extends State<PostDetailScreen> {",
)
dblock = detail[detail_start:detail_end]

if "var _postLiked = false;" not in dblock:
    dblock = dblock.replace(
        "  var _isFollowingAuthor = false;\n",
        "  var _isFollowingAuthor = false;\n  var _postLiked = false;\n",
        1,
    )
    print("✅ patch: PostDetailScreen 添加 _postLiked")
else:
    print("✅ PostDetailScreen _postLiked 已存在，跳过")

new_detail_like = """  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final previousPost = _post;
    final previousLiked = _postLiked;
    final nextLiked = !previousLiked;

    setState(() {
      _isLiking = true;
      _postLiked = nextLiked;
      final nextLikes = _post.likes + (nextLiked ? 1 : -1);
      _post = _post.copyWith(likes: nextLikes < 0 ? 0 : nextLikes);
    });

    try {
      final post = await CampusRepository.instance.togglePostLike(previousPost);
      if (!mounted) return;

      setState(() {
        _post = post;
        if (post.likes > previousPost.likes) {
          _postLiked = true;
        } else if (post.likes < previousPost.likes) {
          _postLiked = false;
        } else {
          _postLiked = nextLiked;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _post = previousPost;
        _postLiked = previousLiked;
      });
      _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }"""

m_start, m_end = find_method(dblock, "  Future<void> _toggleLike() async {")
if dblock[m_start:m_end] != new_detail_like:
    dblock = dblock[:m_start] + new_detail_like + dblock[m_end:]
    print("✅ patch: PostDetailScreen 替换 _toggleLike")
else:
    print("✅ PostDetailScreen _toggleLike 已是目标版本")

old_detail_like_stat = """              _ActionStat(
                icon: _isLiking ? Icons.hourglass_top_rounded : Icons.favorite,
                value: post.likes,
                color: AppColors.red,
                onTap: _isLiking ? null : _toggleLike,
              ),
"""

new_detail_like_stat = """              _ActionStat(
                icon: _isLiking
                    ? Icons.hourglass_top_rounded
                    : (_postLiked
                          ? Icons.favorite
                          : Icons.favorite_border_rounded),
                value: post.likes,
                color: _postLiked ? AppColors.red : AppColors.text,
                onTap: _isLiking ? null : _toggleLike,
              ),
"""

dblock = replace_once(
    dblock,
    old_detail_like_stat,
    new_detail_like_stat,
    "PostDetailScreen 爱心图标/颜色绑定 _postLiked",
)

detail = detail[:detail_start] + dblock + detail[detail_end:]
DETAIL.write_text(detail)

print("✅ post like/favorite sync patch done")
