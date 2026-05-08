#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys

PROJECT = Path.home() / "Desktop" / "CampusSocialApp"
REPO = PROJECT / "frontend/frontend/lib/repositories/campus_repository.dart"
MAIN = PROJECT / "frontend/frontend/lib/screens/main_shell.dart"


def backup(path: Path, suffix: str) -> None:
    bak = path.with_name(path.name + suffix)
    if not bak.exists():
        shutil.copy2(path, bak)
        print(f"✅ 已备份: {bak}")
    else:
        print(f"ℹ️ 备份已存在: {bak}")


def find_method_block(text: str, signature: str) -> tuple[int, int]:
    start = text.find(signature)
    if start < 0:
        raise RuntimeError(f"找不到方法: {signature}")
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"找不到方法开始括号: {signature}")

    depth = 0
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1
    raise RuntimeError(f"找不到方法结束括号: {signature}")


def replace_method(text: str, signature: str, replacement: str) -> str:
    start, end = find_method_block(text, signature)
    return text[:start] + replacement.rstrip() + text[end:]


def patch_repository() -> None:
    text = REPO.read_text(encoding="utf-8")
    backup(REPO, ".bak_home_refresh_loop_fix_v3")

    start, end = find_method_block(text, "  Future<List<CampusPost>> fetchMyPosts()")
    block = text[start:end]
    if "_emitFeedChanged();" in block:
        block = block.replace("    _emitFeedChanged();\n", "")
        text = text[:start] + block + text[end:]
        print("✅ 已移除 fetchMyPosts 内的 _emitFeedChanged，避免进入我的帖子触发首页循环刷新")
    else:
        print("ℹ️ fetchMyPosts 内没有 _emitFeedChanged，跳过")

    REPO.write_text(text, encoding="utf-8")


def patch_main_shell() -> None:
    text = MAIN.read_text(encoding="utf-8")
    backup(MAIN, ".bak_home_refresh_loop_fix_v3")

    noop_bind = """
  void _bindHomeRealtimeRefresh() {
    // 不在事件总线上再次发起网络刷新。
    // createPost/deletePost/updatePost 已经会更新 cachedFeed，
    // _feedSubscription 只需要把 cachedFeed 同步到页面即可。
    // 这样可以避免 fetchMyPosts / fetchFeed 之间互相触发导致页面一直转圈、卡顿。
  }"""

    if "  void _bindHomeRealtimeRefresh()" in text:
        text = replace_method(text, "  void _bindHomeRealtimeRefresh()", noop_bind)
        print("✅ 已禁用事件总线触发的重复网络刷新")
    else:
        print("ℹ️ 没找到 _bindHomeRealtimeRefresh，跳过")

    safe_refresh = """
  Future<void> _refreshFeed() async {
    if (_isRefreshing) return;
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      final feed = await CampusRepository.instance.fetchFeed();
      if (!mounted) return;
      setState(() {
        _feed = feed;
      });
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }"""

    if "  Future<void> _refreshFeed() async" in text:
        text = replace_method(text, "  Future<void> _refreshFeed() async", safe_refresh)
        print("✅ 已给 _refreshFeed 加并发保护和 finally 收尾，避免 loading 卡住")
    else:
        print("ℹ️ 没找到 _refreshFeed，跳过")

    MAIN.write_text(text, encoding="utf-8")


def main() -> None:
    if not PROJECT.exists():
        print(f"❌ 找不到项目目录: {PROJECT}")
        sys.exit(1)
    if not REPO.exists():
        print(f"❌ 找不到文件: {REPO}")
        sys.exit(1)
    if not MAIN.exists():
        print(f"❌ 找不到文件: {MAIN}")
        sys.exit(1)

    print("====== 修复首页/我的帖子循环刷新卡顿 v3 ======")
    patch_repository()
    patch_main_shell()
    print("✅ patch done")


if __name__ == "__main__":
    main()
