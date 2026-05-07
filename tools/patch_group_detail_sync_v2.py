from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DETAIL = ROOT / "frontend" / "frontend" / "lib" / "screens" / "detail_pages.dart"

text = DETAIL.read_text(encoding="utf-8")

# ===== 1. imports =====
if "import 'dart:async';" not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';",
        "import 'dart:async';\n\nimport 'package:flutter/material.dart';",
        1,
    )

if "import '../repositories/campus_event_bus.dart';" not in text:
    text = text.replace(
        "import '../repositories/campus_repository.dart';",
        "import '../repositories/campus_repository.dart';\nimport '../repositories/campus_event_bus.dart';",
        1,
    )

# ===== 2. add subscription field =====
old_fields = """class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late CampusGroup _group = widget.group;
  var _isLoading = false;
  var _isSubmitting = false;
"""

new_fields = """class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late CampusGroup _group = widget.group;
  StreamSubscription<CampusDataEvent>? _groupSubscription;
  var _isLoading = false;
  var _isSubmitting = false;
  var _isReloadingFromEvent = false;
"""

if old_fields in text:
    text = text.replace(old_fields, new_fields, 1)
else:
    print("skip fields: exact block not matched or already patched")

# ===== 3. replace initState / loadDetail area =====
old_block = """  @override
  void initState() {
    super.initState();
    Future<void>(() {
      return CampusRepository.instance.recordHistory(
        kind: 'group',
        refId: _group.id,
        title: _group.name,
        subtitle: '成员 ${_group.members} · 帖子 ${_group.discussions.length}',
        imageUrl: _group.iconUrl,
      );
    }).catchError((_) {});
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (_group.id.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final group = await CampusRepository.instance.fetchGroupDetail(_group);
      if (mounted) setState(() => _group = group);
    } catch (_) {
      // The screen can still render the feed copy if detail loading fails.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
"""

new_block = """  @override
  void initState() {
    super.initState();
    _groupSubscription = CampusEventBus.instance.stream.listen(_onGroupEvent);

    Future<void>(() {
      return CampusRepository.instance.recordHistory(
        kind: 'group',
        refId: _group.id,
        title: _group.name,
        subtitle: '成员 ${_group.members} · 帖子 ${_group.discussions.length}',
        imageUrl: _group.iconUrl,
      );
    }).catchError((_) {});

    _loadDetail();
  }

  @override
  void didUpdateWidget(covariant GroupDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id ||
        oldWidget.group.joined != widget.group.joined ||
        oldWidget.group.membershipStatus != widget.group.membershipStatus ||
        oldWidget.group.members != widget.group.members) {
      _group = widget.group;
      _loadDetail(showLoading: false);
    }
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }

  void _onGroupEvent(CampusDataEvent event) {
    if (!mounted) return;

    final groupId = _group.id;
    if (groupId.isEmpty) return;

    final isCurrentGroupEvent = event.matches(
      CampusEventType.groupChanged,
      refId: groupId,
    );

    if (!isCurrentGroupEvent) return;

    final payload = event.payload;
    if (payload is CampusGroup && payload.id == groupId) {
      setState(() => _group = payload);
    }

    _loadDetail(showLoading: false);
  }

  Future<void> _loadDetail({bool showLoading = true}) async {
    if (_group.id.isEmpty) return;
    if (_isReloadingFromEvent && !showLoading) return;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    if (!showLoading) {
      _isReloadingFromEvent = true;
    }

    try {
      final group = await CampusRepository.instance.fetchGroupDetail(_group);
      if (mounted) setState(() => _group = group);
    } catch (_) {
      // The screen can still render the feed copy if detail loading fails.
    } finally {
      if (!showLoading) {
        _isReloadingFromEvent = false;
      }
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }
"""

if old_block in text:
    text = text.replace(old_block, new_block, 1)
else:
    print("skip init/load block: exact block not matched or already patched")

# ===== 4. improve join pending message =====
old_toggle_message = """      _showMessage(
        context,
        group.joined ? '已加入 ${group.name}' : '已退出 ${group.name}',
      );
"""

new_toggle_message = """      if (group.membershipStatus == 'pending') {
        _showMessage(context, '入群申请已提交，等待管理员审核');
      } else {
        _showMessage(
          context,
          group.joined ? '已加入 ${group.name}' : '已退出 ${group.name}',
        );
      }
"""

if old_toggle_message in text:
    text = text.replace(old_toggle_message, new_toggle_message, 1)

DETAIL.write_text(text, encoding="utf-8")
print("patched detail_pages.dart group detail sync v2")
