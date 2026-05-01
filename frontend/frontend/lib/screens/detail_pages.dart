import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../models/campus_feed.dart';
import '../models/campus_models.dart';
import '../repositories/auth_session.dart';
import '../repositories/campus_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/campus_widgets.dart';

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _friendlyError(Object error) {
  final text = error.toString();
  const marker = 'CampusApiException: ';
  if (text.startsWith(marker)) return text.substring(marker.length);
  return '操作失败，请确认后端服务已启动';
}

class PublishPostScreen extends StatefulWidget {
  const PublishPostScreen({super.key});

  @override
  State<PublishPostScreen> createState() => _PublishPostScreenState();
}

class _PublishPostScreenState extends State<PublishPostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _topicController = TextEditingController(text: '校园生活');
  final _locationController = TextEditingController(text: '图书馆广场');
  var _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _topicController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showMessage(context, '请填写标题和动态内容');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await CampusRepository.instance.createPost(
        title: title,
        body: body,
        topic: _topicController.text.trim().isEmpty
            ? '校园生活'
            : _topicController.text.trim(),
        location: _locationController.text.trim(),
        images: const ['asset:assets/images/profile_sunset.png'],
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveDraft() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty) {
      _showMessage(context, '先写一点内容再保存草稿');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await CampusRepository.instance.saveDraft(
        title: title.isEmpty ? '未命名草稿' : title,
        body: body,
        topic: _topicController.text.trim().isEmpty
            ? '校园生活'
            : _topicController.text.trim(),
        location: _locationController.text.trim(),
        images: const ['asset:assets/images/profile_sunset.png'],
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 82,
        leading: TextButton(
          onPressed: _isSubmitting ? null : _saveDraft,
          child: const Text('草稿'),
        ),
        title: const Text('发布动态'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(_isSubmitting ? '发布中...' : '发布'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: '给动态起个标题',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bodyController,
            minLines: 6,
            maxLines: 8,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '分享你的校园新鲜事...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              counterText: '0/500',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == 4) {
                  return Container(
                    width: 90,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.muted.withValues(alpha: 0.35),
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 32, color: AppColors.muted),
                        SizedBox(height: 4),
                        Text('添加照片/视频', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }
                return Stack(
                  children: [
                    SmartImage(
                      url: sunsetPost.images[index % sunsetPost.images.length],
                      width: 90,
                      height: 90,
                    ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _topicController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.blue),
              hintText: '添加话题',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PublishRow(
            icon: Icons.location_on,
            color: AppColors.green,
            title: '所在位置',
            value: _locationController.text,
          ),
          const SizedBox(height: 12),
          _PublishRow(
            icon: Icons.visibility,
            color: AppColors.blue,
            title: '谁可以看',
            value: '公开 · 所有人可见',
          ),
          const SizedBox(height: 12),
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('更多选项', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const _PublishOption(
                  icon: Icons.alternate_email,
                  color: AppColors.blue,
                  title: '@ 好友',
                  subtitle: '提醒好友来看你的动态',
                ),
                const _PublishOption(
                  icon: Icons.tag,
                  color: AppColors.purple,
                  title: '添加话题',
                  subtitle: '选择更多话题，获得更多曝光',
                ),
                const _PublishOption(
                  icon: Icons.groups_rounded,
                  color: AppColors.green,
                  title: '同步到社团',
                  subtitle: '将动态同步到我的社团动态',
                  trailing: Switch(value: false, onChanged: null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openResults(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(initialQuery: normalizedQuery),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('搜索')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _openResults,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 22),
                    suffixIcon: IconButton(
                      onPressed: () {
                        _controller.clear();
                      },
                      icon: const Icon(Icons.cancel, size: 18),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF0F4FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
          const SectionTitle(
            title: '最近搜索',
            padding: EdgeInsets.fromLTRB(0, 24, 0, 12),
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, size: 17, color: AppColors.muted),
                SizedBox(width: 4),
                Text('清空', style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final item in recentSearches)
                Pill(
                  label: item,
                  color: AppColors.muted,
                  onTap: () {
                    _controller.text = item;
                    _openResults(item);
                  },
                ),
            ],
          ),
          const SectionTitle(
            title: '热门搜索',
            icon: Icons.local_fire_department,
            padding: EdgeInsets.fromLTRB(0, 24, 0, 12),
            action: Text(
              '换一换',
              style: TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 5.8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < recentSearches.length + 1; i++)
                InkWell(
                  onTap: () {
                    final keyword = [
                      '摄影社团招新',
                      '篮球联赛',
                      '志愿者活动',
                      '考研经验分享',
                      '校园音乐节',
                      'AI 未来发展',
                    ][i];
                    _controller.text = keyword;
                    _openResults(keyword);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: [
                            AppColors.red,
                            AppColors.orange,
                            AppColors.blue,
                            AppColors.green,
                            AppColors.purple,
                            AppColors.blueDark,
                          ][i],
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          [
                            '摄影社团招新',
                            '篮球联赛',
                            '志愿者活动',
                            '考研经验分享',
                            '校园音乐节',
                            'AI 未来发展',
                          ][i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({required this.initialQuery, super.key});

  final String initialQuery;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _controller;
  CampusSearchResult _result = CampusSearchResult.empty();
  bool _isLoading = true;
  int _selectedTab = 0;

  static const _tabs = ['综合', '用户', '活动', '帖子', '话题'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _runSearch(widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;

    setState(() => _isLoading = true);
    final result = await CampusRepository.instance.search(normalizedQuery);
    if (!mounted) return;
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  int get _resultCount =>
      _result.users.length +
      _result.activities.length +
      _result.posts.length +
      _result.topics.length;

  @override
  Widget build(BuildContext context) {
    final content = switch (_selectedTab) {
      1 => [_UsersResultSection(users: _result.users, showHeader: false)],
      2 => [
        _ActivitiesResultSection(
          activities: _result.activities,
          showHeader: false,
        ),
      ],
      3 => [_PostsResultSection(posts: _result.posts, showHeader: false)],
      4 => [_TopicsResultSection(topics: _result.topics, showHeader: false)],
      _ => [
        _ResultCountLine(count: _resultCount),
        const SizedBox(height: 18),
        _UsersResultSection(users: _result.users),
        _ActivitiesResultSection(activities: _result.activities),
        _PostsResultSection(posts: _result.posts),
        _TopicsResultSection(topics: _result.topics),
      ],
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _runSearch,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 22),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _result = CampusSearchResult.empty();
                            });
                          },
                          icon: const Icon(Icons.cancel, size: 18),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _SearchResultTab(
                        label: _tabs[i],
                        selected: _selectedTab == i,
                        onTap: () => setState(() => _selectedTab = i),
                      ),
                    ),
                ],
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: _isLoading
                    ? const [
                        SizedBox(height: 180),
                        Center(child: CircularProgressIndicator()),
                      ]
                    : content,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomTabs(
        currentIndex: 3,
        onTap: (index) => navigateToTab(context, index),
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({required this.post, super.key});

  final CampusPost post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late CampusPost _post;
  final _commentController = TextEditingController();
  List<CampusComment> _comments = const [];
  var _isLoadingComments = false;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    Future<void>(() {
      return CampusRepository.instance.recordHistory(
        kind: 'post',
        refId: _post.id,
        title: _post.title,
        subtitle:
            '${_post.author.name} · ${_post.likes}赞 · ${_post.comments}评论',
        imageUrl: _post.images.isEmpty ? '' : _post.images.first,
      );
    }).catchError((_) {});
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (_post.id.isEmpty) return;
    setState(() => _isLoadingComments = true);
    try {
      final comments = await CampusRepository.instance.fetchComments(_post);
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (_) {
      // Static fallback comments remain below if the backend is unavailable.
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      final post = await CampusRepository.instance.togglePostLike(_post);
      if (mounted) setState(() => _post = post);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final post = await CampusRepository.instance.togglePostFavorite(_post);
      if (mounted) setState(() => _post = post);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      _showMessage(context, '请输入评论内容');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await CampusRepository.instance.createComment(
        post: _post,
        text: text,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _post = result.post;
        _comments = [result.comment, ..._comments];
      });
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('帖子详情'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 92),
        children: [
          Row(
            children: [
              CampusAvatar(user: post.author, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.author.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        Pill(label: post.author.school, color: AppColors.blue),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${post.createdAt} · 来自 社区',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('关注'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(post.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Pill(label: '# ${post.topic}', color: AppColors.blue),
          ),
          const SizedBox(height: 16),
          Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text(
            '想知道：\n1. 通过哪个入口预约？是否需要学校账号登录？\n2. 每天几点可以预约？能预约多久的时段？\n3. 选座有没有什么小技巧？热门区域容易抢吗？',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < post.images.take(3).length; i++) ...[
                Expanded(child: SmartImage(url: post.images[i], height: 116)),
                if (i != 2) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Pill(
              label: post.location,
              icon: Icons.location_on,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionStat(
                icon: Icons.favorite,
                value: post.likes,
                color: AppColors.red,
                onTap: _toggleLike,
              ),
              _ActionStat(
                icon: Icons.mode_comment_outlined,
                value: post.comments,
              ),
              _ActionStat(
                icon: Icons.star_border_rounded,
                value: post.saves,
                onTap: _toggleFavorite,
              ),
              _ActionStat(icon: Icons.ios_share_rounded, value: post.shares),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                '全部评论 (${post.comments})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              const Text('最热', style: TextStyle(color: AppColors.muted)),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingComments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_comments.isNotEmpty)
            for (final comment in _comments)
              _CommentTile(
                user: comment.author,
                text: comment.text,
                likes: comment.likes,
              )
          else ...[
            const _CommentTile(
              user: kexin,
              text: '我上周刚预约过！入口在“今日校园”APP 服务 图书馆 座位预约，用学校账号登录就行。',
              likes: 28,
              reply: '谢谢学姐！入口找到了，超方便！',
            ),
            const _CommentTile(
              user: zihao,
              text: '每天早上 8:00 可以预约，能预约当天和第二天的座位，每次最多 4 小时。',
              likes: 19,
            ),
            const _CommentTile(
              user: siyu,
              text: '推荐 3 楼和 5 楼的自习区，安静又宽敞。记得带充电宝，插座很紧张。',
              likes: 15,
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _isSubmitting ? null : _submitComment(),
                  decoration: InputDecoration(
                    hintText: '写评论...',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _isSubmitting ? null : _submitComment,
                icon: Icon(
                  _isSubmitting
                      ? Icons.hourglass_top_rounded
                      : Icons.send_rounded,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({required this.activity, super.key});

  final CampusActivity activity;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late CampusActivity _activity = widget.activity;
  var _isRegistered = false;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() {
      return CampusRepository.instance.recordHistory(
        kind: 'activity',
        refId: _activity.id,
        title: _activity.title,
        subtitle: '${_activity.host} · ${_activity.enrolled}人参加',
        imageUrl: _activity.posterUrl,
      );
    }).catchError((_) {});
  }

  Future<void> _toggleRegistration() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final nextActivity = _isRegistered
          ? await CampusRepository.instance.cancelActivityJoin(_activity)
          : await CampusRepository.instance.joinActivity(_activity);

      if (!mounted) return;
      setState(() {
        _activity = nextActivity;
        _isRegistered = !_isRegistered;
      });

      if (_isRegistered) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationSuccessScreen(activity: nextActivity),
          ),
        );
      } else {
        _showMessage(context, '已取消报名');
      }
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('活动详情'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: [
          SmartImage(url: activity.posterUrl, height: 180, borderRadius: 18),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  activity.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.star_border_rounded),
                label: const Text('收藏'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(label: activity.category, color: AppColors.blue),
              const Pill(label: '音乐', color: AppColors.purple),
              const Pill(label: '校园文化', color: AppColors.green),
            ],
          ),
          const SizedBox(height: 16),
          CampusCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  title: activity.date,
                  subtitle: activity.time,
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  title: activity.location,
                  subtitle: '导航',
                  actionColor: AppColors.blue,
                ),
                _InfoRow(
                  icon: Icons.groups_outlined,
                  title: '${activity.enrolled}人已报名 · 限额${activity.capacity}人',
                  subtitle: '',
                  trailing: AvatarStack(users: activity.guests, size: 28),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CampusCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Color(0xFFEAF2FF),
                  child: Icon(Icons.school, color: AppColors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              activity.host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Pill(label: '官方', color: AppColors.blue),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '组织者 · 学生组织 · 4.8分',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(onPressed: () {}, child: const Text('关注')),
              ],
            ),
          ),
          const SectionTitle(
            title: '活动介绍',
            padding: EdgeInsets.fromLTRB(0, 24, 0, 10),
          ),
          Text(
            activity.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {},
              label: const Text('展开'),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ),
          const SectionTitle(
            title: '活动亮点',
            padding: EdgeInsets.fromLTRB(0, 4, 0, 12),
          ),
          Row(
            children: [
              for (final item in activity.highlights) ...[
                Expanded(
                  child: CampusCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const IconBubble(icon: Icons.auto_awesome, size: 42),
                        const SizedBox(height: 8),
                        Text(
                          item,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                if (item != activity.highlights.last) const SizedBox(width: 10),
              ],
            ],
          ),
          const SectionTitle(
            title: '嘉宾阵容',
            padding: EdgeInsets.fromLTRB(0, 24, 0, 12),
            action: Text('查看更多', style: TextStyle(color: AppColors.muted)),
          ),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: activity.guests.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final user = activity.guests[index];
                return SizedBox(
                  width: 120,
                  child: CampusCard(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CampusAvatar(user: user, size: 48),
                        const Spacer(),
                        Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          user.role ?? user.bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.price,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: AppColors.green),
                    ),
                    const Text(
                      '名额有限，先到先得',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: PrimaryButton(
                  label: _isSubmitting
                      ? '处理中...'
                      : _isRegistered
                      ? '取消报名'
                      : '立即报名',
                  color: _isRegistered ? AppColors.red : AppColors.green,
                  onPressed: _toggleRegistration,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({required this.activity, super.key});

  final CampusActivity activity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('报名成功')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.green,
            size: 64,
          ),
          const SizedBox(height: 8),
          Text(
            '报名成功',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 6),
          const Text(
            '期待在活动现场与你相见！',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 24),
          CampusCard(
            child: Row(
              children: [
                SmartImage(url: activity.posterUrl, width: 112, height: 112),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _CompactMeta(
                        icon: Icons.schedule,
                        label: '${activity.date} ${activity.time}',
                      ),
                      _CompactMeta(
                        icon: Icons.location_on_outlined,
                        label: activity.location,
                      ),
                      _CompactMeta(
                        icon: Icons.groups_outlined,
                        label: '${activity.enrolled}人已报名',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '电子票（入场凭证）',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('签到说明'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      CustomPaint(
                        size: const Size(126, 126),
                        painter: _QrPainter(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '入场二维码',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.blue),
                            ),
                            const SizedBox(height: 8),
                            const Text('请在活动当天出示二维码签到入场'),
                            const Divider(height: 28),
                            const Text(
                              '签到码',
                              style: TextStyle(color: AppColors.blue),
                            ),
                            Text(
                              '8685 9921',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: AppColors.blue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _TicketInfoRow(
                  icon: Icons.event_seat,
                  title: '入场信息',
                  subtitle: '自由入座，先到先得',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const CampusCard(
            child: Column(
              children: [
                _TicketInfoRow(
                  icon: Icons.notifications_active_outlined,
                  title: '温馨提示',
                  subtitle: '请提前30分钟到达现场，请遵守现场秩序。如无法参加，请提前取消报名。',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const CampusCard(
            child: _TicketInfoRow(
              icon: Icons.calendar_month_outlined,
              title: '添加到日历',
              subtitle: '设置活动前提醒',
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: '查看我的活动',
            onPressed: () => navigateToTab(context, 4),
          ),
        ],
      ),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({required this.group, super.key});

  final CampusGroup group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late CampusGroup _group = widget.group;
  var _isLoading = false;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() {
      return CampusRepository.instance.recordHistory(
        kind: 'group',
        refId: _group.id,
        title: _group.name,
        subtitle: '成员 ${_group.members} · 帖子 ${_group.discussions.length}',
        imageUrl: _group.iconUrl,
      );
    }).catchError((_) {});
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (_group.id.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final group = await CampusRepository.instance.fetchGroupDetail(_group);
      if (mounted) setState(() => _group = group);
    } catch (_) {
      // The screen can still render the feed copy if detail loading fails.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleJoin() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final group = _group.joined
          ? await CampusRepository.instance.leaveGroup(_group)
          : await CampusRepository.instance.joinGroup(_group);
      if (!mounted) return;
      setState(() => _group = group);
      _showMessage(
        context,
        group.joined ? '已加入 ${group.name}' : '已退出 ${group.name}',
      );
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 330,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartImage(url: group.coverUrl, borderRadius: 0),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.62),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 28,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SmartImage(
                            url: group.iconUrl,
                            width: 78,
                            height: 78,
                            borderRadius: 18,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        group.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 25,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Pill(
                                      label: '公开',
                                      color: AppColors.blue,
                                      selected: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${group.members}人 · ${group.admins}位管理员',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in group.tags) Pill(label: tag),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading) ...[
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 12),
                        ],
                        CampusCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CampusAvatar(
                              user: xiaobei,
                              size: 50,
                              showBadge: true,
                            ),
                            title: const Text('林小北'),
                            subtitle: const Text('计算机学院 · 大二\n热爱技术，乐于分享'),
                            trailing: const Pill(
                              label: '群主',
                              color: AppColors.blue,
                            ),
                            isThreeLine: true,
                          ),
                        ),
                        const SectionTitle(
                          title: '即将开展的活动',
                          padding: EdgeInsets.fromLTRB(0, 22, 0, 12),
                          action: Text(
                            '全部',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                        CampusCard(
                          child: Column(
                            children:
                                (group.activities.isEmpty
                                        ? [campusActivity]
                                        : group.activities)
                                    .map(
                                      (activity) => _GroupActivityTile(
                                        activity: activity,
                                      ),
                                    )
                                    .toList(growable: false),
                          ),
                        ),
                        const SectionTitle(
                          title: '热门讨论',
                          padding: EdgeInsets.fromLTRB(0, 22, 0, 12),
                          action: Text(
                            '全部',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                        CampusCard(
                          child: Column(
                            children: [
                              for (final post in group.discussions)
                                _SimpleDiscussionTile(post: post),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.ios_share),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: PrimaryButton(
            label: _isSubmitting
                ? '处理中...'
                : group.joined
                ? '退出社群'
                : '申请加入',
            color: group.joined ? AppColors.red : AppColors.blue,
            onPressed: _toggleJoin,
          ),
        ),
      ),
    );
  }
}

class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({required this.topic, super.key});

  final CampusTopic topic;

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  late CampusTopic _topic = widget.topic;

  @override
  void initState() {
    super.initState();
    Future<void>(() {
      return CampusRepository.instance.recordHistory(
        kind: 'topic',
        refId: _topic.id,
        title: _topic.name,
        subtitle: '${_topic.discussions}讨论 · ${_topic.onlineCount}在线',
        imageUrl: _topic.coverUrl,
      );
    }).catchError((_) {});
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (_topic.id.isEmpty) return;
    try {
      final topic = await CampusRepository.instance.fetchTopicDetail(_topic);
      if (mounted) setState(() => _topic = topic);
    } catch (_) {
      // Keep the feed copy visible if the detail request is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topic;

    return Scaffold(
      appBar: AppBar(
        title: const Text('话题详情'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4C8DFF), Color(0xFF7CB7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -28,
                  top: -18,
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 150,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '# ${topic.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${topic.discussions} 讨论',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          AvatarStack(users: topic.contributors, size: 30),
                          const SizedBox(width: 10),
                          Text(
                            '${topic.onlineCount}人在线',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(topic.description),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(
            title: '推荐讨论',
            padding: EdgeInsets.fromLTRB(0, 24, 0, 12),
            action: Text('最新', style: TextStyle(color: AppColors.muted)),
          ),
          for (final post in topic.posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CampusCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: post),
                    ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CampusAvatar(user: post.author, size: 36),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  post.author.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (post.isPinned)
                                const Pill(label: '置顶', color: AppColors.red),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            post.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            post.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _ActionStat(
                                icon: Icons.mode_comment_outlined,
                                value: post.comments,
                              ),
                              const SizedBox(width: 16),
                              _ActionStat(
                                icon: Icons.thumb_up_alt_outlined,
                                value: post.likes,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (post.images.isNotEmpty)
                      SmartImage(url: post.images.first, width: 96, height: 96),
                  ],
                ),
              ),
            ),
          const SectionTitle(
            title: '热门贡献者',
            padding: EdgeInsets.fromLTRB(0, 12, 0, 12),
            action: Text('查看全部', style: TextStyle(color: AppColors.muted)),
          ),
          SizedBox(
            height: 134,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topic.contributors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final user = topic.contributors[index];
                return SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      CampusAvatar(user: user, size: 56),
                      const SizedBox(height: 7),
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 28),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('关注'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SectionTitle(
            title: '相关子话题',
            padding: EdgeInsets.fromLTRB(0, 18, 0, 12),
            action: Text('更多', style: TextStyle(color: AppColors.muted)),
          ),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 3.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final item in topic.relatedTopics)
                CampusCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const IconBubble(icon: Icons.tag, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '# $item',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PublishPostScreen()),
          );
        },
        icon: const Icon(Icons.edit),
        label: const Text('参与讨论'),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late CampusUser _user;
  late final TextEditingController _nameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _majorController;
  late final TextEditingController _gradeController;
  late final TextEditingController _bioController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _user = AuthSession.user ?? xiaobei;
    _nameController = TextEditingController(text: _user.name);
    _schoolController = TextEditingController(text: _user.school);
    _majorController = TextEditingController(text: _user.major);
    _gradeController = TextEditingController(text: _user.grade);
    _bioController = TextEditingController(text: _user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _majorController.dispose();
    _gradeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final user = await CampusRepository.instance.updateProfile(
        name: _nameController.text.trim(),
        school: _schoolController.text.trim(),
        major: _majorController.text.trim(),
        grade: _gradeController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _user.avatarUrl,
      );
      if (!mounted) return;
      setState(() => _user = user);
      Navigator.pop(context, user);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? '保存中' : '保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('头像与昵称', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Stack(
                      children: [
                        CampusAvatar(user: _user, size: 86),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_camera, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _ProfileEditTextRow(
                            label: '昵称',
                            controller: _nameController,
                          ),
                          const Divider(),
                          _ProfileEditRow(
                            label: '用户名',
                            value: _user.id.isEmpty ? '未登录' : _user.id,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CampusCard(
            child: Column(
              children: [
                _ProfileEditRow(
                  label: '身份',
                  value: _user.role?.isNotEmpty == true ? _user.role! : '学生',
                  icon: Icons.school_outlined,
                ),
                const Divider(),
                _ProfileEditTextRow(label: '学校', controller: _schoolController),
                const Divider(),
                _ProfileEditTextRow(label: '专业', controller: _majorController),
                const Divider(),
                _ProfileEditTextRow(label: '年级', controller: _gradeController),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('个人简介', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  minLines: 3,
                  maxLines: 3,
                  maxLength: 100,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('兴趣标签', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: const [
                    Pill(label: '摄影'),
                    Pill(label: '篮球'),
                    Pill(label: '音乐'),
                    Pill(label: '旅行'),
                    Pill(label: '编程'),
                    Pill(label: '+ 添加标签', color: AppColors.muted),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CampusCard(
            child: Column(
              children: [
                _ProfileEditRow(
                  label: '微信',
                  value: 'xiaobei_2024',
                  icon: Icons.chat_bubble_outline,
                ),
                Divider(),
                _ProfileEditRow(label: '微博', value: '林小北_', icon: Icons.public),
                Divider(),
                _ProfileEditRow(
                  label: 'GitHub',
                  value: 'xiaobei-dev',
                  icon: Icons.code,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '校园认证信息',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    const Pill(
                      label: '已认证',
                      icon: Icons.verified,
                      color: AppColors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _PlainKV(label: '学号', value: '2022123456'),
                const _PlainKV(label: '认证状态', value: '已完成学生认证'),
                const _PlainKV(label: '认证时间', value: '2023-09-15'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: _isSaving ? '保存中...' : '保存修改', onPressed: _save),
        ],
      ),
    );
  }
}

class _ProfileEditTextRow extends StatelessWidget {
  const _ProfileEditTextRow({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishRow extends StatelessWidget {
  const _PublishRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      child: Row(
        children: [
          IconBubble(icon: icon, color: color, size: 34),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _PublishOption extends StatelessWidget {
  const _PublishOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconBubble(icon: icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: AppColors.muted),
    );
  }
}

class _SearchResultTab extends StatelessWidget {
  const _SearchResultTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.blue : AppColors.muted,
                fontSize: 17,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 24 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCountLine extends StatelessWidget {
  const _ResultCountLine({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '共找到 $count 条相关结果',
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _UsersResultSection extends StatelessWidget {
  const _UsersResultSection({required this.users, this.showHeader = true});

  final List<CampusUser> users;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return _ResultGroup(
      title: '用户',
      showHeader: showHeader,
      emptyLabel: '暂无匹配用户',
      isEmpty: users.isEmpty,
      child: CampusCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < users.take(3).length; i++) ...[
              _LargeUserResultTile(user: users[i]),
              if (i != users.take(3).length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivitiesResultSection extends StatelessWidget {
  const _ActivitiesResultSection({
    required this.activities,
    this.showHeader = true,
  });

  final List<CampusActivity> activities;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return _ResultGroup(
      title: '活动',
      showHeader: showHeader,
      emptyLabel: '暂无匹配活动',
      isEmpty: activities.isEmpty,
      child: Column(
        children: [
          for (final activity in activities.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LargeActivityResultCard(activity: activity),
            ),
        ],
      ),
    );
  }
}

class _PostsResultSection extends StatelessWidget {
  const _PostsResultSection({required this.posts, this.showHeader = true});

  final List<CampusPost> posts;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return _ResultGroup(
      title: '帖子',
      showHeader: showHeader,
      emptyLabel: '暂无匹配帖子',
      isEmpty: posts.isEmpty,
      child: Column(
        children: [
          for (final post in posts.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LargePostResultCard(post: post),
            ),
        ],
      ),
    );
  }
}

class _TopicsResultSection extends StatelessWidget {
  const _TopicsResultSection({required this.topics, this.showHeader = true});

  final List<CampusTopic> topics;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return _ResultGroup(
      title: '话题',
      showHeader: showHeader,
      emptyLabel: '暂无匹配话题',
      isEmpty: topics.isEmpty,
      child: CampusCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < topics.take(3).length; i++) ...[
              _LargeTopicResultTile(topic: topics[i]),
              if (i != topics.take(3).length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultGroup extends StatelessWidget {
  const _ResultGroup({
    required this.title,
    required this.child,
    required this.emptyLabel,
    required this.isEmpty,
    this.showHeader = true,
  });

  final String title;
  final Widget child;
  final String emptyLabel;
  final bool isEmpty;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: showHeader ? 18 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  const Text('查看更多', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          if (isEmpty) _EmptyResultCard(label: emptyLabel) else child,
        ],
      ),
    );
  }
}

class _LargeUserResultTile extends StatelessWidget {
  const _LargeUserResultTile({required this.user});

  final CampusUser user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          CampusAvatar(user: user, size: 66),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  user.role == null
                      ? '${user.school} · 成员'
                      : '${user.school} · ${user.role}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                const Text('128粉丝', style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue,
              side: const BorderSide(color: AppColors.blue),
              minimumSize: const Size(82, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Text('关注'),
          ),
        ],
      ),
    );
  }
}

class _LargeActivityResultCard extends StatelessWidget {
  const _LargeActivityResultCard({required this.activity});

  final CampusActivity activity;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activity: activity),
          ),
        );
      },
      child: Row(
        children: [
          SmartImage(url: activity.posterUrl, width: 122, height: 88),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _SearchMetaLine(
                  icon: Icons.calendar_month_outlined,
                  label: '${activity.date}  ${activity.time}',
                ),
                const SizedBox(height: 5),
                _SearchMetaLine(
                  icon: Icons.location_on_outlined,
                  label: activity.location,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Pill(label: '报名中', color: AppColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${activity.enrolled}人已报名',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _LargePostResultCard extends StatelessWidget {
  const _LargePostResultCard({required this.post});

  final CampusPost post;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartImage(
            url: post.images.isEmpty
                ? 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=900&q=80'
                : post.images.first,
            width: 122,
            height: 92,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 7),
                Text(
                  post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CampusAvatar(user: post.author, size: 24),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${post.author.name}    ${post.createdAt}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    const Icon(Icons.favorite_border, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likes}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeTopicResultTile extends StatelessWidget {
  const _LargeTopicResultTile({required this.topic});

  final CampusTopic topic;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: const IconBubble(icon: Icons.tag, size: 42),
      title: Text(
        '# ${topic.name}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${topic.discussions}讨论',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TopicDetailScreen(topic: topic)),
        );
      },
    );
  }
}

class _SearchMetaLine extends StatelessWidget {
  const _SearchMetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 17),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _EmptyResultCard extends StatelessWidget {
  const _EmptyResultCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(label, style: const TextStyle(color: AppColors.muted)),
      ),
    );
  }
}

class _ActionStat extends StatelessWidget {
  const _ActionStat({
    required this.icon,
    required this.value,
    this.color = AppColors.text,
    this.onTap,
  });

  final IconData icon;
  final int value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 6),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.user,
    required this.text,
    required this.likes,
    this.reply,
  });

  final CampusUser user;
  final String text;
  final int likes;
  final String? reply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampusAvatar(user: user, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    Pill(label: user.school, color: AppColors.blue),
                    const Spacer(),
                    const Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$likes',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(text),
                const SizedBox(height: 6),
                const Text(
                  '05-20 14:45    回复',
                  style: TextStyle(color: AppColors.muted),
                ),
                if (reply != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('林小北：$reply'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.actionColor,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? actionColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  color: actionColor ?? AppColors.text,
                  fontWeight: actionColor == null
                      ? FontWeight.w600
                      : FontWeight.w800,
                ),
              ),
          ],
        ),
        if (!isLast) const Divider(height: 26),
      ],
    );
  }
}

class _CompactMeta extends StatelessWidget {
  const _CompactMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    const pattern = [
      '111111101101111',
      '100000101001001',
      '101110111111101',
      '101110100010101',
      '101110111010101',
      '100000101010001',
      '111111101010111',
      '000000001000000',
      '111010111101101',
      '011100001001011',
      '101111101111001',
      '100010001000111',
      '111011111010101',
      '001000101100001',
      '111111101111111',
    ];
    final cell = size.width / pattern.length;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (var y = 0; y < pattern.length; y++) {
      for (var x = 0; x < pattern[y].length; x++) {
        if (pattern[y].codeUnitAt(x) == 49) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell * 0.92, cell * 0.92),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TicketInfoRow extends StatelessWidget {
  const _TicketInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBubble(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.muted),
      ],
    );
  }
}

class _GroupActivityTile extends StatelessWidget {
  const _GroupActivityTile({required this.activity});

  final CampusActivity activity;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SmartImage(url: activity.posterUrl, width: 86, height: 62),
      title: Text(activity.title),
      subtitle: Text(
        '${activity.date}  ${activity.time}\n${activity.enrolled}人已报名',
      ),
      isThreeLine: true,
      trailing: OutlinedButton(onPressed: () {}, child: const Text('报名中')),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activity: activity),
          ),
        );
      },
    );
  }
}

class _SimpleDiscussionTile extends StatelessWidget {
  const _SimpleDiscussionTile({required this.post});

  final CampusPost post;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CampusAvatar(user: post.author, size: 42),
      title: Text(post.title),
      subtitle: Text(post.body, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mode_comment_outlined,
            size: 17,
            color: AppColors.muted,
          ),
          const SizedBox(width: 4),
          Text('${post.comments}'),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
    );
  }
}

class _ProfileEditRow extends StatelessWidget {
  const _ProfileEditRow({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (icon != null) ...[
            Icon(icon, color: AppColors.blue, size: 18),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _PlainKV extends StatelessWidget {
  const _PlainKV({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
