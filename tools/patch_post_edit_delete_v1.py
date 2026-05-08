from pathlib import Path
import re

ROOT = Path("/Users/beiyu/Desktop/CampusSocialApp")

API = ROOT / "frontend/frontend/lib/services/campus_api_client.dart"
REPO = ROOT / "frontend/frontend/lib/repositories/campus_repository.dart"
MAIN = ROOT / "frontend/frontend/lib/screens/main_shell.dart"
DETAIL = ROOT / "frontend/frontend/lib/screens/detail_pages.dart"

def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".bak_post_edit_delete_v1")
    if not bak.exists():
        bak.write_text(path.read_text())
        print(f"backup {bak}")

def write(path: Path, text: str):
    path.write_text(text)
    print(f"patched {path}")

def replace_method(src: str, signature: str, replacement: str):
    start = src.find(signature)
    if start == -1:
        return src, False

    brace = src.find("{", start)
    if brace == -1:
        return src, False

    depth = 0
    end = None
    in_single = False
    in_double = False
    escape = False

    for i in range(brace, len(src)):
        ch = src[i]

        if escape:
            escape = False
            continue

        if ch == "\\":
            escape = True
            continue

        if ch == "'" and not in_double:
            in_single = not in_single
            continue

        if ch == '"' and not in_single:
            in_double = not in_double
            continue

        if in_single or in_double:
            continue

        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break

    if end is None:
        return src, False

    return src[:start] + replacement + src[end:], True


# =========================================================
# 1. ApiClient 增加 updatePost
# =========================================================
backup(API)
api = API.read_text()

if "Future<CampusPost> updatePost({" not in api:
    insert = """  Future<CampusPost> updatePost({
    required String token,
    required String postId,
    required String title,
    required String body,
    required String topic,
    required String location,
    required List<String> images,
  }) async {
    final json = await _patchJson('/api/posts/$postId', {
      'title': title,
      'body': body,
      'topic': topic,
      'location': location,
      'images': images,
    }, token: token);
    return _readPostPayload(json);
  }

"""
    marker = "  Future<List<CampusPost>> fetchMyPosts({required String token}) async {"
    if marker not in api:
        raise SystemExit("ApiClient: 找不到 fetchMyPosts 插入点")
    api = api.replace(marker, insert + marker, 1)

write(API, api)


# =========================================================
# 2. Repository 增加 updatePost
# =========================================================
backup(REPO)
repo = REPO.read_text()

if "Future<CampusPost> updatePost({" not in repo:
    insert = """  Future<CampusPost> updatePost({
    required CampusPost post,
    required String title,
    required String body,
    required String topic,
    required String location,
    List<String> images = const [],
  }) async {
    final id = _requirePostId(post);
    final next = _replaceCachedPost(
      await _apiClient.updatePost(
        token: _requireToken(),
        postId: id,
        title: title,
        body: body,
        topic: topic,
        location: location,
        images: images,
      ),
    );

    _emitSync(CampusEventType.postChanged, refId: id, payload: next);
    _emitSync(CampusEventType.profileChanged);
    _emitFeedChanged();
    return next;
  }

"""
    marker = "  Future<void> deletePost(CampusPost post) async {"
    if marker not in repo:
        raise SystemExit("Repository: 找不到 deletePost 插入点")
    repo = repo.replace(marker, insert + marker, 1)

write(REPO, repo)


# =========================================================
# 3. PublishPostScreen 支持编辑帖子 initialPost
# =========================================================
backup(DETAIL)
detail = DETAIL.read_text()

# constructor
detail = detail.replace(
    "const PublishPostScreen({super.key, this.initialDraft});",
    "const PublishPostScreen({super.key, this.initialDraft, this.initialPost});",
)
detail = detail.replace(
    "const PublishPostScreen({super.key});",
    "const PublishPostScreen({super.key, this.initialDraft, this.initialPost});",
)

# fields
if "final CampusPost? initialPost;" not in detail:
    if "final CampusDraft? initialDraft;" in detail:
        detail = detail.replace(
            "final CampusDraft? initialDraft;",
            "final CampusDraft? initialDraft;\n  final CampusPost? initialPost;",
            1,
        )
    else:
        detail = detail.replace(
            "  @override\n  State<PublishPostScreen> createState()",
            "  final CampusDraft? initialDraft;\n  final CampusPost? initialPost;\n\n  @override\n  State<PublishPostScreen> createState()",
            1,
        )

# init fill
if "final post = widget.initialPost;" not in detail:
    detail = detail.replace(
        """  void _fillFromInitialDraft() {
    final draft = widget.initialDraft;
    if (draft == null) return;""",
        """  void _fillFromInitialDraft() {
    final post = widget.initialPost;
    if (post != null) {
      _titleController.text = post.title;
      _bodyController.text = post.body;
      if (post.topic.trim().isNotEmpty) {
        _topicController.text = post.topic.trim();
      }
      if (post.location.trim().isNotEmpty) {
        _locationController.text = post.location.trim();
      }
      _imageUrls
        ..clear()
        ..addAll(post.images);
      return;
    }

    final draft = widget.initialDraft;
    if (draft == null) return;""",
        1,
    )

# submit create/update
old_submit_block = """      await CampusRepository.instance.createPost(
        title: title,
        body: body,
        topic: _topicController.text.trim().isEmpty
            ? '校园生活'
            : _topicController.text.trim(),
        location: _locationController.text.trim(),
        images: _imageUrls,
      );
      await _deleteInitialDraftQuietly();
      if (!mounted) return;
      Navigator.pop(context, true);"""

new_submit_block = """      final topic = _topicController.text.trim().isEmpty
          ? '校园生活'
          : _topicController.text.trim();
      final location = _locationController.text.trim();

      if (widget.initialPost == null) {
        await CampusRepository.instance.createPost(
          title: title,
          body: body,
          topic: topic,
          location: location,
          images: _imageUrls,
        );
      } else {
        await CampusRepository.instance.updatePost(
          post: widget.initialPost!,
          title: title,
          body: body,
          topic: topic,
          location: location,
          images: _imageUrls,
        );
      }

      await _deleteInitialDraftQuietly();
      if (!mounted) return;
      Navigator.pop(context, true);"""

if old_submit_block in detail and "widget.initialPost == null" not in detail:
    detail = detail.replace(old_submit_block, new_submit_block, 1)

# title
detail = detail.replace(
    "title: Text(widget.initialDraft == null ? '发布动态' : '继续编辑'),",
    "title: Text(widget.initialPost != null ? '编辑帖子' : widget.initialDraft == null ? '发布动态' : '继续编辑'),",
)
detail = detail.replace(
    "title: const Text('发布动态'),",
    "title: Text(widget.initialPost != null ? '编辑帖子' : widget.initialDraft == null ? '发布动态' : '继续编辑'),",
)

# submit button text
detail = detail.replace(
    "child: Text(_isSubmitting ? '发布中...' : '发布'),",
    "child: Text(_isSubmitting ? '处理中...' : widget.initialPost != null ? '保存' : '发布'),",
)

# PostDetailScreen methods
if "Future<void> _editPost()" not in detail:
    insert_after = """  Future<void> _toggleAuthorFollow() async {
"""
    helper = """  bool get _isMine {
    final user = AuthSession.user;
    if (user == null) return false;
    if (user.id.isNotEmpty && _post.author.id.isNotEmpty) {
      return user.id == _post.author.id;
    }
    return user.name == _post.author.name;
  }

  CampusPost? _cachedPostById(String id) {
    if (id.isEmpty) return null;

    final feed = CampusRepository.instance.cachedFeed;
    for (final post in feed.posts) {
      if (post.id == id) return post;
    }

    for (final group in feed.groups) {
      for (final post in group.discussions) {
        if (post.id == id) return post;
      }
    }

    for (final topic in feed.topics) {
      for (final post in topic.posts) {
        if (post.id == id) return post;
      }
    }

    return null;
  }

  Future<void> _editPost() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PublishPostScreen(initialPost: _post),
      ),
    );

    if (changed == true && mounted) {
      final next = _cachedPostById(_post.id);
      if (next != null) {
        setState(() {
          _post = next;
        });
      }
      _showMessage(context, '帖子已更新');
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除帖子'),
          content: const Text('确定删除这条帖子吗？删除后评论、收藏和浏览记录也会同步移除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await CampusRepository.instance.deletePost(_post);
      if (!mounted) return;
      _showMessage(context, '帖子已删除');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  Future<void> _showPostActions() async {
    if (!_isMine) {
      _showMessage(context, '只能编辑或删除自己发布的帖子');
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑帖子'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                title: const Text('删除帖子', style: TextStyle(color: AppColors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'edit') {
      await _editPost();
    } else if (action == 'delete') {
      await _deletePost();
    }
  }

"""
    if insert_after not in detail:
        raise SystemExit("detail_pages: 找不到 _toggleAuthorFollow 插入点")
    detail = detail.replace(insert_after, helper + insert_after, 1)

# appbar action
detail = detail.replace(
    "IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),",
    "IconButton(onPressed: _showPostActions, icon: const Icon(Icons.more_horiz)),",
    1,
)

write(DETAIL, detail)


# =========================================================
# 4. main_shell 我的帖子/首页帖子卡片同步
# =========================================================
backup(MAIN)
main = MAIN.read_text()

# CampusShell 监听缓存变化，保证首页/社区能同步
if "_feedSubscription" not in main:
    main = main.replace(
        "  bool _isRefreshing = false;",
        "  bool _isRefreshing = false;\n  StreamSubscription<CampusDataEvent>? _feedSubscription;",
        1,
    )
    main = main.replace(
        "    _refreshFeed();\n  }",
        """    _refreshFeed();
    _feedSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.groupChanged ||
          event.type == CampusEventType.activityChanged) {
        setState(() {
          _feed = CampusRepository.instance.cachedFeed;
        });
      }
    });
  }""",
        1,
    )
    main = main.replace(
        "    campusTabIndexNotifier.removeListener(_syncExternalTabIndex);\n    super.dispose();",
        "    campusTabIndexNotifier.removeListener(_syncExternalTabIndex);\n    _feedSubscription?.cancel();\n    super.dispose();",
        1,
    )

# 我的帖子 State 加订阅和刷新
my_start = main.find("class _MyPostsScreenState extends State<_MyPostsScreen>")
if my_start == -1:
    raise SystemExit("main_shell: 找不到 _MyPostsScreenState")
my_next = main.find("\nclass ", my_start + 10)
my_block = main[my_start:my_next]

if "StreamSubscription<CampusDataEvent>? _subscription;" not in my_block:
    my_block = my_block.replace(
        "  late Future<List<CampusPost>> _future;",
        "  late Future<List<CampusPost>> _future;\n  StreamSubscription<CampusDataEvent>? _subscription;",
        1,
    )

if "_subscription = CampusEventBus.instance.stream.listen" not in my_block:
    my_block = my_block.replace(
        "    _future = CampusRepository.instance.fetchMyPosts();\n  }",
        """    _future = CampusRepository.instance.fetchMyPosts();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.profileChanged) {
        _refreshPosts();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _refreshPosts() {
    if (!mounted) return;
    setState(() {
      _future = CampusRepository.instance.fetchMyPosts();
    });
  }""",
        1,
    )

if "Future<void> _editPost(CampusPost post)" not in my_block:
    my_block = my_block.replace(
        "  Future<void> _deletePost(CampusPost post) async {",
        """  Future<void> _editPost(CampusPost post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PublishPostScreen(initialPost: post),
      ),
    );

    if (changed == true && mounted) {
      _refreshPosts();
      _showShellMessage(context, '帖子已更新');
    }
  }

  Future<void> _deletePost(CampusPost post) async {""",
        1,
    )

# 修复 setState 返回 Future 的写法
my_block = my_block.replace(
    "setState(() => _future = CampusRepository.instance.fetchMyPosts());",
    """setState(() {
        _future = CampusRepository.instance.fetchMyPosts();
      });""",
)

# 给每个帖子下面补编辑/删除操作区
old_card = """                _PostManageCard(
                  post: post,
                  onDelete: remotePosts.isEmpty
                      ? null
                      : () => _deletePost(post),
                ),
                const SizedBox(height: 14),"""

new_card = """                _PostManageCard(
                  post: post,
                  onDelete: remotePosts.isEmpty
                      ? null
                      : () => _deletePost(post),
                ),
                if (remotePosts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _PostManageInlineActions(
                    onEdit: () => _editPost(post),
                    onDelete: () => _deletePost(post),
                  ),
                ],
                const SizedBox(height: 14),"""

if old_card in my_block and "_PostManageInlineActions(" not in my_block:
    my_block = my_block.replace(old_card, new_card, 1)

main = main[:my_start] + my_block + main[my_next:]

# 新增操作按钮组件
if "class _PostManageInlineActions extends StatelessWidget" not in main:
    insert_before = "class PostFeedCard extends StatefulWidget"
    actions_class = """class _PostManageInlineActions extends StatelessWidget {
  const _PostManageInlineActions({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('编辑'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('删除'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
          ),
        ),
      ],
    );
  }
}

"""
    if insert_before not in main:
        raise SystemExit("main_shell: 找不到 PostFeedCard 插入点")
    main = main.replace(insert_before, actions_class + insert_before, 1)

# PostFeedCard 监听 widget 更新
pf_start = main.find("class _PostFeedCardState extends State<PostFeedCard>")
pf_next = main.find("\nclass ", pf_start + 10)
pf_block = main[pf_start:pf_next]

if "void didUpdateWidget(covariant PostFeedCard oldWidget)" not in pf_block:
    pf_block = pf_block.replace(
        "  var _isFavoriting = false;\n",
        """  var _isFavoriting = false;

  @override
  void didUpdateWidget(covariant PostFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.title != widget.post.title ||
        oldWidget.post.body != widget.post.body ||
        oldWidget.post.likes != widget.post.likes ||
        oldWidget.post.comments != widget.post.comments ||
        oldWidget.post.saves != widget.post.saves) {
      _post = widget.post;
    }
  }

""",
        1,
    )

main = main[:pf_start] + pf_block + main[pf_next:]

write(MAIN, main)

print("post edit/delete patch v1 done")
