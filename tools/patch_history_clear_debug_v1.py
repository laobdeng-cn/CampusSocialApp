from pathlib import Path
import re

ROOT = Path("/Users/beiyu/Desktop/CampusSocialApp")

BACKEND = ROOT / "backend/src/routes/index.js"
API = ROOT / "frontend/frontend/lib/services/campus_api_client.dart"
REPO = ROOT / "frontend/frontend/lib/repositories/campus_repository.dart"

def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".bak_history_clear_debug_v1")
    if not bak.exists():
        bak.write_text(path.read_text())
        print(f"✅ 备份: {bak}")

def replace_method(src: str, signature: str, replacement: str):
    start = src.find(signature)
    if start == -1:
        return src, False

    brace = src.find("{", start)
    if brace == -1:
        return src, False

    depth = 0
    end = None
    in_single = False
    in_double = False
    escape = False

    for i in range(brace, len(src)):
        ch = src[i]

        if escape:
            escape = False
            continue

        if ch == "\\":
            escape = True
            continue

        if ch == "'" and not in_double:
            in_single = not in_single
            continue

        if ch == '"' and not in_single:
            in_double = not in_double
            continue

        if in_single or in_double:
            continue

        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break

    if end is None:
        return src, False

    return src[:start] + replacement + src[end:], True

# 1. 后端 /me/history DELETE 加日志
backup(BACKEND)
s = BACKEND.read_text()

backend_route = """router.delete('/me/history', requireAuth, async (request, response, next) => {
  try {
    const userId = String(request.user?._id || '');
    console.log('[history:clear] enter', {
      userId,
      mongoReady: isMongoReady(),
      time: new Date().toISOString(),
    });

    const beforeCount = await BrowsingHistory.countDocuments({
      user: request.user._id,
    });

    const result = await BrowsingHistory.deleteMany({
      user: request.user._id,
    });

    const afterCount = await BrowsingHistory.countDocuments({
      user: request.user._id,
    });

    console.log('[history:clear] done', {
      userId,
      beforeCount,
      deletedCount: result.deletedCount,
      afterCount,
      time: new Date().toISOString(),
    });

    response.json({
      success: true,
      message: '浏览记录已清空',
      beforeCount,
      deletedCount: result.deletedCount || 0,
      afterCount,
    });
  } catch (error) {
    console.error('[history:clear] error', {
      message: error?.message,
      stack: error?.stack,
    });
    next(error);
  }
});"""

pattern = re.compile(
    r"router\.delete\('/me/history',\s*requireAuth,\s*async\s*\(request,\s*response,\s*next\)\s*=>\s*\{[\s\S]*?\n\}\);",
    re.M,
)

s2, n = pattern.subn(backend_route, s, count=1)

if n == 0:
    print("⚠️ 后端没找到 router.delete('/me/history')，未修改 backend/src/routes/index.js")
else:
    BACKEND.write_text(s2)
    print("✅ 后端清空浏览记录接口已加日志")

# 2. 前端 ApiClient.clearHistory 改成原始 HTTP 日志版
backup(API)
s = API.read_text()

api_method = """Future<void> clearHistory({required String token}) async {
    final uri = Uri.parse(baseUrl).replace(path: '/api/me/history');
    final client = HttpClient()..connectionTimeout = timeout;

    // ignore: avoid_print
    print('[api:clearHistory] start DELETE $uri token=${token.isNotEmpty}');

    try {
      final request = await client.deleteUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);

      // ignore: avoid_print
      print(
        '[api:clearHistory] response status=${response.statusCode} body=$responseBody',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CampusApiException(
          'Request failed with ${response.statusCode}: $responseBody',
        );
      }

      if (responseBody.trim().isNotEmpty) {
        try {
          jsonDecode(responseBody);
        } catch (error) {
          // ignore: avoid_print
          print('[api:clearHistory] jsonDecode error=$error body=$responseBody');
          throw CampusApiException('清空浏览记录返回格式异常: $responseBody');
        }
      }

      // ignore: avoid_print
      print('[api:clearHistory] success');
    } catch (error, stack) {
      // ignore: avoid_print
      print('[api:clearHistory] error=$error');
      // ignore: avoid_print
      print('[api:clearHistory] stack=$stack');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }"""

s2, ok = replace_method(
    s,
    "Future<void> clearHistory({required String token}) async",
    api_method,
)

if not ok:
    print("⚠️ 前端没找到 ApiClient.clearHistory，未修改 campus_api_client.dart")
else:
    API.write_text(s2)
    print("✅ 前端 ApiClient.clearHistory 已加日志")

# 3. Repository.clearHistory 加日志
backup(REPO)
s = REPO.read_text()

repo_method = """Future<void> clearHistory() async {
    final token = _requireToken();

    // ignore: avoid_print
    print('[repo:clearHistory] start token=${token.isNotEmpty}');

    try {
      await _apiClient.clearHistory(token: token);

      _emitSync(CampusEventType.profileChanged);
      _emitFeedChanged();

      // ignore: avoid_print
      print('[repo:clearHistory] success');
    } catch (error, stack) {
      // ignore: avoid_print
      print('[repo:clearHistory] error=$error');
      // ignore: avoid_print
      print('[repo:clearHistory] stack=$stack');
      rethrow;
    }
  }"""

s2, ok = replace_method(
    s,
    "Future<void> clearHistory()",
    repo_method,
)

if not ok:
    print("⚠️ 前端没找到 Repository.clearHistory，未修改 campus_repository.dart")
else:
    REPO.write_text(s2)
    print("✅ Repository.clearHistory 已加日志")

print("\\n✅ history clear debug patch done")
