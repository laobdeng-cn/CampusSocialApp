from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_private_unread_refresh_exact_v2")
if not bak.exists():
    bak.write_text(text)

# 0. 确保有 dart:async，给 StreamSubscription 用
if "import 'dart:async';" not in text:
    text = "import 'dart:async';\n" + text

# 1. 替换 _PrivateMessageList：Stateless -> Stateful，并监听已读事件自动刷新
start = text.find("class _PrivateMessageList extends StatelessWidget {")
end = text.find("const _privateChatEntries = [", start)

if start == -1 or end == -1:
    raise SystemExit("❌ 没找到 _PrivateMessageList 或 _privateChatEntries，请重新发 1900-1995 行")

new_private_list = r'''class _PrivateMessageList extends StatefulWidget {
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
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.profileChanged) {
        _refresh().ignore();
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

    try {
      await next;
    } catch (_) {
      // 错误交给 FutureBuilder 展示，避免后台刷新抛未处理异常。
    }
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
            itemBuilder: (context, index) => _PrivateMessageCard(
              entry: entries[index],
              onReturn: _refresh,
            ),
            separatorBuilder: (_, _) => const SizedBox(height: 0),
          ),
        );
      },
    );
  }
}

'''

text = text[:start] + new_private_list + text[end:]

# 2. 删除残留的私信演示数据 _privateChatEntries
start = text.find("const _privateChatEntries = [")
end = text.find("class _PrivateEmptyStateCard extends StatelessWidget", start)

if start != -1 and end != -1:
    text = text[:start] + text[end:]

# 3. 修改 _PrivateMessageCard：增加 onReturn
old_ctor = """class _PrivateMessageCard extends StatelessWidget {
  const _PrivateMessageCard({required this.entry});

  final _PrivateChatEntry entry;
"""

new_ctor = """class _PrivateMessageCard extends StatelessWidget {
  const _PrivateMessageCard({required this.entry, this.onReturn});

  final _PrivateChatEntry entry;
  final Future<void> Function()? onReturn;
"""

if old_ctor not in text:
    raise SystemExit("❌ 没找到 _PrivateMessageCard 构造函数，请发 2070-2090 行")
text = text.replace(old_ctor, new_ctor, 1)

# 4. 修改点击进入聊天：await Navigator.push，回来后刷新列表
old_tap = """        onTap: () {
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

new_tap = """        onTap: () async {
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

if old_tap not in text:
    raise SystemExit("❌ 没找到 _PrivateMessageCard onTap，请发 2080-2100 行")
text = text.replace(old_tap, new_tap, 1)

MAIN.write_text(text)

print("✅ 已修复：消息中心私信列表会监听已读事件并自动刷新，且返回聊天列表时强制刷新")
