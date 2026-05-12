import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/sample_data.dart';
import '../models/campus_feed.dart';
import '../models/campus_models.dart';
import '../repositories/auth_session.dart';
import '../repositories/campus_repository.dart';
import '../repositories/campus_event_bus.dart';
import 'activity_feature_pages.dart';
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

String _detailFriendlyTime(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '刚刚';

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final time = parsed.toLocal();
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 && now.day == time.day) {
    return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 7) return '${diff.inDays}天前';

  return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class PublishPostScreen extends StatefulWidget {
  const PublishPostScreen({super.key, this.initialDraft, this.initialPost});

  final CampusDraft? initialDraft;
  final CampusPost? initialPost;

  @override
  State<PublishPostScreen> createState() => _PublishPostScreenState();
}

class _PublishPostScreenState extends State<PublishPostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _topicController = TextEditingController(text: '校园生活');
  final _locationController = TextEditingController();
  final List<String> _imageUrls = [];
  var _isSubmitting = false;
  var _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _fillFromInitialDraft();
  }

  void _fillFromInitialDraft() {
    final post = widget.initialPost;
    if (post != null) {
      _titleController.text = post.title;
      _bodyController.text = post.body;
      if (post.topic.trim().isNotEmpty) {
        _topicController.text = post.topic.trim();
      }
      if (post.location.trim().isNotEmpty) {
        _locationController.text = post.location.trim();
      }
      _imageUrls
        ..clear()
        ..addAll(post.images);
      return;
    }

    final draft = widget.initialDraft;
    if (draft == null) return;

    _titleController.text = draft.title;
    _bodyController.text = draft.body;
    if (draft.topic.trim().isNotEmpty) {
      _topicController.text = draft.topic.trim();
    }
    if (draft.location.trim().isNotEmpty) {
      _locationController.text = draft.location.trim();
    }
    _imageUrls
      ..clear()
      ..addAll(draft.images);
  }

  String _autoTitleFromBody(String body) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '未命名动态';
    if (normalized.length <= 18) return normalized;
    return '${normalized.substring(0, 18)}...';
  }

  Future<void> _editLocation() async {
    final controller = TextEditingController(text: _locationController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('所在位置'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '例如：图书馆 / 大学生活动中心'),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('清空'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || result == null) return;
    setState(() => _locationController.text = result.trim());
  }

  Future<void> _deleteInitialDraftQuietly() async {
    final draft = widget.initialDraft;
    if (draft == null || draft.id.isEmpty) return;
    try {
      await CampusRepository.instance.deleteDraft(draft);
    } catch (_) {
      // 发布/另存成功后清理旧草稿失败不影响主流程。
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _topicController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage || _imageUrls.length >= 9) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await CampusRepository.instance.uploadImage(
        picked.path,
        purpose: 'post',
      );
      if (!mounted) return;
      setState(() => _imageUrls.add(url));
      _showMessage(context, '图片已上传');
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _submit() async {
    final rawTitle = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      _showMessage(context, '请填写动态内容');
      return;
    }
    final title = rawTitle.isEmpty ? _autoTitleFromBody(body) : rawTitle;

    setState(() => _isSubmitting = true);
    try {
      final topic = _topicController.text.trim().isEmpty
          ? '校园生活'
          : _topicController.text.trim();
      final location = _locationController.text.trim();

      if (widget.initialPost == null) {
        await CampusRepository.instance.createPost(
          title: title,
          body: body,
          topic: topic,
          location: location,
          images: _imageUrls,
        );
      } else {
        await CampusRepository.instance.updatePost(
          post: widget.initialPost!,
          title: title,
          body: body,
          topic: topic,
          location: location,
          images: _imageUrls,
        );
      }

      await _deleteInitialDraftQuietly();
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
        images: _imageUrls,
      );
      await _deleteInitialDraftQuietly();
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
        title: Text(
          widget.initialPost != null
              ? '编辑帖子'
              : widget.initialDraft == null
              ? '发布动态'
              : '继续编辑',
        ),
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
              child: Text(
                _isSubmitting
                    ? '处理中...'
                    : widget.initialPost != null
                    ? '保存'
                    : '发布',
              ),
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
              itemCount: _imageUrls.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == _imageUrls.length) {
                  return InkWell(
                    onTap: _pickAndUploadImage,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.muted.withValues(alpha: 0.35),
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isUploadingImage)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.add,
                              size: 32,
                              color: AppColors.muted,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _isUploadingImage ? '上传中' : '添加照片',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    SmartImage(url: _imageUrls[index], width: 90, height: 90),
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
                        child: InkWell(
                          onTap: () {
                            setState(() => _imageUrls.removeAt(index));
                          },
                          child: const Icon(Icons.close, size: 16),
                        ),
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
          InkWell(
            onTap: _isSubmitting ? null : _editLocation,
            borderRadius: BorderRadius.circular(18),
            child: _PublishRow(
              icon: Icons.location_on,
              color: AppColors.green,
              title: '所在位置',
              value: _locationController.text.trim().isEmpty
                  ? '点击添加位置'
                  : _locationController.text.trim(),
            ),
          ),
          const SizedBox(height: 12),
          CampusCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.visibility, color: AppColors.blue),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    '谁可以看',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Text(
                  '公开 · 所有人可见',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox.shrink(),
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
  CampusDiscover _discover = CampusDiscover.fromFeed(
    CampusRepository.instance.cachedFeed,
  );

  @override
  void initState() {
    super.initState();
    _loadDiscover();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDiscover() async {
    final discover = await CampusRepository.instance.fetchDiscover();
    if (!mounted) return;
    setState(() => _discover = discover);
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
    final hotSearches = _discover.hotSearches.isEmpty
        ? ['摄影社团招新', '篮球联赛', '志愿者活动', '考研经验分享', '校园音乐节', 'AI 未来发展']
        : _discover.hotSearches.take(6).toList(growable: false);

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
              for (var i = 0; i < hotSearches.length; i++)
                InkWell(
                  onTap: () {
                    final keyword = hotSearches[i];
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
                          hotSearches[i],
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
  int _searchRequestId = 0;
  String _selectedSort = 'relevance';

  static const _tabs = ['综合', '用户', '活动', '帖子', '社群', '话题'];
  static const _tabTypes = [
    'all',
    'users',
    'activities',
    'posts',
    'groups',
    'topics',
  ];
  static const _sortOptions = [
    ('relevance', '相关'),
    ('popular', '热门'),
    ('latest', '最新'),
  ];

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
    if (normalizedQuery.isEmpty) {
      setState(() {
        _result = CampusSearchResult.empty();
        _isLoading = false;
      });
      return;
    }

    final requestId = ++_searchRequestId;
    setState(() => _isLoading = true);
    final result = await CampusRepository.instance.search(
      normalizedQuery,
      type: _tabTypes[_selectedTab],
      sort: _selectedSort,
    );
    if (!mounted || requestId != _searchRequestId) return;
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    _runSearch(_controller.text);
  }

  void _selectSort(String sort) {
    if (_selectedSort == sort) return;
    setState(() => _selectedSort = sort);
    _runSearch(_controller.text);
  }

  int get _resultCount =>
      _result.users.length +
      _result.activities.length +
      _result.posts.length +
      _result.groups.length +
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
      4 => [_GroupsResultSection(groups: _result.groups, showHeader: false)],
      5 => [_TopicsResultSection(topics: _result.topics, showHeader: false)],
      _ => [
        _ResultCountLine(count: _resultCount),
        const SizedBox(height: 18),
        _UsersResultSection(users: _result.users),
        _ActivitiesResultSection(activities: _result.activities),
        _PostsResultSection(posts: _result.posts),
        _GroupsResultSection(groups: _result.groups),
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
                            _searchRequestId++;
                            setState(() {
                              _result = CampusSearchResult.empty();
                              _isLoading = false;
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
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  return SizedBox(
                    width: 58,
                    child: _SearchResultTab(
                      label: _tabs[i],
                      selected: _selectedTab == i,
                      onTap: () => _selectTab(i),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(
                children: [
                  for (final option in _sortOptions) ...[
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: _selectedSort == option.$1,
                      onSelected: (_) => _selectSort(option.$1),
                      showCheckmark: false,
                      selectedColor: AppColors.blue.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: _selectedSort == option.$1
                            ? AppColors.blue
                            : AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                      side: BorderSide(
                        color: _selectedSort == option.$1
                            ? AppColors.blue
                            : AppColors.line,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  Text(
                    _isLoading ? '搜索中' : '实时结果',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
  var _isLiking = false;
  var _isFavoriting = false;
  var _isFollowingAuthor = false;
  late bool _postLiked = widget.post.likedByMe;
  var _postFavorited = false;
  late bool _authorFollowed = widget.post.author.followedByMe;

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
    _loadFavoriteStatus();
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
      // 不再展示演示评论：接口为空就展示空状态，避免真实帖子下面混入假评论。
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _loadFavoriteStatus() async {
    if (_post.id.isEmpty) return;
    try {
      final favorites = await CampusRepository.instance.fetchFavorites();
      if (!mounted) return;

      final favorited = favorites.any((record) {
        return record.kind == 'post' && record.post.id == _post.id;
      });

      setState(() => _postFavorited = favorited);
    } catch (_) {
      // 收藏状态加载失败不影响详情页主流程。
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final previousPost = _post;
    final previousLiked = _postLiked;
    final nextLiked = !previousLiked;

    setState(() {
      _isLiking = true;
      _postLiked = nextLiked;
      final nextLikes = _post.likes + (nextLiked ? 1 : -1);
      _post = _post.copyWith(likes: nextLikes < 0 ? 0 : nextLikes);
    });

    try {
      final post = await CampusRepository.instance.togglePostLike(previousPost);
      if (!mounted) return;

      setState(() {
        _post = post;
        _postLiked = post.likedByMe;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _post = previousPost;
        _postLiked = previousLiked;
      });
      _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriting) return;

    final wasFavorited = _postFavorited;
    setState(() => _isFavoriting = true);

    try {
      final post = await CampusRepository.instance.togglePostFavorite(_post);
      if (!mounted) return;

      setState(() {
        _post = post;
        _postFavorited = !wasFavorited;
      });

      _showMessage(context, _postFavorited ? '已收藏' : '已取消收藏');
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isFavoriting = false);
    }
  }

  bool get _isMine {
    final user = AuthSession.user;
    if (user == null) return false;
    if (user.id.isNotEmpty && _post.author.id.isNotEmpty) {
      return user.id == _post.author.id;
    }
    return user.name == _post.author.name;
  }

  CampusPost? _cachedPostById(String id) {
    if (id.isEmpty) return null;

    final feed = CampusRepository.instance.cachedFeed;
    for (final post in feed.posts) {
      if (post.id == id) return post;
    }

    for (final group in feed.groups) {
      for (final post in group.discussions) {
        if (post.id == id) return post;
      }
    }

    for (final topic in feed.topics) {
      for (final post in topic.posts) {
        if (post.id == id) return post;
      }
    }

    return null;
  }

  Future<void> _editPost() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PublishPostScreen(initialPost: _post)),
    );

    if (changed == true && mounted) {
      final next = _cachedPostById(_post.id);
      if (next != null) {
        setState(() {
          _post = next;
        });
      }
      _showMessage(context, '帖子已更新');
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除帖子'),
          content: const Text('确定删除这条帖子吗？删除后评论、收藏和浏览记录也会同步移除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await CampusRepository.instance.deletePost(_post);
      if (!mounted) return;
      _showMessage(context, '帖子已删除');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  Future<void> _showPostActions() async {
    if (!_isMine) {
      _showMessage(context, '只能编辑或删除自己发布的帖子');
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑帖子'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.red,
                ),
                title: const Text(
                  '删除帖子',
                  style: TextStyle(color: AppColors.red),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'edit') {
      await _editPost();
    } else if (action == 'delete') {
      await _deletePost();
    }
  }

  Future<void> _toggleAuthorFollow() async {
    if (_isFollowingAuthor) return;
    setState(() => _isFollowingAuthor = true);
    try {
      final nextUser = _authorFollowed
          ? await CampusRepository.instance.unfollowUser(_post.author)
          : await CampusRepository.instance.followUser(_post.author);
      if (!mounted) return;
      setState(() {
        _authorFollowed = nextUser.followedByMe;
        _post = _post.copyWith(author: nextUser);
      });
      _showMessage(context, _authorFollowed ? '已关注 ${nextUser.name}' : '已取消关注');
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isFollowingAuthor = false);
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
          IconButton(
            onPressed: _showPostActions,
            icon: const Icon(Icons.more_horiz),
          ),
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
                      '${_detailFriendlyTime(post.createdAt)} · 来自 社区',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isFollowingAuthor ? null : _toggleAuthorFollow,
                icon: Icon(
                  _isFollowingAuthor
                      ? Icons.hourglass_top_rounded
                      : _authorFollowed
                      ? Icons.check_rounded
                      : Icons.add,
                  size: 18,
                ),
                label: Text(
                  _isFollowingAuthor
                      ? '处理中'
                      : _authorFollowed
                      ? '已关注'
                      : '关注',
                ),
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
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < post.images.take(3).length; i++) ...[
                Expanded(child: SmartImage(url: post.images[i], height: 116)),
                if (i != 2) const SizedBox(width: 8),
              ],
            ],
          ),
          if (post.location.trim().isNotEmpty &&
              post.location.trim() != '图书馆广场') ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Pill(
                label: post.location.trim(),
                icon: Icons.location_on,
                color: AppColors.blue,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionStat(
                icon: _isLiking
                    ? Icons.hourglass_top_rounded
                    : (_postLiked
                          ? Icons.favorite
                          : Icons.favorite_border_rounded),
                value: post.likes,
                color: _postLiked ? AppColors.red : AppColors.text,
                onTap: _isLiking ? null : _toggleLike,
              ),
              _ActionStat(
                icon: Icons.mode_comment_outlined,
                value: post.comments,
              ),
              _ActionStat(
                icon: _isFavoriting
                    ? Icons.hourglass_top_rounded
                    : (_postFavorited
                          ? Icons.star_rounded
                          : Icons.star_border_rounded),
                value: post.saves,
                color: _postFavorited ? AppColors.orange : AppColors.text,
                onTap: _isFavoriting ? null : _toggleFavorite,
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

          if (!_isLoadingComments && _comments.isEmpty)
            CampusCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mode_comment_outlined,
                        color: AppColors.muted,
                        size: 34,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '暂无真实评论',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '发布第一条评论后，会显示在这里',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                createdAt: comment.createdAt,
              )
          else
            ...[],
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
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('签到说明'),
                            content: const Text('活动开始后，请凭电子票或签到码完成现场签到。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('知道了'),
                              ),
                            ],
                          ),
                        );
                      },
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
  StreamSubscription<CampusDataEvent>? _groupSubscription;
  var _isLoading = false;
  var _isSubmitting = false;
  var _isReloadingFromEvent = false;

  @override
  void initState() {
    super.initState();
    _groupSubscription = CampusEventBus.instance.stream.listen(_onGroupEvent);

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

  @override
  void didUpdateWidget(covariant GroupDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id ||
        oldWidget.group.joined != widget.group.joined ||
        oldWidget.group.membershipStatus != widget.group.membershipStatus ||
        oldWidget.group.members != widget.group.members) {
      _group = widget.group;
      _loadDetail(showLoading: false);
    }
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }

  void _onGroupEvent(CampusDataEvent event) {
    if (!mounted) return;

    final groupId = _group.id;
    if (groupId.isEmpty) return;

    final isCurrentGroupEvent = event.matches(
      CampusEventType.groupChanged,
      refId: groupId,
    );

    if (!isCurrentGroupEvent) return;

    final payload = event.payload;
    if (payload is CampusGroup && payload.id == groupId) {
      setState(() => _group = payload);
    }

    _loadDetail(showLoading: false);
  }

  Future<void> _loadDetail({bool showLoading = true}) async {
    if (_group.id.isEmpty) return;
    if (_isReloadingFromEvent && !showLoading) return;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    if (!showLoading) {
      _isReloadingFromEvent = true;
    }

    try {
      final group = await CampusRepository.instance.fetchGroupDetail(_group);
      if (mounted) setState(() => _group = group);
    } catch (_) {
      // The screen can still render the feed copy if detail loading fails.
    } finally {
      if (!showLoading) {
        _isReloadingFromEvent = false;
      }
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
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
      if (group.membershipStatus == 'pending') {
        _showMessage(context, '入群申请已提交，等待管理员审核');
      } else {
        _showMessage(
          context,
          group.joined ? '已加入 ${group.name}' : '已退出 ${group.name}',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openManagedGroups() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyManagedGroupsScreen()),
    );
    if (mounted) _loadDetail();
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final announcementText = group.announcementText.trim();
    final sortedDiscussions =
        group.discussions
            .where(
              (post) =>
                  post.title.trim().isNotEmpty || post.body.trim().isNotEmpty,
            )
            .toList(growable: true)
          ..sort((left, right) {
            if (left.pinnedInGroup == right.pinnedInGroup) return 0;
            return left.pinnedInGroup ? -1 : 1;
          });

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
                                    Pill(
                                      label: _groupVisibilityLabel(
                                        group.visibility,
                                      ),
                                      color: _groupVisibilityColor(
                                        group.visibility,
                                      ),
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
                        if (announcementText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _GroupAnnouncementCard(
                            text: announcementText,
                            updatedAt: group.announcementUpdatedAt,
                            updatedBy: group.announcementUpdatedBy,
                          ),
                        ],
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
                        if (group.activities.isEmpty)
                          const CampusCard(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: Text(
                                  '暂无即将开展的活动',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            ),
                          )
                        else
                          CampusCard(
                            child: Column(
                              children: group.activities
                                  .map(
                                    (activity) =>
                                        _GroupActivityTile(activity: activity),
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
                        if (sortedDiscussions.isEmpty)
                          const CampusCard(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: Text(
                                  '暂无热门讨论',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            ),
                          )
                        else
                          CampusCard(
                            child: Column(
                              children: [
                                for (final post in sortedDiscussions)
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
                    onPressed: () => _showMessage(context, '分享功能正在完善中'),
                    icon: const Icon(Icons.ios_share),
                  ),
                  IconButton.filledTonal(
                    onPressed: _openManagedGroups,
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
                : group.canManage
                ? '进入管理台'
                : group.membershipStatus == 'pending'
                ? '申请审核中'
                : group.joined
                ? '退出社群'
                : '申请加入',
            color: group.canManage
                ? AppColors.blue
                : group.joined
                ? AppColors.red
                : AppColors.blue,
            onPressed: group.membershipStatus == 'pending'
                ? () => _showMessage(context, '入群申请正在审核中')
                : group.canManage
                ? _openManagedGroups
                : _toggleJoin,
          ),
        ),
      ),
    );
  }
}

class MyManagedGroupsScreen extends StatefulWidget {
  const MyManagedGroupsScreen({super.key});

  @override
  State<MyManagedGroupsScreen> createState() => _MyManagedGroupsScreenState();
}

class _MyManagedGroupsScreenState extends State<MyManagedGroupsScreen> {
  late Future<List<CampusGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadGroups();
  }

  Future<List<CampusGroup>> _loadGroups() {
    return CampusRepository.instance.fetchManagedGroups();
  }

  void _refresh() {
    setState(() {
      _future = _loadGroups();
    });
  }

  Future<void> _openCreate() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GroupEditorScreen()),
    );
    if (changed == true && mounted) _refresh();
  }

  Future<void> _openManagement(CampusGroup group) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GroupManagementScreen(group: group)),
    );
    if (changed == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('我管理的社群'),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<CampusGroup>>(
        future: _future,
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <CampusGroup>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              CampusCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppColors.blue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? '正在同步社群管理数据'
                            : '当前管理 ${groups.length} 个社群',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (groups.isEmpty)
                CampusCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.groups_2_outlined,
                        size: 46,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '你还没有管理中的社群',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '现在就创建一个新的校园社群吧',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(label: '创建社群', onPressed: _openCreate),
                    ],
                  ),
                )
              else
                for (var index = 0; index < groups.length; index++) ...[
                  _ManagedGroupCard(
                    group: groups[index],
                    onTap: () => _openManagement(groups[index]),
                  ),
                  if (index != groups.length - 1) const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({required this.group, super.key});

  final CampusGroup group;

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late CampusGroup _group;
  var _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _reload();
  }

  Future<void> _reload() async {
    try {
      final group = await CampusRepository.instance.fetchGroupDetail(_group);
      if (mounted) setState(() => _group = group);
    } catch (_) {}
  }

  Future<void> _openEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupEditorScreen(initialGroup: _group),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _openMembers() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupMembersManagementScreen(group: _group),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _openJoinRequests() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GroupJoinRequestsScreen(group: _group)),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _openAnnouncement() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupAnnouncementEditorScreen(group: _group),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _openDiscussions() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDiscussionsManagementScreen(group: _group),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _openActivities() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateActivityScreen(groupContext: _group),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _deleteGroup() async {
    if (_group.membershipRole != 'owner' || _isDeleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解散社群'),
        content: Text('确认解散「${_group.name}」吗？这个操作不能撤回。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解散'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await CampusRepository.instance.deleteGroup(_group);
      if (!mounted) return;
      _showMessage(context, '社群已解散');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('社群管理')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          CampusCard(
            child: Row(
              children: [
                SmartImage(
                  url: _group.iconUrl,
                  width: 66,
                  height: 66,
                  borderRadius: 16,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _group.name,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_group.members} 位成员 · ${_group.admins} 位管理员',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Pill(
                            label: _groupVisibilityLabel(_group.visibility),
                            color: _groupVisibilityColor(_group.visibility),
                          ),
                          Pill(
                            label: _groupRoleLabel(_group.membershipRole),
                            color: AppColors.blue,
                          ),
                        ],
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
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.blue,
                  ),
                  title: const Text('编辑社群资料'),
                  subtitle: const Text('名称、简介、封面、标签、可见范围'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openEdit,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.group_outlined,
                    color: AppColors.purple,
                  ),
                  title: const Text('成员管理'),
                  subtitle: const Text('查看成员，设置管理员，移除成员'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openMembers,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.how_to_reg_outlined,
                    color: AppColors.green,
                  ),
                  title: const Text('入群申请'),
                  subtitle: const Text('审核待加入的同学'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openJoinRequests,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.campaign_outlined,
                    color: AppColors.orange,
                  ),
                  title: const Text('群公告'),
                  subtitle: const Text('发布或更新社群公告'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openAnnouncement,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.forum_outlined,
                    color: AppColors.green,
                  ),
                  title: const Text('讨论运营'),
                  subtitle: const Text('发布群内讨论，设置或取消置顶'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openDiscussions,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.event_note_outlined,
                    color: AppColors.blue,
                  ),
                  title: const Text('社群活动'),
                  subtitle: const Text('按社群维度发起活动'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openActivities,
                ),
                if (_group.membershipRole == 'owner') ...[
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.red,
                    ),
                    title: const Text('解散社群'),
                    subtitle: Text(_isDeleting ? '处理中...' : '删除社群及其成员关系'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _isDeleting ? null : _deleteGroup,
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

class GroupAnnouncementEditorScreen extends StatefulWidget {
  const GroupAnnouncementEditorScreen({required this.group, super.key});

  final CampusGroup group;

  @override
  State<GroupAnnouncementEditorScreen> createState() =>
      _GroupAnnouncementEditorScreenState();
}

class _GroupAnnouncementEditorScreenState
    extends State<GroupAnnouncementEditorScreen> {
  late final TextEditingController _controller;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.group.announcementText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final group = await CampusRepository.instance.updateGroupAnnouncement(
        group: widget.group,
        text: _controller.text.trim(),
      );
      if (!mounted) return;
      _showMessage(context, group.announcementText.isEmpty ? '公告已清空' : '公告已更新');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('群公告')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          CampusCard(
            child: TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 8,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '写一条要让所有成员第一眼看到的公告',
              ),
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSubmitting ? '保存中...' : '保存公告',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class GroupDiscussionsManagementScreen extends StatefulWidget {
  const GroupDiscussionsManagementScreen({required this.group, super.key});

  final CampusGroup group;

  @override
  State<GroupDiscussionsManagementScreen> createState() =>
      _GroupDiscussionsManagementScreenState();
}

class _GroupDiscussionsManagementScreenState
    extends State<GroupDiscussionsManagementScreen> {
  late CampusGroup _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _reload();
  }

  Future<void> _reload() async {
    try {
      final group = await CampusRepository.instance.fetchGroupDetail(_group);
      if (mounted) setState(() => _group = group);
    } catch (_) {}
  }

  Future<void> _createDiscussion() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDiscussionComposerScreen(group: _group),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _togglePin(CampusPost post) async {
    try {
      final nextGroup = await CampusRepository.instance
          .toggleGroupDiscussionPin(
            group: _group,
            post: post,
            pinned: !post.pinnedInGroup,
          );
      if (!mounted) return;
      setState(() => _group = nextGroup);
      _showMessage(context, post.pinnedInGroup ? '已取消置顶' : '已设为置顶');
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final discussions = [..._group.discussions]
      ..sort((left, right) {
        if (left.pinnedInGroup == right.pinnedInGroup) return 0;
        return left.pinnedInGroup ? -1 : 1;
      });
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('讨论运营'),
        actions: [
          IconButton(
            onPressed: _createDiscussion,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          for (var index = 0; index < discussions.length; index++) ...[
            CampusCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                discussions[index].title,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (discussions[index].pinnedInGroup)
                              const Pill(label: '置顶', color: AppColors.red),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          discussions[index].body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          discussions[index].author.name,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (_) => _togglePin(discussions[index]),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'pin',
                        child: Text(
                          discussions[index].pinnedInGroup ? '取消置顶' : '设为置顶',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (index != discussions.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDiscussion,
        backgroundColor: AppColors.blue,
        label: const Text('发布讨论'),
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class GroupDiscussionComposerScreen extends StatefulWidget {
  const GroupDiscussionComposerScreen({required this.group, super.key});

  final CampusGroup group;

  @override
  State<GroupDiscussionComposerScreen> createState() =>
      _GroupDiscussionComposerScreenState();
}

class _GroupDiscussionComposerScreenState
    extends State<GroupDiscussionComposerScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  late final TextEditingController _topicController;
  final _locationController = TextEditingController();
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: '${widget.group.name}讨论');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _topicController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      _showMessage(context, '请填写讨论标题和内容');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await CampusRepository.instance.createGroupPost(
        group: widget.group,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        topic: _topicController.text.trim(),
        location: _locationController.text.trim(),
      );
      if (!mounted) return;
      _showMessage(context, '群内讨论已发布');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('发布群内讨论')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          CampusCard(
            child: Column(
              children: [
                _GroupFormField(
                  label: '标题',
                  controller: _titleController,
                  hint: '讨论一个值得大家参与的话题',
                ),
                const Divider(),
                _GroupFormField(
                  label: '话题',
                  controller: _topicController,
                  hint: '例如：编程学习小组讨论',
                ),
                const Divider(),
                _GroupFormField(
                  label: '地点',
                  controller: _locationController,
                  hint: '线上 / 教学楼 / 图书馆',
                ),
                const Divider(),
                _GroupFormField(
                  label: '内容',
                  controller: _bodyController,
                  hint: '写下讨论背景、希望大家怎么参与',
                  minLines: 5,
                  maxLines: 7,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSubmitting ? '发布中...' : '发布讨论',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class GroupEditorScreen extends StatefulWidget {
  const GroupEditorScreen({this.initialGroup, super.key});

  final CampusGroup? initialGroup;

  bool get isEditing => initialGroup != null;

  @override
  State<GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends State<GroupEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _iconUrlController;
  late final TextEditingController _tagsController;
  late String _visibility;
  var _isSubmitting = false;
  var _isUploadingCover = false;
  var _isUploadingIcon = false;

  @override
  void initState() {
    super.initState();
    final group = widget.initialGroup;
    _nameController = TextEditingController(text: group?.name ?? '');
    _descriptionController = TextEditingController(
      text: group?.description ?? '',
    );
    _coverUrlController = TextEditingController(
      text:
          group?.coverUrl ??
          'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80',
    );
    _iconUrlController = TextEditingController(
      text:
          group?.iconUrl ??
          'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=500&q=80',
    );
    _tagsController = TextEditingController(text: group?.tags.join(',') ?? '');
    _visibility = group?.visibility ?? 'approval';
  }

  Future<void> _pickGroupImage({required bool cover}) async {
    if (_isUploadingCover || _isUploadingIcon) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: cover ? 1800 : 900,
    );
    if (picked == null) return;

    setState(() {
      if (cover) {
        _isUploadingCover = true;
      } else {
        _isUploadingIcon = true;
      }
    });
    try {
      final url = await CampusRepository.instance.uploadImage(
        picked.path,
        purpose: cover ? 'group_cover' : 'group_icon',
      );
      if (!mounted) return;
      setState(() {
        if (cover) {
          _coverUrlController.text = url;
        } else {
          _iconUrlController.text = url;
        }
      });
      _showMessage(context, cover ? '社群封面已上传' : '社群图标已上传');
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          if (cover) {
            _isUploadingCover = false;
          } else {
            _isUploadingIcon = false;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _coverUrlController.dispose();
    _iconUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_nameController.text.trim().isEmpty) {
      _showMessage(context, '请先填写社群名称');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final tags = _tagsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      final group = widget.isEditing
          ? await CampusRepository.instance.updateGroup(
              group: widget.initialGroup!,
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              coverUrl: _coverUrlController.text.trim(),
              iconUrl: _iconUrlController.text.trim(),
              tags: tags,
              visibility: _visibility,
            )
          : await CampusRepository.instance.createGroup(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              coverUrl: _coverUrlController.text.trim(),
              iconUrl: _iconUrlController.text.trim(),
              tags: tags,
              visibility: _visibility,
            );
      if (!mounted) return;
      _showMessage(
        context,
        widget.isEditing ? '已更新 ${group.name}' : '已创建 ${group.name}',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(widget.isEditing ? '编辑社群' : '创建社群')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          CampusCard(
            child: Column(
              children: [
                _GroupFormField(
                  label: '社群名称',
                  controller: _nameController,
                  hint: '例如：编程学习小组',
                ),
                const Divider(),
                _GroupFormField(
                  label: '社群简介',
                  controller: _descriptionController,
                  hint: '介绍社群定位、适合谁加入',
                  minLines: 3,
                  maxLines: 4,
                ),
                const Divider(),
                _GroupFormField(
                  label: '封面链接',
                  controller: _coverUrlController,
                  hint: '请输入封面图片 URL',
                  trailing: IconButton(
                    onPressed: _isUploadingCover
                        ? null
                        : () => _pickGroupImage(cover: true),
                    icon: _isUploadingCover
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded),
                  ),
                ),
                const Divider(),
                _GroupFormField(
                  label: '图标链接',
                  controller: _iconUrlController,
                  hint: '请输入图标图片 URL',
                  trailing: IconButton(
                    onPressed: _isUploadingIcon
                        ? null
                        : () => _pickGroupImage(cover: false),
                    icon: _isUploadingIcon
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded),
                  ),
                ),
                const Divider(),
                _GroupFormField(
                  label: '标签',
                  controller: _tagsController,
                  hint: '多个标签用逗号分隔',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '加入方式',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in const [
                      'public',
                      'approval',
                      'private',
                    ])
                      ChoiceChip(
                        label: Text(_groupVisibilityLabel(option)),
                        selected: _visibility == option,
                        onSelected: (_) => setState(() => _visibility = option),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSubmitting
                ? (widget.isEditing ? '保存中...' : '创建中...')
                : (widget.isEditing ? '保存修改' : '创建社群'),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class GroupMembersManagementScreen extends StatefulWidget {
  const GroupMembersManagementScreen({required this.group, super.key});

  final CampusGroup group;

  @override
  State<GroupMembersManagementScreen> createState() =>
      _GroupMembersManagementScreenState();
}

class _GroupMembersManagementScreenState
    extends State<GroupMembersManagementScreen> {
  late Future<List<CampusGroupMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadMembers();
  }

  Future<List<CampusGroupMember>> _loadMembers() {
    return CampusRepository.instance.fetchGroupMembers(widget.group);
  }

  void _refresh() {
    setState(() {
      _future = _loadMembers();
    });
  }

  Future<void> _changeRole(CampusGroupMember member, String role) async {
    try {
      await CampusRepository.instance.updateGroupMemberRole(
        group: widget.group,
        member: member,
        role: role,
      );
      if (!mounted) return;
      _showMessage(context, role == 'admin' ? '已设为管理员' : '已改为普通成员');
      _refresh();
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  Future<void> _removeMember(CampusGroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确认将 ${member.user.name} 移出社群吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await CampusRepository.instance.removeGroupMember(
        group: widget.group,
        member: member,
      );
      if (!mounted) return;
      _showMessage(context, '成员已移除');
      _refresh();
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('成员管理')),
      body: FutureBuilder<List<CampusGroupMember>>(
        future: _future,
        builder: (context, snapshot) {
          final members = snapshot.data ?? const <CampusGroupMember>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              CampusCard(
                child: Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? '正在同步成员列表'
                      : '共 ${members.length} 位成员',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < members.length; index++) ...[
                _GroupMemberCard(
                  member: members[index],
                  canPromote:
                      widget.group.membershipRole == 'owner' &&
                      members[index].role != 'owner',
                  canRemove:
                      members[index].role != 'owner' &&
                      (widget.group.membershipRole == 'owner' ||
                          members[index].role == 'member'),
                  onPromote: members[index].role == 'admin'
                      ? () => _changeRole(members[index], 'member')
                      : () => _changeRole(members[index], 'admin'),
                  onRemove: () => _removeMember(members[index]),
                ),
                if (index != members.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class GroupJoinRequestsScreen extends StatefulWidget {
  const GroupJoinRequestsScreen({required this.group, super.key});

  final CampusGroup group;

  @override
  State<GroupJoinRequestsScreen> createState() =>
      _GroupJoinRequestsScreenState();
}

class _GroupJoinRequestsScreenState extends State<GroupJoinRequestsScreen> {
  late Future<List<CampusGroupMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRequests();
  }

  Future<List<CampusGroupMember>> _loadRequests() {
    return CampusRepository.instance.fetchGroupJoinRequests(widget.group);
  }

  void _refresh() {
    setState(() {
      _future = _loadRequests();
    });
  }

  Future<void> _review(CampusGroupMember request, bool approved) async {
    final previousFuture = _future;

    setState(() {
      _future = previousFuture.then(
        (items) => items
            .where((item) => item.id != request.id)
            .toList(growable: false),
      );
    });

    try {
      await CampusRepository.instance.reviewGroupJoinRequest(
        group: widget.group,
        request: request,
        approved: approved,
      );
      if (!mounted) return;
      _showMessage(context, approved ? '已通过入群申请' : '已拒绝入群申请');
      _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _future = previousFuture);
      _showMessage(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('入群申请')),
      body: FutureBuilder<List<CampusGroupMember>>(
        future: _future,
        builder: (context, snapshot) {
          final requests = snapshot.data ?? const <CampusGroupMember>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              CampusCard(
                child: Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? '正在同步申请列表'
                      : '待审核 ${requests.length} 条申请',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (requests.isEmpty)
                const CampusCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        '暂无待审核申请',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                )
              else
                for (var index = 0; index < requests.length; index++) ...[
                  _GroupJoinRequestCard(
                    request: requests[index],
                    onApprove: () => _review(requests[index], true),
                    onReject: () => _review(requests[index], false),
                  ),
                  if (index != requests.length - 1) const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _ManagedGroupCard extends StatelessWidget {
  const _ManagedGroupCard({required this.group, required this.onTap});

  final CampusGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            SmartImage(
              url: group.iconUrl,
              width: 70,
              height: 70,
              borderRadius: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${group.members} 位成员 · ${group.admins} 位管理员',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Pill(
                        label: _groupRoleLabel(group.membershipRole),
                        color: AppColors.blue,
                      ),
                      Pill(
                        label: _groupVisibilityLabel(group.visibility),
                        color: _groupVisibilityColor(group.visibility),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _GroupMemberCard extends StatelessWidget {
  const _GroupMemberCard({
    required this.member,
    required this.canPromote,
    required this.canRemove,
    required this.onPromote,
    required this.onRemove,
  });

  final CampusGroupMember member;
  final bool canPromote;
  final bool canRemove;
  final VoidCallback onPromote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      child: Row(
        children: [
          CampusAvatar(user: member.user, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.user.name,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(
                      label: _groupRoleLabel(member.role),
                      color: member.role == 'owner'
                          ? AppColors.orange
                          : member.role == 'admin'
                          ? AppColors.blue
                          : AppColors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${member.user.school} · ${member.user.grade}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: canPromote || canRemove,
            onSelected: (value) {
              if (value == 'promote') onPromote();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (context) => [
              if (canPromote)
                PopupMenuItem<String>(
                  value: 'promote',
                  child: Text(member.role == 'admin' ? '撤销管理员' : '设为管理员'),
                ),
              if (canRemove)
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('移除成员'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupJoinRequestCard extends StatelessWidget {
  const _GroupJoinRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final CampusGroupMember request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      child: Column(
        children: [
          Row(
            children: [
              CampusAvatar(user: request.user, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.user.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${request.user.school} · ${request.user.grade}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Pill(label: '待审核', color: AppColors.orange),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: const Text('拒绝'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  child: const Text('通过'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupFormField extends StatelessWidget {
  const _GroupFormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

String _groupVisibilityLabel(String value) {
  switch (value) {
    case 'public':
      return '公开加入';
    case 'private':
      return '仅邀请';
    default:
      return '需审核';
  }
}

Color _groupVisibilityColor(String value) {
  switch (value) {
    case 'public':
      return AppColors.green;
    case 'private':
      return AppColors.orange;
    default:
      return AppColors.blue;
  }
}

String _groupRoleLabel(String value) {
  switch (value) {
    case 'owner':
      return '群主';
    case 'admin':
      return '管理员';
    default:
      return '成员';
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
          IconButton(
            onPressed: () => _showMessage(context, '分享功能正在完善中'),
            icon: const Icon(Icons.ios_share),
          ),
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
                        onPressed: () =>
                            _showMessage(context, '已关注 ${user.name}'),
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
  var _isUploadingAvatar = false;

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

  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 900,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await CampusRepository.instance.uploadImage(
        picked.path,
        purpose: 'avatar',
      );
      if (!mounted) return;
      setState(() => _user = _user.copyWith(avatarUrl: url));
      _showMessage(context, '头像已上传');
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
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
                    InkWell(
                      onTap: _pickAvatar,
                      borderRadius: BorderRadius.circular(44),
                      child: Stack(
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
                              child: _isUploadingAvatar
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.photo_camera, size: 18),
                            ),
                          ),
                        ],
                      ),
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

class _GroupsResultSection extends StatelessWidget {
  const _GroupsResultSection({required this.groups, this.showHeader = true});

  final List<CampusGroup> groups;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return _ResultGroup(
      title: '社群',
      showHeader: showHeader,
      emptyLabel: '暂无匹配社群',
      isEmpty: groups.isEmpty,
      child: CampusCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < groups.take(3).length; i++) ...[
              _LargeGroupResultTile(group: groups[i]),
              if (i != groups.take(3).length - 1) const Divider(height: 1),
            ],
          ],
        ),
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

class _LargeUserResultTile extends StatefulWidget {
  const _LargeUserResultTile({required this.user});

  final CampusUser user;

  @override
  State<_LargeUserResultTile> createState() => _LargeUserResultTileState();
}

class _LargeUserResultTileState extends State<_LargeUserResultTile> {
  late CampusUser _user = widget.user;
  var _isSubmitting = false;

  Future<void> _toggleFollow() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final nextUser = _user.followedByMe
          ? await CampusRepository.instance.unfollowUser(_user)
          : await CampusRepository.instance.followUser(_user);
      if (!mounted) return;
      setState(() => _user = nextUser);
      _showMessage(
        context,
        nextUser.followedByMe ? '已关注 ${nextUser.name}' : '已取消关注',
      );
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
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
            onPressed: _isSubmitting ? null : _toggleFollow,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue,
              side: const BorderSide(color: AppColors.blue),
              minimumSize: const Size(82, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: Text(
              _isSubmitting
                  ? '处理中'
                  : user.followedByMe
                  ? '已关注'
                  : '关注',
            ),
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
            builder: (_) => ActivityEnrollmentDetailScreen(
              activity: activity,
              initialRegistered:
                  activity.activityStatus.isNotEmpty ||
                  activity.isCheckInNotStarted ||
                  activity.isCheckInAvailable ||
                  activity.isCheckedIn ||
                  activity.isEnded,
              initialFavorite: activity.isFavorited,
            ),
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
                    const Pill(label: '立即报名', color: AppColors.green),
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

class _LargeGroupResultTile extends StatelessWidget {
  const _LargeGroupResultTile({required this.group});

  final CampusGroup group;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SmartImage(url: group.iconUrl, width: 48, height: 48),
      ),
      title: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${group.members}人 · ${group.tags.take(2).join(' / ')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
        );
      },
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
    required this.createdAt,
  }) : reply = null;

  final CampusUser user;
  final String text;
  final int likes;
  final String createdAt;
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
                Text(
                  '${_detailFriendlyTime(createdAt)}    回复',
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
      trailing: const OutlinedButton(onPressed: null, child: Text('已报名')),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityEnrollmentDetailScreen(
              activity: activity,
              initialRegistered:
                  activity.activityStatus.isNotEmpty ||
                  activity.isCheckInNotStarted ||
                  activity.isCheckInAvailable ||
                  activity.isCheckedIn ||
                  activity.isEnded,
              initialFavorite: activity.isFavorited,
            ),
          ),
        );
      },
    );
  }
}

class _GroupAnnouncementCard extends StatelessWidget {
  const _GroupAnnouncementCard({
    required this.text,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String text;
  final String updatedAt;
  final CampusUser? updatedBy;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, color: AppColors.orange),
              const SizedBox(width: 8),
              const Text(
                '群公告',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
          if (updatedAt.isNotEmpty || updatedBy != null) ...[
            const SizedBox(height: 12),
            Text(
              [
                if (updatedBy != null) updatedBy!.name,
                if (updatedAt.isNotEmpty) _formatGroupMetaTime(updatedAt),
              ].join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
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
      title: Row(
        children: [
          Expanded(child: Text(post.title)),
          if (post.pinnedInGroup)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Pill(label: '置顶', color: AppColors.red),
            ),
        ],
      ),
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

String _formatGroupMetaTime(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
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
