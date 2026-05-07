#!/usr/bin/env python3
"""Idempotent realtime sync patch and repair script for the Flutter app."""
from __future__ import annotations

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


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write(path: Path, content: str) -> bool:
    old = path.read_text(encoding="utf-8") if path.exists() else None
    if old == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def ensure_import(content: str, import_line: str, after_line: str | None = None) -> str:
    if import_line in content:
        return content
    if after_line and after_line in content:
        return content.replace(after_line, after_line + "\n" + import_line, 1)
    return import_line + "\n" + content


def find_class_block(content: str, class_signature: str) -> tuple[int, int] | None:
    start = content.find(class_signature)
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


def find_method_block(block: str, method_signature: str) -> tuple[int, int] | None:
    start = block.find(method_signature)
    if start < 0:
        return None
    brace = block.find("{", start)
    if brace < 0:
        return None
    depth = 0
    for index in range(brace, len(block)):
        char = block[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return start, index + 1
    return None


def patch_activity_pages() -> bool:
    content = read(ACTIVITY_PAGES)
    original = content

    content = ensure_import(content, "import 'dart:async';", "import 'dart:io';")
    content = ensure_import(
        content,
        "import '../repositories/campus_event_bus.dart';",
        "import '../repositories/campus_repository.dart';",
    )

    # Repair an earlier broad text replacement: only the activity comment section owns this field.
    content = content.replace("    _commentSubscription?.cancel();\n", "")

    target = find_class_block(
        content,
        "class _ActivityCommentSectionState extends State<_ActivityCommentSection>",
    )
    if target:
        start, end = target
        block = content[start:end]
        if "StreamSubscription<CampusDataEvent>? _commentSubscription;" not in block:
            block = block.replace(
                "  final _controller = TextEditingController();\n",
                "  final _controller = TextEditingController();\n"
                "  StreamSubscription<CampusDataEvent>? _commentSubscription;\n",
                1,
            )
        if "CampusEventType.activityCommentChanged" not in block:
            block = block.replace(
                "    _future = CampusRepository.instance.fetchActivityComments(widget.activity);\n",
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
                "    });\n",
                1,
            )
        if "void dispose()" in block and "_commentSubscription?.cancel();" not in block:
            block = block.replace(
                "    _controller.dispose();\n",
                "    _commentSubscription?.cancel();\n"
                "    _controller.dispose();\n",
                1,
            )
        content = content[:start] + block + content[end:]

    return write(ACTIVITY_PAGES, content) or content != original


def patch_repository() -> bool:
    content = read(REPOSITORY)
    original = content

    content = ensure_import(content, "import 'campus_event_bus.dart';", "import 'auth_session.dart';")

    if "void _emitSync(CampusEventType type" not in content:
        content = content.replace(
            "  CampusFeed get cachedFeed => _cachedFeed;\n",
            "  CampusFeed get cachedFeed => _cachedFeed;\n\n"
            "  void _emitSync(CampusEventType type, {String refId = '', Object? payload}) {\n"
            "    CampusEventBus.instance.emit(\n"
            "      CampusDataEvent(type, refId: refId, payload: payload),\n"
            "    );\n"
            "  }\n\n"
            "  void _emitFeedChanged() {\n"
            "    _emitSync(CampusEventType.feedChanged);\n"
            "  }\n",
            1,
        )

    content = content.replace(");    _emitSync", ");\n    _emitSync")
    content = content.replace("\n\n\n   void _cacheFavoriteRecords", "\n\n  void _cacheFavoriteRecords")

    content = content.replace(
        "_emitSync(CampusEventType.activityChanged, refId: id);",
        "_emitSync(CampusEventType.activityChanged, refId: activityId);",
    )
    content = content.replace(
        "_emitSync(CampusEventType.groupChanged, refId: id);",
        "_emitSync(CampusEventType.groupChanged, refId: groupId);",
    )

    return write(REPOSITORY, content) or content != original


def patch_main_shell() -> bool:
    if not MAIN_SHELL.exists():
        return False
    content = read(MAIN_SHELL)
    original = content

    content = ensure_import(content, "import 'dart:async';")
    content = ensure_import(
        content,
        "import '../repositories/campus_event_bus.dart';",
        "import '../repositories/campus_repository.dart';",
    )

    target = find_class_block(content, "class _ActivityListCardState extends State<ActivityListCard>")
    if target:
        start, end = target
        block = content[start:end]
        if "StreamSubscription<CampusDataEvent>? _syncSubscription;" not in block:
            block = block.replace(
                "  late CampusActivity _activity;\n",
                "  late CampusActivity _activity;\n"
                "  StreamSubscription<CampusDataEvent>? _syncSubscription;\n",
                1,
            )
        if "CampusEventType.activityChanged" not in block:
            init_range = find_method_block(block, "  void initState()")
            if init_range:
                m_start, m_end = init_range
                method = block[m_start:m_end]
                method = method.replace(
                    "    _activity = widget.activity;\n",
                    "    _activity = widget.activity;\n"
                    "    _syncSubscription = CampusEventBus.instance.stream.listen((event) {\n"
                    "      if (!mounted || _activity.id.isEmpty) return;\n"
                    "      if (event.matches(CampusEventType.activityChanged, refId: _activity.id) ||\n"
                    "          event.type == CampusEventType.feedChanged) {\n"
                    "        for (final item in CampusRepository.instance.cachedFeed.activities) {\n"
                    "          if (item.id == _activity.id) {\n"
                    "            setState(() {\n"
                    "              _activity = item;\n"
                    "              _isRegistered = _realRegistered;\n"
                    "            });\n"
                    "            break;\n"
                    "          }\n"
                    "        }\n"
                    "      }\n"
                    "    });\n",
                    1,
                )
                block = block[:m_start] + method + block[m_end:]
        if "void dispose()" not in block:
            insert = (
                "\n  @override\n"
                "  void dispose() {\n"
                "    _syncSubscription?.cancel();\n"
                "    super.dispose();\n"
                "  }\n"
            )
            marker = "\n  @override\n  void didUpdateWidget"
            if marker in block:
                block = block.replace(marker, insert + marker, 1)
            else:
                block = block[:-1] + insert + "\n}"
        elif "_syncSubscription?.cancel();" not in block:
            block = block.replace("    super.dispose();", "    _syncSubscription?.cancel();\n    super.dispose();", 1)
        content = content[:start] + block + content[end:]

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
