#!/usr/bin/env python3
"""Idempotent realtime sync patch and cleanup script for the Flutter app."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "frontend" / "frontend" / "lib"
EVENT_BUS = LIB / "repositories" / "campus_event_bus.dart"
REPOSITORY = LIB / "repositories" / "campus_repository.dart"
ACTIVITY_PAGES = LIB / "screens" / "activity_feature_pages.dart"
MAIN_SHELL = LIB / "screens" / "main_shell.dart"

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

HELPER = """
  void _emitSync(CampusEventType type, {String refId = '', Object? payload}) {
    CampusEventBus.instance.emit(
      CampusDataEvent(type, refId: refId, payload: payload),
    );
  }

  void _emitFeedChanged() {
    _emitSync(CampusEventType.feedChanged);
  }
"""

ACTIVITY_LISTENER = """    _syncSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.activityChanged ||
          event.type == CampusEventType.feedChanged) {
        _refreshActivities();
      }
    });
"""

REGISTERED_LISTENER = """    _syncSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.activityChanged ||
          event.type == CampusEventType.feedChanged) {
        _refresh();
      }
    });
"""

COMMENT_LISTENER = """    _commentSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.matches(
        CampusEventType.activityCommentChanged,
        refId: widget.activity.id,
      )) {
        setState(() {
          _future = CampusRepository.instance.fetchActivityComments(
            widget.activity,
          );
        });
      }
    });
"""

MAIN_CARD_LISTENER = """    _syncSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted || _activity.id.isEmpty) return;
      if (event.matches(CampusEventType.activityChanged, refId: _activity.id) ||
          event.type == CampusEventType.feedChanged) {
        for (final item in CampusRepository.instance.cachedFeed.activities) {
          if (item.id == _activity.id) {
            setState(() {
              _activity = item;
              _isRegistered = _realRegistered;
            });
            break;
          }
        }
      }
    });
"""


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write(path: Path, content: str) -> bool:
    old = path.read_text(encoding="utf-8") if path.exists() else None
    if old == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def dedupe_import(content: str, import_line: str, after_line: str | None = None) -> str:
    lines = [line for line in content.splitlines() if line.strip() != import_line.strip()]
    content = "\n".join(lines) + ("\n" if content.endswith("\n") else "")
    if after_line and after_line in content:
        return content.replace(after_line, after_line + "\n" + import_line, 1)
    return import_line + "\n" + content


def find_block(content: str, signature: str) -> tuple[int, int] | None:
    start = content.find(signature)
    if start < 0:
        return None
    brace = content.find("{", start)
    if brace < 0:
        return None
    depth = 0
    for i in range(brace, len(content)):
        if content[i] == "{":
            depth += 1
        elif content[i] == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1
    return None


def patch_class(content: str, signature: str, fn) -> str:
    target = find_block(content, signature)
    if not target:
        return content
    start, end = target
    block = fn(content[start:end])
    return content[:start] + block + content[end:]


def remove_listener_blocks(block: str, assignment: str) -> str:
    pattern = re.escape(assignment) + r" = CampusEventBus\.instance\.stream\.listen\(\(event\) \{[\s\S]*?^    \}\);\n"
    return re.sub(pattern, "", block, flags=re.MULTILINE)


def add_dispose_cancel(block: str, cancel_line: str, before_line: str | None = None) -> str:
    block = block.replace(f"    {cancel_line}\n", "")
    if "  void dispose()" not in block:
        insert = f"\n  @override\n  void dispose() {{\n    {cancel_line}\n    super.dispose();\n  }}\n"
        marker = "\n  @override\n  void didUpdateWidget"
        if marker in block:
            return block.replace(marker, insert + marker, 1)
        return block[:-1] + insert + "\n}"
    if before_line and before_line in block:
        return block.replace(before_line, f"    {cancel_line}\n" + before_line, 1)
    return block.replace("    super.dispose();", f"    {cancel_line}\n    super.dispose();", 1)


def patch_repository() -> bool:
    content = read(REPOSITORY)
    original = content
    content = dedupe_import(content, "import 'campus_event_bus.dart';", "import 'auth_session.dart';")

    # Keep exactly one helper block.
    content = re.sub(
        r"\n  void _emitSync\(CampusEventType type,[\s\S]*?\n  void _emitFeedChanged\(\) \{\n    _emitSync\(CampusEventType\.feedChanged\);\n  \}\n+",
        "\n",
        content,
    )
    content = content.replace("  CampusFeed get cachedFeed => _cachedFeed;\n", "  CampusFeed get cachedFeed => _cachedFeed;\n" + HELPER + "\n", 1)

    content = content.replace(");    _emitSync", ");\n    _emitSync")
    content = content.replace("_emitSync(CampusEventType.activityChanged, refId: id);", "_emitSync(CampusEventType.activityChanged, refId: activityId);")
    content = content.replace("_emitSync(CampusEventType.groupChanged, refId: id);", "_emitSync(CampusEventType.groupChanged, refId: groupId);")
    content = re.sub(r"(\n    _emitSync\(CampusEventType\.activityCommentChanged, refId: id\);)+", "\n    _emitSync(CampusEventType.activityCommentChanged, refId: id);", content)
    content = re.sub(r"\n{3,}", "\n\n", content)

    return write(REPOSITORY, content) or content != original


def patch_activity_pages() -> bool:
    content = read(ACTIVITY_PAGES)
    original = content
    content = dedupe_import(content, "import 'dart:async';", "import 'dart:io';")
    content = dedupe_import(content, "import '../repositories/campus_event_bus.dart';", "import '../repositories/campus_repository.dart';")
    content = content.replace("  StreamSubscription<CampusDataEvent>? _commentSubscription;\n", "")
    content = content.replace("    _commentSubscription?.cancel();\n", "")

    def patch_all(block: str) -> str:
        block = block.replace("  StreamSubscription<CampusDataEvent>? _syncSubscription;\n", "")
        block = block.replace("  late Future<List<_ActivityItem>> _activitiesFuture;\n", "  late Future<List<_ActivityItem>> _activitiesFuture;\n  StreamSubscription<CampusDataEvent>? _syncSubscription;\n", 1)
        block = remove_listener_blocks(block, "_syncSubscription")
        block = block.replace("    _activitiesFuture = _loadActivities();\n", "    _activitiesFuture = _loadActivities();\n" + ACTIVITY_LISTENER, 1)
        block = add_dispose_cancel(block, "_syncSubscription?.cancel();", "    _searchController.dispose();\n")
        return block

    def patch_registered(block: str) -> str:
        block = block.replace("  StreamSubscription<CampusDataEvent>? _syncSubscription;\n", "")
        block = block.replace("  late Future<List<CampusActivity>> _activitiesFuture;\n", "  late Future<List<CampusActivity>> _activitiesFuture;\n  StreamSubscription<CampusDataEvent>? _syncSubscription;\n", 1)
        block = remove_listener_blocks(block, "_syncSubscription")
        block = block.replace("    _activitiesFuture = CampusRepository.instance.fetchMyActivities();\n", "    _activitiesFuture = CampusRepository.instance.fetchMyActivities();\n" + REGISTERED_LISTENER, 1)
        block = add_dispose_cancel(block, "_syncSubscription?.cancel();")
        return block

    def patch_comment(block: str) -> str:
        block = block.replace("  StreamSubscription<CampusDataEvent>? _commentSubscription;\n", "")
        block = block.replace("  final _controller = TextEditingController();\n", "  final _controller = TextEditingController();\n  StreamSubscription<CampusDataEvent>? _commentSubscription;\n", 1)
        block = remove_listener_blocks(block, "_commentSubscription")
        block = block.replace("    _future = CampusRepository.instance.fetchActivityComments(widget.activity);\n", "    _future = CampusRepository.instance.fetchActivityComments(widget.activity);\n" + COMMENT_LISTENER, 1)
        block = add_dispose_cancel(block, "_commentSubscription?.cancel();", "    _controller.dispose();\n")
        return block

    content = patch_class(content, "class _ActivityAllScreenState extends State<ActivityAllScreen>", patch_all)
    content = patch_class(content, "class _MyRegisteredActivitiesScreenState", patch_registered)
    content = patch_class(content, "class _ActivityCommentSectionState extends State<_ActivityCommentSection>", patch_comment)
    content = re.sub(r"\n{3,}", "\n\n", content)
    return write(ACTIVITY_PAGES, content) or content != original


def patch_main_shell() -> bool:
    if not MAIN_SHELL.exists():
        return False
    content = read(MAIN_SHELL)
    original = content
    content = dedupe_import(content, "import 'dart:async';")
    content = dedupe_import(content, "import '../repositories/campus_event_bus.dart';", "import '../repositories/campus_repository.dart';")

    def patch_card(block: str) -> str:
        block = block.replace("  StreamSubscription<CampusDataEvent>? _syncSubscription;\n", "")
        block = block.replace("  late CampusActivity _activity;\n", "  late CampusActivity _activity;\n  StreamSubscription<CampusDataEvent>? _syncSubscription;\n", 1)
        block = remove_listener_blocks(block, "_syncSubscription")
        block = block.replace("    _activity = widget.activity;\n", "    _activity = widget.activity;\n" + MAIN_CARD_LISTENER, 1)
        block = add_dispose_cancel(block, "_syncSubscription?.cancel();")
        return block

    content = patch_class(content, "class _ActivityListCardState extends State<ActivityListCard>", patch_card)
    content = re.sub(r"\n{3,}", "\n\n", content)
    return write(MAIN_SHELL, content) or content != original


def main() -> None:
    changed = False
    changed |= write(EVENT_BUS, EVENT_BUS_CONTENT)
    changed |= patch_repository()
    changed |= patch_activity_pages()
    changed |= patch_main_shell()
    print("Realtime sync patch applied." if changed else "Realtime sync patch already applied.")


if __name__ == "__main__":
    main()
