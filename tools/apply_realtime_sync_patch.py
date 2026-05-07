#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'frontend' / 'frontend' / 'lib'
REPO = LIB / 'repositories' / 'campus_repository.dart'
ACT = LIB / 'screens' / 'activity_feature_pages.dart'
MAIN = LIB / 'screens' / 'main_shell.dart'
EVENT = LIB / 'repositories' / 'campus_event_bus.dart'

EVENT.write_text("""import 'dart:async';

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
    if (!_controller.isClosed) _controller.add(event);
  }
}
""", encoding='utf-8')

def save(path, text):
    path.write_text(text, encoding='utf-8')

repo = REPO.read_text(encoding='utf-8')
repo = '\n'.join([l for l in repo.splitlines() if l.strip() != "import 'campus_event_bus.dart';"]) + '\n'
repo = repo.replace("import 'auth_session.dart';", "import 'auth_session.dart';\nimport 'campus_event_bus.dart';", 1)
helper_pattern = r"\n\s*void _emitSync\(CampusEventType type, \{String refId = '', Object\? payload\}\) \{.*?\n\s*void _emitFeedChanged\(\) \{\n\s*_emitSync\(CampusEventType\.feedChanged\);\n\s*\}\n"
repo = re.sub(helper_pattern, '\n', repo, flags=re.S)
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
repo = repo.replace('  CampusFeed get cachedFeed => _cachedFeed;\n', '  CampusFeed get cachedFeed => _cachedFeed;\n' + helper + '\n', 1)
repo = repo.replace(');    _emitSync', ');\n    _emitSync')
repo = repo.replace('refId: id);', 'refId: activityId);')
repo = repo.replace('CampusEventType.groupChanged, refId: activityId', 'CampusEventType.groupChanged, refId: groupId')
repo = re.sub(r'(\n\s*_emitSync\(CampusEventType\.activityCommentChanged, refId: activityId\);)+', '\n    _emitSync(CampusEventType.activityCommentChanged, refId: activityId);', repo)
repo = repo.replace('refId: activityId, payload: comment', 'refId: id, payload: comment')
repo = repo.replace('activityCommentChanged, refId: activityId);', 'activityCommentChanged, refId: id);')
save(REPO, repo)

act = ACT.read_text(encoding='utf-8')
act = '\n'.join([l for l in act.splitlines() if l.strip() not in ["import 'dart:async';", "import '../repositories/campus_event_bus.dart';"]]) + '\n'
act = act.replace("import 'dart:io';", "import 'dart:io';\nimport 'dart:async';", 1)
act = act.replace("import '../repositories/campus_repository.dart';", "import '../repositories/campus_repository.dart';\nimport '../repositories/campus_event_bus.dart';", 1)
act = act.replace('    });\n          }\n\n  @override\n  void dispose()', '    });\n  }\n\n  @override\n  void dispose()')
act = act.replace('    });\n      }\n\n  @override\n  void dispose()', '    });\n  }\n\n  @override\n  void dispose()')
act = act.replace('    });\n      }\n\n  @override\n  void didUpdateWidget', '    });\n  }\n\n  @override\n  void didUpdateWidget')
act = re.sub(r'(\n\s*_syncSubscription\?\.cancel\(\);)+', '\n    _syncSubscription?.cancel();', act)
act = re.sub(r'(\n\s*_commentSubscription\?\.cancel\(\);)+', '\n    _commentSubscription?.cancel();', act)
save(ACT, act)

main = MAIN.read_text(encoding='utf-8')
main = '\n'.join([l for l in main.splitlines() if l.strip() not in ["import 'dart:async';", "import '../repositories/campus_event_bus.dart';"]]) + '\n'
main = "import 'dart:async';\n" + main
main = main.replace("import '../repositories/campus_repository.dart';", "import '../repositories/campus_repository.dart';\nimport '../repositories/campus_event_bus.dart';", 1)
main = main.replace('        WidgetsBinding.instance.addPostFrameCallback', '    WidgetsBinding.instance.addPostFrameCallback')
main = re.sub(r'(\n\s*_syncSubscription\?\.cancel\(\);)+', '\n    _syncSubscription?.cancel();', main)
save(MAIN, main)
print('repair done')
