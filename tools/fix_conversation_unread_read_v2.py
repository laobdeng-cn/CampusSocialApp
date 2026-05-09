from pathlib import Path
import re

BACKEND = Path("backend/src/routes/index.js")
API = Path("frontend/frontend/lib/services/campus_api_client.dart")
REPO = Path("frontend/frontend/lib/repositories/campus_repository.dart")
MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")

# ===== 1. 后端新增 read-v2，避免旧路由没生效 =====
backend = BACKEND.read_text()
bak = BACKEND.with_suffix(".js.bak_fix_conversation_unread_read_v2")
if not bak.exists():
    bak.write_text(backend)

if "const Conversation = require('../models/Conversation');" not in backend:
    backend = "const Conversation = require('../models/Conversation');\n" + backend

if "const Message = require('../models/Message');" not in backend:
    backend = "const Message = require('../models/Message');\n" + backend

route = r'''
router.post('/conversations/:id/read-v2', requireAuth, async (request, response, next) => {
  try {
    const conversation = await Conversation.findOne({
      _id: request.params.id,
      participants: request.user._id,
    });

    if (!conversation) {
      response.status(404).json({ message: '会话不存在或无权限访问' });
      return;
    }

    const result = await Message.updateMany(
      {
        conversation: conversation._id,
        sender: { $ne: request.user._id },
        readBy: { $ne: request.user._id },
      },
      {
        $addToSet: { readBy: request.user._id },
      }
    );

    const unreadCount = await Message.countDocuments({
      conversation: conversation._id,
      sender: { $ne: request.user._id },
      readBy: { $ne: request.user._id },
    });

    response.json({
      ok: true,
      updatedCount: result.modifiedCount || 0,
      unreadCount,
    });
  } catch (error) {
    next(error);
  }
});

'''

if "read-v2" not in backend:
    marker = "router.get('/me/following'"
    if marker in backend:
        backend = backend.replace(marker, route + "\n" + marker, 1)
    else:
        backend += "\n" + route

BACKEND.write_text(backend)

# ===== 2. 前端 ApiClient：markConversationRead 走 read-v2 =====
api = API.read_text()
bak = API.with_suffix(".dart.bak_fix_conversation_unread_read_v2")
if not bak.exists():
    bak.write_text(api)

if "Future<void> markConversationRead" not in api:
    marker = "  Future<CampusChatMessage> sendConversationMessage({"
    method = r'''  Future<void> markConversationRead({
    required String token,
    required String conversationId,
  }) async {
    await _postJson(
      '/api/conversations/$conversationId/read-v2',
      {},
      token: token,
    );
  }

'''
    if marker not in api:
        raise SystemExit("❌ ApiClient 没找到 sendConversationMessage 插入位置")
    api = api.replace(marker, method + marker, 1)
else:
    api = api.replace(
        "/api/conversations/$conversationId/read'",
        "/api/conversations/$conversationId/read-v2'",
    )
    api = api.replace(
        "/api/conversations/$conversationId/read\"",
        "/api/conversations/$conversationId/read-v2\"",
    )

API.write_text(api)

# ===== 3. Repository：没有 markConversationRead 就补上 =====
repo = REPO.read_text()
bak = REPO.with_suffix(".dart.bak_fix_conversation_unread_read_v2")
if not bak.exists():
    bak.write_text(repo)

if "Future<void> markConversationRead" not in repo:
    marker = "  Future<CampusChatMessage> sendConversationMessage({"
    method = r'''  Future<void> markConversationRead(String conversationId) async {
    if (conversationId.isEmpty) return;
    await _apiClient.markConversationRead(
      token: _requireToken(),
      conversationId: conversationId,
    );
    _emitSync(CampusEventType.notificationChanged, refId: conversationId);
  }

'''
    if marker not in repo:
        raise SystemExit("❌ Repository 没找到 sendConversationMessage 插入位置")
    repo = repo.replace(marker, method + marker, 1)

REPO.write_text(repo)

# ===== 4. ChatScreen：进入聊天页后 await 标记已读，然后刷新本地消息 =====
main = MAIN.read_text()
bak = MAIN.with_suffix(".dart.bak_fix_conversation_unread_read_v2")
if not bak.exists():
    bak.write_text(main)

pattern = r"  Future<void> _loadMessages\(\) async \{[\s\S]*?\n  \}\n\n  Future<void> _sendMessage\(\) async \{"
replacement = r'''  Future<void> _loadMessages() async {
    if (_conversationId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final repo = CampusRepository.instance;
      final messages = await repo.fetchConversationMessages(_conversationId);

      // 打开会话即视为已读。这里必须 await，不能 ignore，
      // 否则返回消息中心时 unreadCount 可能还没被后端清掉。
      await repo.markConversationRead(_conversationId);

      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {'''

if not re.search(pattern, main):
    raise SystemExit("❌ 没匹配到 ChatScreen _loadMessages，请发 2210-2235 行")
main = re.sub(pattern, replacement, main, count=1)

# ===== 5. 进入私信会话返回后，强制刷新私信列表 =====
main = main.replace(
    "await onReturn?.call();",
    "await onReturn?.call();",
)

MAIN.write_text(main)

print("✅ 已修复私信已读同步：后端 read-v2 + 前端 await 标记已读")
