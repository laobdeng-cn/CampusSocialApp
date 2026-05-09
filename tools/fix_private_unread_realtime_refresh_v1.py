from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
REPO = Path("frontend/frontend/lib/repositories/campus_repository.dart")

main = MAIN.read_text()
repo = REPO.read_text()

bak_main = MAIN.with_suffix(".dart.bak_fix_private_unread_realtime_refresh_v1")
bak_repo = REPO.with_suffix(".dart.bak_fix_private_unread_realtime_refresh_v1")
if not bak_main.exists():
    bak_main.write_text(main)
if not bak_repo.exists():
    bak_repo.write_text(repo)

# 1. 确保 Repository 标记已读后会广播 notificationChanged
repo = re.sub(
    r"Future<void> markConversationRead\(String conversationId\) async \{[\s\S]*?\n  \}\n\n  Future<CampusChatMessage> sendConversationMessage",
    r'''Future<void> markConversationRead(String conversationId) async {
    if (conversationId.isEmpty) return;
    await _apiClient.markConversationRead(
      token: _requireToken(),
      conversationId: conversationId,
    );
    _emitSync(CampusEventType.notificationChanged, refId: conversationId);
  }

  Future<CampusChatMessage> sendConversationMessage''',
    repo,
    count=1,
)

REPO.write_text(repo)

# 2. 重写 _PrivateMessageList：监听 notificationChanged，自动刷新私信列表
pattern = r"class _PrivateMessageList extends StatefulWidget \{[\s\S]*?\n\}\n\nclass _PrivateEmptyStateCard"
replacement = r'''class _PrivateMessageList extends StatefulWidget {
  const _PrivateMessageList();

  @override
  State<_PrivateMessageList> createState() => _PrivateMessageListState();
}

class _PrivateMessageListState extends State<_PrivateMessageList> {
  late Future<List<CampusConversation>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchConversations();

    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.notificationChanged ||
          event.type == CampusEventType.profileChanged) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = CampusRepository.instance.fetchConversations();
    if (mounted) {
      setState(() => _future = next);
    }
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusConversation>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _PrivateEmptyStateCard(
            icon: Icons.error_outline_rounded,
            title: '私信加载失败',
            subtitle: _shellError(snapshot.error!),
          );
        }

        final entries = (snapshot.data ?? const <CampusConversation>[])
            .map(_PrivateChatEntry.fromConversation)
            .toList(growable: false);

        if (entries.isEmpty) {
          return const _PrivateEmptyStateCard(
            icon: Icons.mark_chat_unread_outlined,
            title: '暂无真实私信',
            subtitle: '从用户主页点击发消息，或收到别人消息后，会显示在这里',
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
            itemCount: entries.length,
            itemBuilder: (context, index) =>
                _PrivateMessageCard(entry: entries[index], onReturn: _refresh),
            separatorBuilder: (_, _) => const SizedBox(height: 0),
          ),
        );
      },
    );
  }
}

class _PrivateEmptyStateCard'''

if not re.search(pattern, main):
    raise SystemExit("❌ 没匹配到 _PrivateMessageList，请发 main_shell.dart 1900-1955 行")
main = re.sub(pattern, replacement, main, count=1)

# 3. 确保 _PrivateMessageCard 支持返回后刷新
main = main.replace(
    "const _PrivateMessageCard({required this.entry});\n\n  final _PrivateChatEntry entry;",
    "const _PrivateMessageCard({required this.entry, this.onReturn});\n\n  final _PrivateChatEntry entry;\n  final Future<void> Function()? onReturn;",
    1,
)

old_tap = """onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                contact: entry.user,
                conversationId: entry.conversationId,
                displayName: entry.name ?? entry.user.name,
                online: entry.online,
              ),
            ),
          );
        },"""

new_tap = """onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                contact: entry.user,
                conversationId: entry.conversationId,
                displayName: entry.name ?? entry.user.name,
                online: entry.online,
              ),
            ),
          );
          await onReturn?.call();
        },"""

if old_tap in main:
    main = main.replace(old_tap, new_tap, 1)

# 4. 确保 ChatScreen 打开后 await 标记已读
main = re.sub(
    r"Future<void> _loadMessages\(\) async \{[\s\S]*?\n  \}\n\n  Future<void> _sendMessage\(\) async \{",
    r'''Future<void> _loadMessages() async {
    if (_conversationId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final repo = CampusRepository.instance;
      final messages = await repo.fetchConversationMessages(_conversationId);
      await repo.markConversationRead(_conversationId);

      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {''',
    main,
    count=1,
)

MAIN.write_text(main)

print("✅ 已修复：进入聊天页标记已读后，消息中心私信列表自动刷新，不再需要热重载")
