#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path("/Users/beiyu/Desktop/CampusSocialApp")
MAIN = ROOT / "frontend/frontend/lib/screens/main_shell.dart"
DETAIL = ROOT / "frontend/frontend/lib/screens/detail_pages.dart"
REPO = ROOT / "frontend/frontend/lib/repositories/campus_repository.dart"
API = ROOT / "frontend/frontend/lib/services/campus_api_client.dart"

def text(p): return p.read_text()
def backup(p):
    b = p.with_suffix(p.suffix + ".bak_my_posts_real_v1")
    if not b.exists():
        b.write_text(text(p))
        print("backup", b)
def write(p, s):
    if text(p) != s:
        p.write_text(s)
        print("patched", p)
    else:
        print("no change", p)
def class_block(src, decl):
    s = src.find(decl)
    if s < 0: return -1, -1, ""
    e = src.find("\nclass ", s + len(decl))
    if e < 0: e = len(src)
    return s, e, src[s:e]
def before(src, marker, ins):
    if ins.strip() in src: return src
    if marker not in src: raise SystemExit("missing marker: " + marker[:80])
    return src.replace(marker, ins + marker, 1)

# ApiClient updatePost
backup(API)
api = text(API)
if "Future<CampusPost> updatePost({" not in api:
    api = before(api, "  Future<List<CampusPost>> fetchMyPosts({required String token}) async {", """  Future<CampusPost> updatePost({
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

""")
write(API, api)

# Repository updatePost
backup(REPO)
repo = text(REPO)
if "Future<CampusPost> updatePost({" not in repo:
    repo = before(repo, "  Future<void> deletePost(CampusPost post) async {", """  Future<CampusPost> updatePost({
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

""")
if "_emitSync(CampusEventType.postChanged, refId: id);" in repo and "_emitSync(CampusEventType.profileChanged);" not in repo.split("_emitSync(CampusEventType.postChanged, refId: id);", 1)[1][:180]:
    repo = repo.replace("_emitSync(CampusEventType.postChanged, refId: id);\n    _emitFeedChanged();",
                        "_emitSync(CampusEventType.postChanged, refId: id);\n    _emitSync(CampusEventType.profileChanged);\n    _emitFeedChanged();", 1)
write(REPO, repo)

# detail_pages: PublishPostScreen edit post
backup(DETAIL)
detail = text(DETAIL)
detail = detail.replace("const PublishPostScreen({super.key});", "const PublishPostScreen({super.key, this.initialDraft, this.initialPost});")
detail = detail.replace("const PublishPostScreen({super.key, this.initialDraft});", "const PublishPostScreen({super.key, this.initialDraft, this.initialPost});")
if "final CampusPost? initialPost;" not in detail:
    if "final CampusDraft? initialDraft;" in detail:
        detail = detail.replace("final CampusDraft? initialDraft;", "final CampusDraft? initialDraft;\n  final CampusPost? initialPost;", 1)
    else:
        detail = detail.replace("  @override\n  State<PublishPostScreen> createState()", "  final CampusDraft? initialDraft;\n  final CampusPost? initialPost;\n\n  @override\n  State<PublishPostScreen> createState()", 1)

# Fill post content into edit screen
if "void _fillFromInitialPostOrDraft()" not in detail and "void _fillFromInitialDraft()" not in detail:
    ip = detail.find("  @override\n  void dispose()", detail.find("class _PublishPostScreenState"))
    if ip < 0: raise SystemExit("missing PublishPostScreen dispose")
    detail = detail[:ip] + """  @override
  void initState() {
    super.initState();
    _fillFromInitialPostOrDraft();
  }

  void _fillFromInitialPostOrDraft() {
    final post = widget.initialPost;
    if (post != null) {
      _titleController.text = post.title;
      _bodyController.text = post.body;
      if (post.topic.trim().isNotEmpty) _topicController.text = post.topic.trim();
      if (post.location.trim().isNotEmpty) _locationController.text = post.location.trim();
      _imageUrls
        ..clear()
        ..addAll(post.images);
      return;
    }

    final draft = widget.initialDraft;
    if (draft != null) {
      _titleController.text = draft.title;
      _bodyController.text = draft.body;
      if (draft.topic.trim().isNotEmpty) _topicController.text = draft.topic.trim();
      if (draft.location.trim().isNotEmpty) _locationController.text = draft.location.trim();
      _imageUrls
        ..clear()
        ..addAll(draft.images);
    }
  }

""" + detail[ip:]
elif "void _fillFromInitialDraft()" in detail and "final post = widget.initialPost;" not in detail[detail.find("void _fillFromInitialDraft()"):detail.find("void _fillFromInitialDraft()")+1000]:
    detail = detail.replace("""  void _fillFromInitialDraft() {
    final draft = widget.initialDraft;
    if (draft == null) return;""", """  void _fillFromInitialDraft() {
    final post = widget.initialPost;
    if (post != null) {
      _titleController.text = post.title;
      _bodyController.text = post.body;
      if (post.topic.trim().isNotEmpty) _topicController.text = post.topic.trim();
      if (post.location.trim().isNotEmpty) _locationController.text = post.location.trim();
      _imageUrls
        ..clear()
        ..addAll(post.images);
      return;
    }

    final draft = widget.initialDraft;
    if (draft == null) return;""", 1)

old = """      await CampusRepository.instance.createPost(
        title: title,
        body: body,
        topic: _topicController.text.trim().isEmpty
            ? '校园生活'
            : _topicController.text.trim(),
        location: _locationController.text.trim(),
        images: _imageUrls,
      );"""
if old in detail and "CampusRepository.instance.updatePost(" not in detail[detail.find("Future<void> _submit()"):detail.find("Future<void> _submit()")+2000]:
    detail = detail.replace(old, """      final topic = _topicController.text.trim().isEmpty
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
      }""", 1)

detail = detail.replace("title: const Text('发布动态'),", "title: Text(widget.initialPost != null ? '编辑帖子' : widget.initialDraft == null ? '发布动态' : '继续编辑'),")
detail = detail.replace("title: Text(widget.initialDraft == null ? '发布动态' : '继续编辑'),", "title: Text(widget.initialPost != null ? '编辑帖子' : widget.initialDraft == null ? '发布动态' : '继续编辑'),")
detail = detail.replace("child: Text(_isSubmitting ? '发布中...' : '发布'),", "child: Text(_isSubmitting ? '处理中...' : widget.initialPost != null ? '保存' : '发布'),")

# PostDetail more actions
if "Future<void> _showPostActions()" not in detail and "  Future<void> _toggleAuthorFollow() async {" in detail:
    detail = detail.replace("  Future<void> _toggleAuthorFollow() async {", """  bool get _isMine {
    final user = AuthSession.user;
    if (user == null) return false;
    if (user.id.isNotEmpty && _post.author.id.isNotEmpty) return user.id == _post.author.id;
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
      MaterialPageRoute(builder: (_) => PublishPostScreen(initialPost: _post)),
    );
    if (changed == true && mounted) {
      final next = _cachedPostById(_post.id);
      if (next != null) setState(() => _post = next);
      _showMessage(context, '帖子已更新');
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除帖子'),
        content: const Text('确定删除这条帖子吗？删除后将不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
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
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
    if (action == 'edit') await _editPost();
    if (action == 'delete') await _deletePost();
  }

  Future<void> _toggleAuthorFollow() async {""", 1)
detail = detail.replace("IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),", "IconButton(onPressed: _showPostActions, icon: const Icon(Icons.more_horiz)),", 1)
write(DETAIL, detail)

# main_shell: My posts real-only
backup(MAIN)
main = text(MAIN)

if "_feedSubscription" not in main:
    main = main.replace("  bool _isRefreshing = false;", "  bool _isRefreshing = false;\n  StreamSubscription<CampusDataEvent>? _feedSubscription;", 1)
    main = main.replace("    _refreshFeed();\n  }", """    _refreshFeed();
    _feedSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.groupChanged ||
          event.type == CampusEventType.activityChanged) {
        setState(() => _feed = CampusRepository.instance.cachedFeed);
      }
    });
  }""", 1)
    main = main.replace("    campusTabIndexNotifier.removeListener(_syncExternalTabIndex);\n    super.dispose();", "    campusTabIndexNotifier.removeListener(_syncExternalTabIndex);\n    _feedSubscription?.cancel();\n    super.dispose();", 1)

s, e, block = class_block(main, "class _MyPostsScreenState extends State<_MyPostsScreen>")
if not block: raise SystemExit("missing _MyPostsScreenState")

if "StreamSubscription<CampusDataEvent>? _subscription;" not in block:
    block = block.replace("  late Future<List<CampusPost>> _future;", "  late Future<List<CampusPost>> _future;\n  StreamSubscription<CampusDataEvent>? _subscription;", 1)

if "_subscription = CampusEventBus.instance.stream.listen" not in block:
    block = block.replace("    _future = CampusRepository.instance.fetchMyPosts();\n  }", """    _future = CampusRepository.instance.fetchMyPosts();
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
  }""", 1)

if "Future<void> _editPost(CampusPost post)" not in block:
    block = block.replace("  Future<void> _deletePost(CampusPost post) async {", """  Future<void> _editPost(CampusPost post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PublishPostScreen(initialPost: post)),
    );
    if (changed == true && mounted) {
      _refreshPosts();
      _showShellMessage(context, '帖子已更新');
    }
  }

  Future<void> _deletePost(CampusPost post) async {""", 1)

block = block.replace("setState(() => _future = CampusRepository.instance.fetchMyPosts());", "_refreshPosts();")
block = block.replace("final posts = remotePosts.isEmpty ? _fallbackPosts() : remotePosts;", "final posts = remotePosts;")
block = block.replace("final posts = snapshot.data?.isEmpty == true ? _fallbackPosts() : snapshot.data ?? const <CampusPost>[];", "final posts = snapshot.data ?? const <CampusPost>[];")

if "暂无真实帖子数据" not in block:
    block = block.replace("""              const SizedBox(height: 14),
              for (final post in posts) ...[""", """              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (posts.isEmpty)
                CampusCard(
                  child: Column(
                    children: [
                      const Icon(Icons.article_outlined, size: 46, color: AppColors.muted),
                      const SizedBox(height: 12),
                      const Text(
                        '暂无真实帖子数据',
                        style: TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text('发布一条动态后，会自动显示在这里', style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 14),
                      PrimaryButton(
                        label: '去发布帖子',
                        onPressed: () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => const PublishPostScreen()),
                          );
                          if (created == true) _refreshPosts();
                        },
                      ),
                    ],
                  ),
                ),
              for (final post in posts) ...[""", 1)

old1 = """                _PostManageCard(
                  post: post,
                  onDelete: remotePosts.isEmpty
                      ? null
                      : () => _deletePost(post),
                ),
                const SizedBox(height: 14),"""
new1 = """                _PostManageCard(
                  post: post,
                  onDelete: () => _deletePost(post),
                ),
                const SizedBox(height: 8),
                _PostManageInlineActions(
                  onEdit: () => _editPost(post),
                  onDelete: () => _deletePost(post),
                ),
                const SizedBox(height: 14),"""
if old1 in block and "_PostManageInlineActions(" not in block:
    block = block.replace(old1, new1, 1)
old2 = """                _PostManageCard(
                  post: post,
                  onDelete: () => _deletePost(post),
                ),
                const SizedBox(height: 14),"""
if old2 in block and "_PostManageInlineActions(" not in block:
    block = block.replace(old2, new1, 1)

main = main[:s] + block + main[e:]

if "class _PostManageInlineActions extends StatelessWidget" not in main:
    actions = """class _PostManageInlineActions extends StatelessWidget {
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
    marker = "class PostFeedCard extends StatefulWidget"
    if marker in main:
        main = main.replace(marker, actions + marker, 1)
    else:
        main += "\n" + actions

# PostFeedCard sync
ps, pe, pblock = class_block(main, "class _PostFeedCardState extends State<PostFeedCard>")
if pblock and "void didUpdateWidget(covariant PostFeedCard oldWidget)" not in pblock:
    pblock = pblock.replace("  var _isFavoriting = false;\n", """  var _isFavoriting = false;

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

""", 1)
    main = main[:ps] + pblock + main[pe:]

write(MAIN, main)
print("\nDONE: 我的帖子真实数据 + 编辑删除 v1")
