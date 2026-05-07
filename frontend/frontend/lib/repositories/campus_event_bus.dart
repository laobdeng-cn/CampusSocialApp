import 'dart:async';

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
