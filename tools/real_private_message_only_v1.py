from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_real_private_message_only_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 私信列表：删除 remote 为空时回退演示数据
old_private_list = """class _PrivateMessageList extends StatelessWidget {
  const _PrivateMessageList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusConversation>>(
      future: CampusRepository.instance.fetchConversations(),
      builder: (context, snapshot) {
        final remoteEntries = (snapshot.data ?? const <CampusConversation>[])
            .map(_PrivateChatEntry.fromConversation)
            .toList(growable: false);
        final entries = remoteEntries.isEmpty
            ? _privateChatEntries
            : remoteEntries;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _PrivateMessageCard(entry: entries[index]),
          separatorBuilder: (_, _) => const SizedBox(height: 0),
        );
      },
    );
  }
}
"""

new_private_list = """class _PrivateMessageList extends StatelessWidget {
  const _PrivateMessageList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusConversation>>(
      future: CampusRepository.instance.fetchConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _EmptyStateCard(
            icon: Icons.error_outline_rounded,
            title: '私信加载失败',
            subtitle: _shellError(snapshot.error!),
          );
        }

        final entries = (snapshot.data ?? const <CampusConversation>[])
            .map(_PrivateChatEntry.fromConversation)
            .toList(growable: false);

        if (entries.isEmpty) {
          return const _EmptyStateCard(
            icon: Icons.mark_chat_unread_outlined,
            title: '暂无真实私信',
            subtitle: '从用户主页点击发消息，或收到别人消息后，会显示在这里',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _PrivateMessageCard(entry: entries[index]),
          separatorBuilder: (_, _) => const SizedBox(height: 0),
        );
      },
    );
  }
}
"""

if old_private_list not in text:
    raise SystemExit("❌ 没找到 _PrivateMessageList 原代码，请重新发 1903-1928 行")
text = text.replace(old_private_list, new_private_list, 1)

# 2. 私信列表时间格式友好化
text = text.replace(
    "time: conversation.updatedAt,",
    "time: _friendlyTime(conversation.updatedAt),",
    1,
)

# 3. 聊天页：删除 conversationId 为空时的固定摄影活动演示聊天
old_message_widgets = """    final messageWidgets = _conversationId.isNotEmpty
        ? _messages
              .map(
                (message) => message.isMine
                    ? _OutgoingChatBubble(text: message.text, sent: true)
                    : _IncomingChatBubble(
                        user: widget.contact,
                        text: message.text,
                      ),
              )
              .toList(growable: false)
        : <Widget>[
            _IncomingChatBubble(
              user: widget.contact,
              text: '嘿，周末的摄影社团采风活动你参加吗？\\n我们准备去湖边拍日出和校园风景～',
            ),
            const _OutgoingChatBubble(text: '参加的！想拍湖边的日出，超级期待！'),
            _IncomingChatBubble(
              user: widget.contact,
              text: '太棒了！我们计划周六早上6:30集合，\\n6:40出发，你看时间OK吗？',
            ),
            const _OutgoingChatBubble(text: '可以的，6:30没问题！集合地点在哪呀？'),
            _IncomingChatBubble(
              user: widget.contact,
              text: '在图书馆前的小广场集合，那里比较方便\\n大家汇合。',
            ),
            const _OutgoingChatBubble(text: '好的好的～那需要带相机和脚架吗？'),
            _IncomingChatBubble(
              user: widget.contact,
              text: '建议带上相机和脚架哦，日出光线比较低，\\n脚架会更稳；如果有ND滤镜也可以带上。',
            ),
            const _OutgoingChatBubble(text: '收到！那这天天气怎么样？会不会下雨呀？'),
            _WeatherChatBubble(user: widget.contact),
          ];
"""

new_message_widgets = """    final messageWidgets = _messages
        .map(
          (message) => message.isMine
              ? _OutgoingChatBubble(
                  user: message.sender,
                  text: message.text,
                  sent: true,
                )
              : _IncomingChatBubble(user: message.sender, text: message.text),
        )
        .toList(growable: false);
"""

if old_message_widgets not in text:
    raise SystemExit("❌ 没找到 ChatScreen 演示聊天代码，请重新发 2258-2295 行")
text = text.replace(old_message_widgets, new_message_widgets, 1)

# 4. 聊天消息为空时显示真实空状态，而不是空白/演示内容
old_chat_list_children = """                    children: [
                      const _ChatTimeLabel(label: '最近消息'),
                      ...messageWidgets,
                    ],
"""

new_chat_list_children = """                    children: [
                      const _ChatTimeLabel(label: '最近消息'),
                      if (messageWidgets.isEmpty)
                        const _ChatEmptyHint()
                      else
                        ...messageWidgets,
                    ],
"""

if old_chat_list_children not in text:
    raise SystemExit("❌ 没找到 ChatScreen ListView children 代码")
text = text.replace(old_chat_list_children, new_chat_list_children, 1)

# 5. 出站消息头像不能再固定用 kexin，要用真实 sender
old_outgoing_class = """class _OutgoingChatBubble extends StatelessWidget {
  const _OutgoingChatBubble({required this.text, this.sent = false});

  final String text;
  final bool sent;
"""

new_outgoing_class = """class _OutgoingChatBubble extends StatelessWidget {
  const _OutgoingChatBubble({
    required this.user,
    required this.text,
    this.sent = false,
  });

  final CampusUser user;
  final String text;
  final bool sent;
"""

if old_outgoing_class not in text:
    raise SystemExit("❌ 没找到 _OutgoingChatBubble 类头")
text = text.replace(old_outgoing_class, new_outgoing_class, 1)

text = text.replace(
    "              const CampusAvatar(user: kexin, size: 40),",
    "              CampusAvatar(user: user, size: 40),",
    1,
)

# 6. 插入聊天空状态组件
insert_after = """class _ChatTimeLabel extends StatelessWidget {
  const _ChatTimeLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 18),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ),
    );
  }
}
"""

chat_empty = """
class _ChatEmptyHint extends StatelessWidget {
  const _ChatEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Center(
        child: Column(
          children: const [
            Icon(
              Icons.forum_outlined,
              color: AppColors.muted,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              '暂无真实聊天记录',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '发送第一条消息后，会显示在这里',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
"""

if "_ChatEmptyHint" not in text:
    text = text.replace(insert_after, insert_after + chat_empty, 1)

MAIN.write_text(text)
print("✅ 私信前端已改为只显示真实 conversations/messages，删除演示私信和演示聊天")
