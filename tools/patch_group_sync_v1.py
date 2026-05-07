from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "frontend" / "frontend" / "lib"
REPO = LIB / "repositories" / "campus_repository.dart"
MAIN = LIB / "screens" / "main_shell.dart"

def write_if_changed(path: Path, text: str):
    old = path.read_text(encoding="utf-8")
    if old != text:
        path.write_text(text, encoding="utf-8")
        print(f"patched {path}")
    else:
        print(f"unchanged {path}")

# ========== patch repository ==========
repo = REPO.read_text(encoding="utf-8")

# 确保 Repository 已经引入事件总线
if "import 'campus_event_bus.dart';" not in repo:
    repo = repo.replace(
        "import 'auth_session.dart';",
        "import 'auth_session.dart';\nimport 'campus_event_bus.dart';",
        1,
    )

old_replace_group = """  CampusGroup _replaceCachedGroup(CampusGroup nextGroup) {
    final enriched = _enrichGroup(nextGroup);
    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups
          .map((group) => group.id == enriched.id ? enriched : group)
          .toList(growable: false),
      topics: _cachedFeed.topics,
    );
    return enriched;
  }
"""

new_replace_group = """  CampusGroup _replaceCachedGroup(CampusGroup nextGroup) {
    final enriched = _enrichGroup(nextGroup);
    _cachedFeed = CampusFeed(
      users: _cachedFeed.users,
      posts: _cachedFeed.posts,
      activities: _cachedFeed.activities,
      groups: _cachedFeed.groups
          .map((group) => group.id == enriched.id ? enriched : group)
          .toList(growable: false),
      topics: _cachedFeed.topics,
    );

    if (enriched.id.isNotEmpty) {
      _emitSync(
        CampusEventType.groupChanged,
        refId: enriched.id,
        payload: enriched,
      );
    } else {
      _emitSync(CampusEventType.groupChanged, payload: enriched);
    }
    _emitFeedChanged();

    return enriched;
  }
"""

if old_replace_group in repo:
    repo = repo.replace(old_replace_group, new_replace_group, 1)
else:
    print("skip _replaceCachedGroup: exact block not matched or already patched")

# createGroup 创建成功后也要广播
old_create_return = """    );
    return enriched;
  }

  Future<CampusGroup> updateGroup({
"""

new_create_return = """    );
    _emitSync(
      CampusEventType.groupChanged,
      refId: enriched.id,
      payload: enriched,
    );
    _emitFeedChanged();
    return enriched;
  }

  Future<CampusGroup> updateGroup({
"""

if old_create_return in repo and "refId: enriched.id,\n      payload: enriched," not in repo[repo.find("Future<CampusGroup> createGroup"):repo.find("Future<CampusGroup> updateGroup")]:
    repo = repo.replace(old_create_return, new_create_return, 1)

# 入群审批后广播
review_pattern = r"""  Future<CampusGroupMember> reviewGroupJoinRequest\(\{
    required CampusGroup group,
    required CampusGroupMember request,
    required bool approved,
  \}\) \{
    final groupId = _requireGroupId\(group\);
    if \(request.id.isEmpty\) \{
      throw const CampusApiException\('这条申请暂未同步到后端'\);
    \}
    return _apiClient.reviewGroupJoinRequest\(
      token: _requireToken\(\),
      groupId: groupId,
      membershipId: request.id,
      approved: approved,
    \);
  \}
"""

review_replacement = """  Future<CampusGroupMember> reviewGroupJoinRequest({
    required CampusGroup group,
    required CampusGroupMember request,
    required bool approved,
  }) async {
    final groupId = _requireGroupId(group);
    if (request.id.isEmpty) {
      throw const CampusApiException('这条申请暂未同步到后端');
    }

    final member = await _apiClient.reviewGroupJoinRequest(
      token: _requireToken(),
      groupId: groupId,
      membershipId: request.id,
      approved: approved,
    );

    _emitSync(CampusEventType.groupChanged, refId: groupId);
    _emitSync(CampusEventType.notificationChanged);
    _emitFeedChanged();

    return member;
  }
"""

repo = re.sub(review_pattern, review_replacement, repo, count=1)

# 成员角色修改后广播
role_pattern = r"""  Future<CampusGroupMember> updateGroupMemberRole\(\{
    required CampusGroup group,
    required CampusGroupMember member,
    required String role,
  \}\) \{
    final groupId = _requireGroupId\(group\);
    if \(member.id.isEmpty\) \{
      throw const CampusApiException\('这位成员暂未同步到后端'\);
    \}
    return _apiClient.updateGroupMemberRole\(
      token: _requireToken\(\),
      groupId: groupId,
      membershipId: member.id,
      role: role,
    \);
  \}
"""

role_replacement = """  Future<CampusGroupMember> updateGroupMemberRole({
    required CampusGroup group,
    required CampusGroupMember member,
    required String role,
  }) async {
    final groupId = _requireGroupId(group);
    if (member.id.isEmpty) {
      throw const CampusApiException('这位成员暂未同步到后端');
    }

    final nextMember = await _apiClient.updateGroupMemberRole(
      token: _requireToken(),
      groupId: groupId,
      membershipId: member.id,
      role: role,
    );

    _emitSync(CampusEventType.groupChanged, refId: groupId);
    _emitFeedChanged();

    return nextMember;
  }
"""

repo = re.sub(role_pattern, role_replacement, repo, count=1)

# 移除成员后广播
remove_pattern = r"""  Future<void> removeGroupMember\(\{
    required CampusGroup group,
    required CampusGroupMember member,
  \}\) \{
    final groupId = _requireGroupId\(group\);
    if \(member.id.isEmpty\) \{
      throw const CampusApiException\('这位成员暂未同步到后端'\);
    \}
    return _apiClient.removeGroupMember\(
      token: _requireToken\(\),
      groupId: groupId,
      membershipId: member.id,
    \);
  \}
"""

remove_replacement = """  Future<void> removeGroupMember({
    required CampusGroup group,
    required CampusGroupMember member,
  }) async {
    final groupId = _requireGroupId(group);
    if (member.id.isEmpty) {
      throw const CampusApiException('这位成员暂未同步到后端');
    }

    await _apiClient.removeGroupMember(
      token: _requireToken(),
      groupId: groupId,
      membershipId: member.id,
    );

    _emitSync(CampusEventType.groupChanged, refId: groupId);
    _emitFeedChanged();
  }
"""

repo = re.sub(remove_pattern, remove_replacement, repo, count=1)

write_if_changed(REPO, repo)

# ========== patch main_shell _GroupTile ==========
main = MAIN.read_text(encoding="utf-8")

# import 去重
lines = main.splitlines()
lines = [line for line in lines if line.strip() not in {
    "import 'dart:async';",
    "import '../repositories/campus_event_bus.dart';",
}]
main = "\n".join(lines) + "\n"

main = "import 'dart:async';\n" + main
if "import '../repositories/campus_repository.dart';" in main:
    main = main.replace(
        "import '../repositories/campus_repository.dart';",
        "import '../repositories/campus_repository.dart';\nimport '../repositories/campus_event_bus.dart';",
        1,
    )

start = main.find("class _GroupTileState extends State<_GroupTile>")
if start < 0:
    print("skip _GroupTileState: class not found")
else:
    brace = main.find("{", start)
    depth = 0
    end = -1
    for i in range(brace, len(main)):
        if main[i] == "{":
            depth += 1
        elif main[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break

    block = main[start:end]

    if "StreamSubscription<CampusDataEvent>? _groupSubscription;" not in block:
        block = block.replace(
            "  late CampusGroup _group = widget.group;\n",
            "  late CampusGroup _group = widget.group;\n"
            "  StreamSubscription<CampusDataEvent>? _groupSubscription;\n",
            1,
        )

    if "void _syncFromCachedGroup" not in block:
        block = block.replace(
            "  var _isSubmitting = false;\n",
            """  var _isSubmitting = false;

  void _syncFromCachedGroup(CampusDataEvent event) {
    if (!mounted) return;
    final currentId = _group.id;
    if (currentId.isEmpty) return;

    if (!event.matches(CampusEventType.groupChanged, refId: currentId) &&
        event.type != CampusEventType.feedChanged) {
      return;
    }

    final payload = event.payload;
    if (payload is CampusGroup && payload.id == currentId) {
      setState(() => _group = payload);
      return;
    }

    for (final cached in CampusRepository.instance.cachedFeed.groups) {
      if (cached.id == currentId) {
        setState(() => _group = cached);
        return;
      }
    }
  }
""",
            1,
        )

    if "void initState()" not in block:
        block = block.replace(
            "  Future<void> _toggleJoin() async {",
            """  @override
  void initState() {
    super.initState();
    _groupSubscription = CampusEventBus.instance.stream.listen(_syncFromCachedGroup);
  }

  @override
  void didUpdateWidget(covariant _GroupTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id ||
        oldWidget.group.joined != widget.group.joined ||
        oldWidget.group.membershipStatus != widget.group.membershipStatus ||
        oldWidget.group.members != widget.group.members) {
      _group = widget.group;
    }
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleJoin() async {""",
            1,
        )

    main = main[:start] + block + main[end:]

write_if_changed(MAIN, main)

print("group sync v1 patch done")
