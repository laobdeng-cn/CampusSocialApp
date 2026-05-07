#!/usr/bin/env python3
"""Apply a lightweight realtime sync patch for the Flutter campus app.

This script is intentionally idempotent. It adds a small event bus and wires the
activity/comment related screens so local pages refresh after create/edit/delete,
join/cancel, favorite, notification and comment operations.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FRONTEND = ROOT / "frontend" / "frontend" / "lib"

EVENT_BUS = FRONTEND / "repositories" / "campus_event_bus.dart"
REPOSITORY = FRONTEND / "repositories" / "campus_repository.dart"
ACTIVITY_PAGES = FRONTEND / "screens" / "activity_feature_pages.dart"
MAIN_SHELL = FRONTEND / "screens" / "main_shell.dart"

EVENT_BUS_CONTENT = """import 'dart:async';

/// Lightweight in-process event bus for refreshing already-open pages after
/// create / edit / delete / join / cancel / favorite / comment operations.
enum CampusEventType {
  feedChanged,
  postChanged,
  activityChanged,
  activityCommentChanged,
  notificationChanged,
  groupChanged,
  profileChanged,
}

class CampusDataEvent {
  const CampusDataEvent(this.type, {this.refId = '', this.payload});

  final CampusEventType type;
  final String refId;
  final Object? payload;

  bool matches(CampusEventType targetType, {String? refId}) {
    if (type != targetType) return false;
    if (refId == null || refId.isEmpty) return true;
    return this.refId.isEmpty || this.refId == refId;
  }
}

class CampusEventBus {
  CampusEventBus._();

  static final CampusEventBus instance = CampusEventBus._();

  final StreamController<CampusDataEvent> _controller =
      StreamController<CampusDataEvent>.broadcast(sync: true);

  Stream<CampusDataEvent> get stream => _controller.stream;

  void emit(CampusDataEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
}
"""


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_if_changed(path: Path, content: str) -> bool:
    old = path.read_text(encoding="utf-8") if path.exists() else None
    if old == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def replace_once(content: str, old: str, new: str, label: str) -> tuple[str, bool]:
    if old not in content:
        return content, False
    return content.replace(old, new, 1), True


def ensure_import(content: str, import_line: str, after_line: str | None = None) -> tuple[str, bool]:
    if import_line in content:
        return content, False
    if after_line and after_line in content:
        return content.replace(after_line, after_line + "\n" + import_line, 1), True
    marker = "\n\n"
    if marker in content:
        return content.replace(marker, "\n" + import_line + marker, 1), True
    return import_line + "\n" + content, True


def find_block(content: str, signature: str) -> tuple[int, int] | None:
    start = content.find(signature)
    if start < 0:
        return None
    brace = content.find("{", start)
    if brace < 0:
        return None
    depth = 0
    for index in range(brace, len(content)):
        char = content[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return start, index + 1
    return None


def patch_function_before_return(
    content: str,
    signature: str,
    return_line: str,
    insertion: str,
) -> tuple[str, bool]:
    block_range = find_block(content, signature)
    if not block_range:
        return content, False
    start, end = block_range
    block = content[start:end]
    if insertion.strip() in block:
        return content, False
    marker = return_line
    pos = block.rfind(marker)
    if pos < 0:
        return content, False
    block = block[:pos] + insertion + block[pos:]
    return content[:start] + block + content[end:], True


def patch_function_before_close(content: str, signature: str, insertion: str) -> tuple[str, bool]:
    block_range = find_block(content, signature)
    if not block_range:
        return content, False
    start, end = block_range
    block = content[start:end]
    if insertion.strip() in block:
        return content, False
    close = block.rfind("\n  }")
    if close < 0:
        return content, False
    block = block[:close] + insertion + block[close:]
    return content[:start] + block + content[end:], True


def patch_repository() -> bool:
    content = read(REPOSITORY)
    changed = False

    content, did = ensure_import(
        content,
        "import 'campus_event_bus.dart';",
        "import 'auth_session.dart';",
    )
    changed |= did

    helper = """

  void _emitSync(CampusEventType type, {String refId = '', Object? payload}) {
    CampusEventBus.instance.emit(
      CampusDataEvent(type, refId: refId, payload: payload),
    );
  }

  void _emitFeedChanged() {
    _emitSync(CampusEventType.feedChanged);
  }
"""
    content, did = replace_once(
        content,
        "  CampusFeed get cachedFeed => _cachedFeed;\n",
        "  CampusFeed get cachedFeed => _cachedFeed;" + helper + "\n",
        "repo helper",
    )
    changed |= did

    replacements = [
        (
            "  Future<CampusPost> togglePostLike(CampusPost post) async {\n"
            "    final id = _requirePostId(post);\n"
            "    return _replaceCachedPost(\n"
            "      await _apiClient.togglePostLike(token: _requireToken(), postId: id),\n"
            "    );\n"
            "  }",
            "  Future<CampusPost> togglePostLike(CampusPost post) async {\n"
            "    final id = _requirePostId(post);\n"
            "    final next = _replaceCachedPost(\n"
            "      await _apiClient.togglePostLike(token: _requireToken(), postId: id),\n"
            "    );\n"
            "    _emitSync(CampusEventType.postChanged, refId: id, payload: next);\n"
            "    _emitFeedChanged();\n"
            "    return next;\n"
            "  }",
        ),
        (
            "  Future<CampusPost> togglePostFavorite(CampusPost post) async {\n"
            "    final id = _requirePostId(post);\n"
            "    return _replaceCachedPost(\n"
            "      await _apiClient.togglePostFavorite(token: _requireToken(), postId: id),\n"
            "    );\n"
            "  }",
            "  Future<CampusPost> togglePostFavorite(CampusPost post) async {\n"
            "    final id = _requirePostId(post);\n"
            "    final next = _replaceCachedPost(\n"
            "      await _apiClient.togglePostFavorite(token: _requireToken(), postId: id),\n"
            "    );\n"
            "    _emitSync(CampusEventType.postChanged, refId: id, payload: next);\n"
            "    _emitFeedChanged();\n"
            "    return next;\n"
            "  }",
        ),
        (
            "  Future<void> deleteComment(CampusMyCommentRecord comment) {\n"
            "    if (comment.id.isEmpty) {\n"
            "      throw const CampusApiException('这条评论暂未同步到后端');\n"
            "    }\n"
            "    return _apiClient.deleteComment(\n"
            "      token: _requireToken(),\n"
            "      commentId: comment.id,\n"
            "    );\n"
            "  }",
            "  Future<void> deleteComment(CampusMyCommentRecord comment) async {\n"
            "    if (comment.id.isEmpty) {\n"
            "      throw const CampusApiException('这条评论暂未同步到后端');\n"
            "    }\n"
            "    await _apiClient.deleteComment(\n"
            "      token: _requireToken(),\n"
            "      commentId: comment.id,\n"
            "    );\n"
            "    _emitSync(CampusEventType.postChanged, refId: comment.post.id);\n"
            "    _emitFeedChanged();\n"
            "  }",
        ),
        (
            "  Future<void> markNotificationsRead() {\n"
            "    return _apiClient.markNotificationsRead(token: _requireToken());\n"
            "  }",
            "  Future<void> markNotificationsRead() async {\n"
            "    await _apiClient.markNotificationsRead(token: _requireToken());\n"
            "    _emitSync(CampusEventType.notificationChanged);\n"
            "  }",
        ),
        (
            "  Future<CampusNotificationRecord> markNotificationRead(String notificationId) {\n"
            "    if (notificationId.isEmpty) {\n"
            "      throw const CampusApiException('这条通知暂未同步到后端');\n"
            "    }\n"
            "    return _apiClient.markNotificationRead(\n"
            "      token: _requireToken(),\n"
            "      notificationId: notificationId,\n"
            "    );\n"
            "  }",
            "  Future<CampusNotificationRecord> markNotificationRead(String notificationId) async {\n"
            "    if (notificationId.isEmpty) {\n"
            "      throw const CampusApiException('这条通知暂未同步到后端');\n"
            "    }\n"
            "    final next = await _apiClient.markNotificationRead(\n"
            "      token: _requireToken(),\n"
            "      notificationId: notificationId,\n"
            "    );\n"
            "    _emitSync(CampusEventType.notificationChanged, refId: notificationId);\n"
            "    return next;\n"
            "  }",
        ),
        (
            "  Future<void> deleteNotification(String notificationId) {\n"
            "    if (notificationId.isEmpty) {\n"
            "      throw const CampusApiException('这条通知暂未同步到后端');\n"
            "    }\n"
            "    return _apiClient.deleteNotification(\n"
            "      token: _requireToken(),\n"
            "      notificationId: notificationId,\n"
            "    );\n"
            "  }",
            "  Future<void> deleteNotification(String notificationId) async {\n"
            "    if (notificationId.isEmpty) {\n"
            "      throw const CampusApiException('这条通知暂未同步到后端');\n"
            "    }\n"
            "    await _apiClient.deleteNotification(\n"
            "      token: _requireToken(),\n"
            "      notificationId: notificationId,\n"
            "    );\n"
            "    _emitSync(CampusEventType.notificationChanged, refId: notificationId);\n"
            "  }",
        ),
    ]
    for old, new in replacements:
        content, did = replace_once(content, old, new, "repo replacement")
        changed |= did

    content, did = patch_function_before_return(
        content,
        "  CampusPost _replaceCachedPost(",
        "    return post;",
        "    _emitSync(CampusEventType.postChanged, refId: post.id, payload: post);\n"
        "    _emitFeedChanged();\n",
    )
    changed |= did
    content, did = patch_function_before_return(
        content,
        "  CampusActivity _replaceCachedActivity(",
        "    return activity;",
        "    _emitSync(CampusEventType.activityChanged, refId: activity.id, payload: activity);\n"
        "    _emitFeedChanged();\n",
    )
    changed |= did
    content, did = patch_function_before_return(
        content,
        "  CampusGroup _replaceCachedGroup(",
        "    return group;",
        "    _emitSync(CampusEventType.groupChanged, refId: group.id, payload: group);\n"
        "    _emitFeedChanged();\n",
    )
    changed |= did
    content, did = patch_function_before_close(
        content,
        "  void _removeCachedActivity(",
        "    _emitSync(CampusEventType.activityChanged, refId: id);\n"
        "    _emitFeedChanged();\n",
    )
    changed |= did
    content, did = patch_function_before_close(
        content,
        "  void _removeCachedGroup(",
        "    _emitSync(CampusEventType.groupChanged, refId: id);\n"
        "    _emitFeedChanged();\n",
    )
    changed |= did

    # Activity comments need a dedicated event because they don't necessarily change feed data.
    content, did = replace_once(
        content,
        "    return _apiClient.createActivityComment(\n"
        "      token: _requireToken(),\n"
        "      activityId: id,\n"
        "      text: text,\n"
        "    );",
        "    final comment = await _apiClient.createActivityComment(\n"
        "      token: _requireToken(),\n"
        "      activityId: id,\n"
        "      text: text,\n"
        "    );\n"
        "    _emitSync(CampusEventType.activityCommentChanged, refId: id, payload: comment);\n"
        "    _emitSync(CampusEventType.notificationChanged);\n"
        "    return comment;",
        "create activity comment emit",
    )
    changed |= did
    content, did = replace_once(
        content,
        "    await _apiClient.deleteActivityComment(\n"
        "      token: _requireToken(),\n"
        "      activityId: id,\n"
        "      commentId: comment.id,\n"
        "    );",
        "    await _apiClient.deleteActivityComment(\n"
        "      token: _requireToken(),\n"
        "      activityId: id,\n"
        "      commentId: comment.id,\n"
        "    );\n"
        "    _emitSync(CampusEventType.activityCommentChanged, refId: id);",
        "delete activity comment emit",
    )
    changed |= did

    return write_if_changed(REPOSITORY, content) or changed


def patch_activity_pages() -> bool:
    content = read(ACTIVITY_PAGES)
    changed = False

    content, did = ensure_import(content, "import 'dart:async';", "import 'dart:io';")
    changed |= did
    content, did = ensure_import(
        content,
        "import '../repositories/campus_event_bus.dart';",
        "import '../repositories/campus_repository.dart';",
    )
    changed |= did

    content, did = replace_once(
        content,
        "  late Future<List<_ActivityItem>> _activitiesFuture;\n",
        "  late Future<List<_ActivityItem>> _activitiesFuture;\n"
        "  StreamSubscription<CampusDataEvent>? _syncSubscription;\n",
        "all activity subscription field",
    )
    changed |= did
    content, did = replace_once(
        content,
        "    _activitiesFuture = _loadActivities();\n",
        "    _activitiesFuture = _loadActivities();\n"
        "    _syncSubscription = CampusEventBus.instance.stream.listen((event) {\n"
        "      if (!mounted) return;\n"
        "      if (event.type == CampusEventType.activityChanged ||\n"
        "          event.type == CampusEventType.feedChanged) {\n"
        "        _refreshActivities();\n"
        "      }\n"
        "    });\n",
        "all activity subscription init",
    )
    changed |= did
    content, did = replace_once(
        content,
        "    _searchController.dispose();\n",
        "    _syncSubscription?.cancel();\n"
        "    _searchController.dispose();\n",
        "all activity subscription dispose",
    )
    changed |= did

    content, did = replace_once(
        content,
        "  late Future<List<CampusActivity>> _activitiesFuture;\n"
        "  var _selectedTab = '全部';\n",
        "  late Future<List<CampusActivity>> _activitiesFuture;\n"
        "  StreamSubscription<CampusDataEvent>? _syncSubscription;\n"
        "  var _selectedTab = '全部';\n",
        "registered subscription field",
    )
    changed |= did
    content, did = replace_once(
        content,
        "    _activitiesFuture = CampusRepository.instance.fetchMyActivities();\n"
        "  }\n\n"
        "  Future<void> _refresh() async {",
        "    _activitiesFuture = CampusRepository.instance.fetchMyActivities();\n"
        "    _syncSubscription = CampusEventBus.instance.stream.listen((event) {\n"
        "      if (!mounted) return;\n"
        "      if (event.type == CampusEventType.activityChanged ||\n"
        "          event.type == CampusEventType.feedChanged) {\n"
        "        _refresh();\n"
        "      }\n"
        "    });\n"
        "  }\n\n"
        "  @override\n"
        "  void dispose() {\n"
        "    _syncSubscription?.cancel();\n"
        "    super.dispose();\n"
        "  }\n\n"
        "  Future<void> _refresh() async {",
        "registered subscription init dispose",
    )
    changed |= did

    content, did = replace_once(
        content,
        "  late Future<List<CampusComment>> _future;\n"
        "  final _controller = TextEditingController();\n"
        "  var _isSending = false;\n",
        "  late Future<List<CampusComment>> _future;\n"
        "  final _controller = TextEditingController();\n"
        "  StreamSubscription<CampusDataEvent>? _commentSubscription;\n"
        "  var _isSending = false;\n",
        "comment subscription field",
    )
    changed |= did
    content, did = replace_once(
        content,
        "    _future = CampusRepository.instance.fetchActivityComments(widget.activity);\n"
        "  }",
        "    _future = CampusRepository.instance.fetchActivityComments(widget.activity);\n"
        "    _commentSubscription = CampusEventBus.instance.stream.listen((event) {\n"
        "      if (!mounted) return;\n"
        "      if (event.matches(\n"
        "        CampusEventType.activityCommentChanged,\n"
        "        refId: widget.activity.id,\n"
        "      )) {\n"
        "        setState(() {\n"
        "          _future = CampusRepository.instance.fetchActivityComments(\n"
        "            widget.activity,\n"
        "          );\n"
        "        });\n"
        "      }\n"
        "    });\n"
        "  }",
        "comment subscription init",
    )
    changed |= did
    content, did = replace_once(
        content,
        "    _controller.dispose();\n"
        "    super.dispose();",
        "    _commentSubscription?.cancel();\n"
        "    _controller.dispose();\n"
        "    super.dispose();",
        "comment subscription dispose",
    )
    changed |= did

    return write_if_changed(ACTIVITY_PAGES, content) or changed


def patch_main_shell() -> bool:
    if not MAIN_SHELL.exists():
        return False
    content = read(MAIN_SHELL)
    changed = False

    if not content.startswith("import 'dart:async';") and "import 'dart:async';" not in content:
        content = "import 'dart:async';\n" + content
        changed = True
    content, did = ensure_import(
        content,
        "import '../repositories/campus_event_bus.dart';",
        "import '../repositories/campus_repository.dart';",
    )
    changed |= did

    content, did = replace_once(
        content,
        "  late CampusActivity _activity;\n"
        "  var _isFavoriting = false;\n",
        "  late CampusActivity _activity;\n"
        "  StreamSubscription<CampusDataEvent>? _syncSubscription;\n"
        "  var _isFavoriting = false;\n",
        "activity card subscription field",
    )
    changed |= did
    content, did = replace_once(
        content,
        "    _activity = widget.activity;\n"
        "  }\n\n"
        "  @override\n"
        "  void didUpdateWidget",
        "    _activity = widget.activity;\n"
        "    _syncSubscription = CampusEventBus.instance.stream.listen((event) {\n"
        "      if (!mounted || _activity.id.isEmpty) return;\n"
        "      if (event.matches(CampusEventType.activityChanged, refId: _activity.id) ||\n"
        "          event.type == CampusEventType.feedChanged) {\n"
        "        for (final item in CampusRepository.instance.cachedFeed.activities) {\n"
        "          if (item.id == _activity.id) {\n"
        "            setState(() => _activity = item);\n"
        "            break;\n"
        "          }\n"
        "        }\n"
        "      }\n"
        "    });\n"
        "  }\n\n"
        "  @override\n"
        "  void dispose() {\n"
        "    _syncSubscription?.cancel();\n"
        "    super.dispose();\n"
        "  }\n\n"
        "  @override\n"
        "  void didUpdateWidget",
        "activity card subscription init dispose",
    )
    changed |= did

    return write_if_changed(MAIN_SHELL, content) or changed


def main() -> None:
    changed = False
    changed |= write_if_changed(EVENT_BUS, EVENT_BUS_CONTENT)
    changed |= patch_repository()
    changed |= patch_activity_pages()
    changed |= patch_main_shell()
    if changed:
        print("Realtime sync patch applied.")
    else:
        print("Realtime sync patch already applied.")


if __name__ == "__main__":
    main()
