from pathlib import Path

ROOT = Path.home() / "Desktop" / "CampusSocialApp"
MAIN = ROOT / "frontend" / "frontend" / "lib" / "screens" / "main_shell.dart"

text = MAIN.read_text(encoding="utf-8")
old = text

# 1. 在 CommunityScreen 里加一个状态覆盖方法：
# discover 返回的 recommendedGroups 可能没有 joined/membershipStatus，
# 所以优先用 Repository 缓存里的同 id 社群状态。
if "CampusGroup _syncCommunityGroupState(CampusGroup group)" not in text:
    marker = """  Future<void> _refresh() async {
    await widget.onRefresh();
    await _loadDiscover();
  }
"""
    insert = marker + """
  CampusGroup _syncCommunityGroupState(CampusGroup group) {
    if (group.id.isEmpty) return group;

    for (final cached in CampusRepository.instance.cachedFeed.groups) {
      if (cached.id == group.id) {
        return cached;
      }
    }

    return group;
  }
"""
    if marker not in text:
        raise SystemExit("未找到 CommunityScreen._refresh 方法，请先把 918-970 行发我")
    text = text.replace(marker, insert, 1)

# 2. 推荐群组列表渲染前，统一套用缓存状态
old_block = """    final recommendedGroups = groups.isEmpty
        ? [programmingGroup]
        : groups.take(3).toList(growable: false);"""

new_block = """    final recommendedGroups = groups.isEmpty
        ? [_syncCommunityGroupState(programmingGroup)]
        : groups
              .take(3)
              .map(_syncCommunityGroupState)
              .toList(growable: false);"""

if old_block in text:
    text = text.replace(old_block, new_block, 1)
elif "_syncCommunityGroupState(programmingGroup)" not in text:
    raise SystemExit("未找到 recommendedGroups 代码块，请把 CommunityScreen build 940-970 行发我")

# 3. _GroupTile 接收到新 group 后，强制同步本地 _group，避免 StatefulWidget 保留旧按钮状态
start = text.find("class _GroupTileState extends State<_GroupTile> {")
if start < 0:
    raise SystemExit("未找到 _GroupTileState")

toggle_pos = text.find("  Future<void> _toggleJoin() async {", start)
if toggle_pos < 0:
    raise SystemExit("未找到 _GroupTileState._toggleJoin")

state_block = text[start:toggle_pos]

if "void didUpdateWidget(covariant _GroupTile oldWidget)" not in state_block:
    inject = """  @override
  void didUpdateWidget(covariant _GroupTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _group = widget.group;
  }

"""
    text = text[:toggle_pos] + inject + text[toggle_pos:]
else:
    # 如果已有 didUpdateWidget，改成无条件同步，避免条件漏掉 canManage / membershipRole 等字段
    method_start = text.find("  @override\n  void didUpdateWidget(covariant _GroupTile oldWidget)", start, toggle_pos)
    if method_start >= 0:
        next_override = text.find("\n  @override", method_start + 5)
        next_future = text.find("\n  Future<void> _toggleJoin()", method_start)
        method_end_candidates = [p for p in [next_override, next_future] if p > method_start]
        method_end = min(method_end_candidates)
        replacement = """  @override
  void didUpdateWidget(covariant _GroupTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _group = widget.group;
  }
"""
        text = text[:method_start] + replacement + text[method_end:]

if text != old:
    MAIN.write_text(text, encoding="utf-8")
    print(f"patched {MAIN}")
else:
    print("no changes")

print("✅ community joined sync v3 done")
