from pathlib import Path
import re

ROOT = Path("/Users/beiyu/Desktop/CampusSocialApp")
MAIN = ROOT / "frontend/frontend/lib/screens/main_shell.dart"
DETAIL = ROOT / "frontend/frontend/lib/screens/detail_pages.dart"

main = MAIN.read_text()
detail = DETAIL.read_text()

# 1) PublishPostScreen 增加 initialDraft 参数
detail = detail.replace(
    "class PublishPostScreen extends StatefulWidget {\n  const PublishPostScreen({super.key});\n\n  @override",
    """class PublishPostScreen extends StatefulWidget {
  const PublishPostScreen({super.key, this.initialDraft});

  final CampusDraft? initialDraft;

  @override""",
)

# 2) 发布页 initState 回填草稿内容
if "void _fillFromInitialDraft()" not in detail:
    marker = """  final List<String> _imageUrls = [];
  var _isSubmitting = false;
  var _isUploadingImage = false;

  @override
  void dispose() {"""
    detail = detail.replace(
        marker,
        """  final List<String> _imageUrls = [];
  var _isSubmitting = false;
  var _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _fillFromInitialDraft();
  }

  void _fillFromInitialDraft() {
    final draft = widget.initialDraft;
    if (draft == null) return;

    _titleController.text = draft.title;
    _bodyController.text = draft.body;
    if (draft.topic.trim().isNotEmpty) {
      _topicController.text = draft.topic.trim();
    }
    if (draft.location.trim().isNotEmpty) {
      _locationController.text = draft.location.trim();
    }
    _imageUrls
      ..clear()
      ..addAll(draft.images);
  }

  Future<void> _deleteInitialDraftQuietly() async {
    final draft = widget.initialDraft;
    if (draft == null || draft.id.isEmpty) return;
    try {
      await CampusRepository.instance.deleteDraft(draft);
    } catch (_) {
      // 发布/另存成功后清理旧草稿失败不影响主流程。
    }
  }

  @override
  void dispose() {""",
    )

# 3) 发布成功后清理原草稿
detail = detail.replace(
    """      await CampusRepository.instance.createPost(
        title: title,
        body: body,
        topic: _topicController.text.trim().isEmpty
            ? '校园生活'
            : _topicController.text.trim(),
        location: _locationController.text.trim(),
        images: _imageUrls,
      );
      if (!mounted) return;
      Navigator.pop(context, true);""",
    """      await CampusRepository.instance.createPost(
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
      Navigator.pop(context, true);""",
)

# 4) 保存草稿时，如果来自旧草稿，保存新版后清理旧草稿，避免重复
detail = detail.replace(
    """      await CampusRepository.instance.saveDraft(
        title: title.isEmpty ? '未命名草稿' : title,
        body: body,
        topic: _topicController.text.trim().isEmpty
            ? '校园生活'
            : _topicController.text.trim(),
        location: _locationController.text.trim(),
        images: _imageUrls,
      );
      if (!mounted) return;
      Navigator.pop(context, true);""",
    """      await CampusRepository.instance.saveDraft(
        title: title.isEmpty ? '未命名草稿' : title,
        body: body,
        topic: _topicController.text.trim().isEmpty
            ? '校园生活'
            : _topicController.text.trim(),
        location: _locationController.text.trim(),
        images: _imageUrls,
      );
      await _deleteInitialDraftQuietly();
      if (!mounted) return;
      Navigator.pop(context, true);""",
)

# 5) 发布页标题区分普通发布 / 继续编辑
detail = detail.replace(
    "        title: const Text('发布动态'),",
    "        title: Text(widget.initialDraft == null ? '发布动态' : '继续编辑'),",
)

# 6) 草稿箱页面增加 _openDraft 方法
state_start = main.find("class _DraftBoxScreenState extends State<_DraftBoxScreen>")
if state_start == -1:
    raise SystemExit("找不到 _DraftBoxScreenState")

next_class = main.find("\nclass ", state_start + 10)
draft_state = main[state_start:next_class]

if "Future<void> _openDraft(CampusDraft draft)" not in draft_state:
    draft_state = draft_state.replace(
        "\n  @override\n  Widget build(BuildContext context) {",
        """
  Future<void> _openDraft(CampusDraft draft) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PublishPostScreen(initialDraft: draft),
      ),
    );

    if (changed == true && mounted) {
      setState(() {
        _future = CampusRepository.instance.fetchDrafts();
      });
    }
  }

  @override
  Widget build(BuildContext context) {""",
    )

# 7) 草稿箱给 DraftTile 传 onEdit
draft_state = re.sub(
    r"(_DraftTile\.fromDraft\(\s*draft:\s*draft,\s*)(onDelete:\s*\(\)\s*=>\s*_deleteDraft\(draft\),)",
    r"\1onEdit: () => _openDraft(draft),\n                    \2",
    draft_state,
)

main = main[:state_start] + draft_state + main[next_class:]

# 8) DraftTile factory 增加 onEdit 参数
main = re.sub(
    r"(factory _DraftTile\.fromDraft\(\{\s*required CampusDraft draft,\s*)",
    r"\1required VoidCallback onEdit,\n    ",
    main,
    count=1,
)

# 9) DraftTile.fromDraft return _DraftTile 时传入 onEdit
main = re.sub(
    r"(return _DraftTile\(\s*)",
    r"\1onEdit: onEdit,\n      ",
    main,
    count=1,
)

# 10) DraftTile 构造函数增加 onEdit 可选参数
main = re.sub(
    r"(const _DraftTile\(\{\s*)",
    r"\1this.onEdit,\n    ",
    main,
    count=1,
)

# 11) DraftTile 字段增加 onEdit
tile_start = main.find("class _DraftTile extends StatelessWidget")
if tile_start == -1:
    raise SystemExit("找不到 _DraftTile")

tile_next = main.find("\nclass ", tile_start + 10)
tile_block = main[tile_start:tile_next]

if "final VoidCallback? onEdit;" not in tile_block:
    # 放在 onDelete 字段附近；如果没有 onDelete，就放在 build 前
    if "final VoidCallback? onDelete;" in tile_block:
        tile_block = tile_block.replace(
            "final VoidCallback? onDelete;",
            "final VoidCallback? onDelete;\n  final VoidCallback? onEdit;",
        )
    elif "final VoidCallback onDelete;" in tile_block:
        tile_block = tile_block.replace(
            "final VoidCallback onDelete;",
            "final VoidCallback onDelete;\n  final VoidCallback? onEdit;",
        )
    else:
        tile_block = tile_block.replace(
            "\n  @override\n  Widget build",
            "\n  final VoidCallback? onEdit;\n\n  @override\n  Widget build",
        )

# 12) DraftTile 整张卡片可点击继续编辑
if "return CampusCard(\n      onTap: onEdit," not in tile_block:
    tile_block = tile_block.replace(
        "return CampusCard(",
        "return CampusCard(\n      onTap: onEdit,",
        1,
    )

main = main[:tile_start] + tile_block + main[tile_next:]

MAIN.write_text(main)
DETAIL.write_text(detail)

print("draft continue edit patch done")
