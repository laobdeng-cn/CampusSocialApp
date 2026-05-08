from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

# 1. 确保首页时间格式化函数存在
shell_error = """String _shellError(Object error) {
  final text = error.toString();
  const marker = 'CampusApiException: ';
  if (text.startsWith(marker)) return text.substring(marker.length);
  return '操作失败，请确认后端服务已启动';
}
"""

helper = r"""
String _shellFriendlyTime(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '刚刚';

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final time = parsed.toLocal();
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 &&
      now.year == time.year &&
      now.month == time.month &&
      now.day == time.day) {
    return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 7) return '${diff.inDays}天前';

  return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

"""

if "_shellFriendlyTime" not in text:
    if shell_error not in text:
        raise SystemExit("❌ 没找到 _shellError，先别继续，把 main_shell 顶部 1-70 发我")
    text = text.replace(shell_error, shell_error + helper, 1)
    print("✅ 已补充 _shellFriendlyTime")

# 2. 整段替换 PostFeedCard，修复之前被脚本破坏的类结构
start = text.find("class PostFeedCard extends StatefulWidget")
end = text.find("class DiscussionCard extends StatelessWidget")

if start == -1:
    raise SystemExit("❌ 没找到 PostFeedCard 类")
if end == -1:
    raise SystemExit("❌ 没找到 DiscussionCard 类，无法确定替换结束位置")

new_block = r'''class PostFeedCard extends StatefulWidget {
  const PostFeedCard({required this.post, super.key});

  final CampusPost post;

  @override
  State<PostFeedCard> createState() => _PostFeedCardState();
}

class _PostFeedCardState extends State<PostFeedCard> {
  late CampusPost _post = widget.post;
  late bool _liked = widget.post.likes > 0;
  late bool _favorited = widget.post.saves > 0;
  var _isLiking = false;
  var _isFavoriting = false;

  @override
  void didUpdateWidget(covariant PostFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likes != widget.post.likes ||
        oldWidget.post.saves != widget.post.saves ||
        oldWidget.post.comments != widget.post.comments) {
      _post = widget.post;
      _liked = widget.post.likes > 0;
      _favorited = widget.post.saves > 0;
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final previousPost = _post;
    final previousLiked = _liked;

    setState(() {
      _isLiking = true;
      _liked = !_liked;
      final nextLikes = _post.likes + (_liked ? 1 : -1);
      _post = _post.copyWith(likes: nextLikes < 0 ? 0 : nextLikes);
    });

    try {
      final post = await CampusRepository.instance.togglePostLike(previousPost);
      if (!mounted) return;
      setState(() {
        _post = post;
        _liked = post.likes > previousPost.likes || post.likes > 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _post = previousPost;
        _liked = previousLiked;
      });
      _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriting) return;

    final previousPost = _post;
    final previousFavorited = _favorited;

    setState(() {
      _isFavoriting = true;
      _favorited = !_favorited;
      final nextSaves = _post.saves + (_favorited ? 1 : -1);
      _post = _post.copyWith(saves: nextSaves < 0 ? 0 : nextSaves);
    });

    try {
      final post = await CampusRepository.instance.togglePostFavorite(
        previousPost,
      );
      if (!mounted) return;
      setState(() {
        _post = post;
        _favorited = post.saves > previousPost.saves || post.saves > 0;
      });
      _showShellMessage(context, _favorited ? '已收藏' : '已取消收藏');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _post = previousPost;
        _favorited = previousFavorited;
      });
      _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isFavoriting = false);
    }
  }

  Future<void> _openDetail() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: _post)),
    );

    if (changed == true && mounted) {
      setState(() {
        _post = _post.copyWith(
          likes: _post.likes,
          comments: _post.comments,
          saves: _post.saves,
        );
        _liked = _post.likes > 0;
        _favorited = _post.saves > 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;

    return CampusCard(
      onTap: _openDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(user: post.author),
                    ),
                  );
                },
                child: CampusAvatar(user: post.author, size: 44),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${post.author.name} · ${post.topic}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _shellFriendlyTime(post.createdAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (post.images.length >= 3)
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(child: SmartImage(url: post.images[i], height: 92)),
                    if (i != 2) const SizedBox(width: 8),
                  ],
                ],
              )
            else
              SmartImage(
                url: post.images.first,
                height: 142,
                width: double.infinity,
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _InlineInteractionButton(
                icon: _isLiking
                    ? Icons.hourglass_top_rounded
                    : (_liked ? Icons.favorite : Icons.favorite_border_rounded),
                label: '${post.likes}',
                color: _liked ? AppColors.red : AppColors.text,
                isLoading: _isLiking,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 12),
              _InlineInteractionButton(
                icon: Icons.mode_comment_outlined,
                label: '${post.comments}',
                onTap: _openDetail,
              ),
              const SizedBox(width: 12),
              _InlineInteractionButton(
                icon: _isFavoriting
                    ? Icons.hourglass_top_rounded
                    : (_favorited ? Icons.star_rounded : Icons.star_border_rounded),
                label: '${post.saves}',
                color: _favorited ? AppColors.orange : AppColors.text,
                isLoading: _isFavoriting,
                onTap: _toggleFavorite,
              ),
              const Spacer(),
              const Icon(Icons.ios_share_rounded, size: 21),
            ],
          ),
        ],
      ),
    );
  }
}

'''

text = text[:start] + new_block + text[end:]

MAIN.write_text(text)
print("✅ 已重建 PostFeedCard，修复类结构、首页时间、爱心收藏状态")
