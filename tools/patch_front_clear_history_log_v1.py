from pathlib import Path
import re

ROOT = Path("/Users/beiyu/Desktop/CampusSocialApp")
API = ROOT / "frontend/frontend/lib/services/campus_api_client.dart"
REPO = ROOT / "frontend/frontend/lib/repositories/campus_repository.dart"
MAIN = ROOT / "frontend/frontend/lib/screens/main_shell.dart"

def write_if_changed(path, text):
    old = path.read_text()
    if old != text:
        path.with_suffix(path.suffix + ".bak_front_clear_history_log_v1").write_text(old)
        path.write_text(text)
        print(f"patched {path}")
    else:
        print(f"unchanged {path}")

# 1. ApiClient clearHistory 日志
api = API.read_text()
m = re.search(
    r"  Future<void> clearHistory\(\{required String token\}\) async \{\n(?P<body>.*?)\n  \}\n\n  Future<List<CampusDraft>> fetchDrafts",
    api,
    flags=re.S,
)
if not m:
    raise SystemExit("没找到 ApiClient clearHistory 方法，请发 campus_api_client.dart 680-710 行")

body = m.group("body")
path_match = re.search(r"_deleteJson\(\s*['\"]([^'\"]+)['\"]", body)
api_path = path_match.group(1) if path_match else "/api/me/history"

api_replacement = f"""  Future<void> clearHistory({{required String token}}) async {{
    const path = '{api_path}';
    final tokenTail = token.length <= 6 ? token : token.substring(token.length - 6);
    // 临时日志：清空浏览记录前端请求链路
    // ignore: avoid_print
    print('[front:api:clearHistory] DELETE ' + path + ' tokenLen=' + token.length.toString() + ' tokenTail=' + tokenTail);
    try {{
      await _deleteJson(path, token: token);
      // ignore: avoid_print
      print('[front:api:clearHistory] success ' + path);
    }} catch (error, stack) {{
      // ignore: avoid_print
      print('[front:api:clearHistory] error ' + path + ' => ' + error.toString());
      // ignore: avoid_print
      print(stack);
      rethrow;
    }}
  }}

  Future<List<CampusDraft>> fetchDrafts"""
api = api[:m.start()] + api_replacement + api[m.end():]
write_if_changed(API, api)

# 2. Repository clearHistory 日志
repo = REPO.read_text()
m = re.search(
    r"  Future<void> clearHistory\(\) \{.*?\n  \}\n\n  Future<List<CampusDraft>> fetchDrafts",
    repo,
    flags=re.S,
)
if not m:
    m = re.search(
        r"  Future<void> clearHistory\(\) async \{.*?\n  \}\n\n  Future<List<CampusDraft>> fetchDrafts",
        repo,
        flags=re.S,
    )
if not m:
    raise SystemExit("没找到 Repository clearHistory 方法，请发 campus_repository.dart 628-645 行")

repo_replacement = """  Future<void> clearHistory() async {
    final token = _requireToken();
    // 临时日志：Repository 层
    // ignore: avoid_print
    print('[front:repo:clearHistory] enter tokenLen=${token.length}');
    try {
      await _apiClient.clearHistory(token: token);
      // ignore: avoid_print
      print('[front:repo:clearHistory] success');
    } catch (error, stack) {
      // ignore: avoid_print
      print('[front:repo:clearHistory] error => $error');
      // ignore: avoid_print
      print(stack);
      rethrow;
    }
  }

  Future<List<CampusDraft>> fetchDrafts"""
repo = repo[:m.start()] + repo_replacement + repo[m.end():]
write_if_changed(REPO, repo)

# 3. 浏览记录页面 _clear 日志
main = MAIN.read_text()
class_start = main.find("class _BrowsingHistoryScreenState")
if class_start == -1:
    raise SystemExit("没找到 _BrowsingHistoryScreenState")

clear_start = main.find("  Future<void> _clear() async {", class_start)
if clear_start == -1:
    raise SystemExit("没找到 _clear 方法")

next_override = main.find("\n  @override", clear_start)
if next_override == -1:
    raise SystemExit("没找到 _clear 后面的 @override，无法安全替换")

clear_replacement = """  Future<void> _clear() async {
    // 临时日志：页面层
    // ignore: avoid_print
    print('[front:ui:clearHistory] tap');
    try {
      await CampusRepository.instance.clearHistory();
      if (!mounted) return;
      setState(() => _future = Future.value(const <CampusHistoryRecord>[]));
      _showShellMessage(context, '浏览记录已清空');
      // ignore: avoid_print
      print('[front:ui:clearHistory] success');
    } catch (error, stack) {
      // ignore: avoid_print
      print('[front:ui:clearHistory] error => $error');
      // ignore: avoid_print
      print(stack);
      if (mounted) _showShellMessage(context, _shellError(error));
    }
  }
"""
main = main[:clear_start] + clear_replacement + main[next_override:]
write_if_changed(MAIN, main)

print("front clear history log patch done")
