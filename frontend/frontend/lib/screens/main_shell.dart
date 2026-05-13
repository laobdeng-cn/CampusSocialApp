import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../data/sample_data.dart';
import '../models/campus_feed.dart';
import '../models/campus_models.dart';
import '../repositories/auth_session.dart';
import '../repositories/campus_repository.dart';
import '../repositories/campus_event_bus.dart';
import '../theme/app_theme.dart';
import '../widgets/campus_widgets.dart';
import 'activity_feature_pages.dart';
import 'auth_screens.dart';
import 'detail_pages.dart';

List<CampusPost> _visibleRealHomePosts(Iterable<CampusPost> posts) {
  const demoTitles = <String>{
    '校园日落拍摄地推荐',
    '新图书馆自习位怎么预约？求攻略！',
    '高效复习时间表分享，亲测有效！',
    '各科目复习资料大合集（持续更新）',
    '图书馆自习打卡',
    '食堂新品测评｜芝士焗饭绝了！',
  };

  const demoAuthors = <String>{'林小北', '陈可欣', '王子豪', '刘思雨', '张晓晨'};

  final seen = <String>{};
  final result = <CampusPost>[];

  for (final post in posts) {
    final id = post.id.trim();
    if (id.isEmpty) continue;

    if (demoTitles.contains(post.title.trim())) continue;
    if (demoAuthors.contains(post.author.name.trim())) continue;

    if (seen.add(id)) result.add(post);
  }

  result.sort((left, right) {
    final leftTime = DateTime.tryParse(left.createdAt);
    final rightTime = DateTime.tryParse(right.createdAt);
    if (leftTime != null && rightTime != null) {
      return rightTime.compareTo(leftTime);
    }
    return 0;
  });

  return result;
}

List<CampusUser> _visibleRealHomeUsers(Iterable<CampusUser> users) {
  const demoNames = <String>{'林小北', '陈可欣', '王子豪', '刘思雨', '张晓晨'};

  final currentUserId = AuthSession.user?.id.trim() ?? '';
  final seen = <String>{};
  final result = <CampusUser>[];

  for (final user in users) {
    final id = user.id.trim();
    final name = user.name.trim();

    if (id.isEmpty) continue;
    if (currentUserId.isNotEmpty && id == currentUserId) continue;
    if (demoNames.contains(name)) continue;

    final key = id.isNotEmpty ? id : name;
    if (seen.add(key)) result.add(user);
  }

  return result;
}

List<CampusPost> _realCampusPosts(Iterable<CampusPost> posts) {
  return posts
      .where((post) => post.id.trim().isNotEmpty)
      .toList(growable: false);
}

void _showShellMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _shellError(Object error) {
  final text = error.toString();
  const marker = 'CampusApiException: ';
  if (text.startsWith(marker)) return text.substring(marker.length);
  return '操作失败，请确认后端服务已启动';
}

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

class CampusShell extends StatefulWidget {
  const CampusShell({super.key});

  @override
  State<CampusShell> createState() => _CampusShellState();
}

class _CampusShellState extends State<CampusShell> {
  StreamSubscription<CampusDataEvent>? _homeRefreshSubscription;

  int _currentIndex = 0;
  CampusFeed _feed = CampusRepository.instance.cachedFeed;
  bool _isRefreshing = false;
  StreamSubscription<CampusDataEvent>? _feedSubscription;

  void _bindHomeRealtimeRefresh() {
    // 不在事件总线上再次发起网络刷新。
    // createPost/deletePost/updatePost 已经会更新 cachedFeed，
    // _feedSubscription 只需要把 cachedFeed 同步到页面即可。
    // 这样可以避免 fetchMyPosts / fetchFeed 之间互相触发导致页面一直转圈、卡顿。
  }

  @override
  void initState() {
    super.initState();
    _bindHomeRealtimeRefresh();
    campusTabIndexNotifier.addListener(_syncExternalTabIndex);
    _refreshFeed();
    _feedSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.groupChanged ||
          event.type == CampusEventType.activityChanged) {
        setState(() {
          _feed = CampusRepository.instance.cachedFeed;
        });
      }
    });
  }

  @override
  void dispose() {
    campusTabIndexNotifier.removeListener(_syncExternalTabIndex);
    _feedSubscription?.cancel();
    _homeRefreshSubscription?.cancel();
    super.dispose();
  }

  void _selectTab(int index) {
    if (campusTabIndexNotifier.value != index) {
      campusTabIndexNotifier.value = index;
      return;
    }
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  void _syncExternalTabIndex() {
    if (!mounted) return;
    final index = campusTabIndexNotifier.value;
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

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
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<TabSwitchNotification>(
      onNotification: (notification) {
        _selectTab(notification.index);
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(
              feed: _feed,
              onRefresh: _refreshFeed,
              isRefreshing: _isRefreshing,
            ),
            ActivitiesScreen(feed: _feed, onRefresh: _refreshFeed),
            const MessageCenterScreen(),
            CommunityScreen(feed: _feed, onRefresh: _refreshFeed),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: BottomTabs(
          currentIndex: _currentIndex,
          onTap: _selectTab,
        ),
      ),
    );
  }
}

class _FriendRecommendationSection extends StatefulWidget {
  const _FriendRecommendationSection({required this.users});

  final List<CampusUser> users;

  @override
  State<_FriendRecommendationSection> createState() =>
      _FriendRecommendationSectionState();
}

class _FriendRecommendationSectionState
    extends State<_FriendRecommendationSection> {
  int _offset = 0;

  List<CampusUser> get _visibleUsers {
    final users = widget.users;
    if (users.length <= 3) return users;

    return List<CampusUser>.generate(3, (index) {
      return users[(_offset + index) % users.length];
    });
  }

  void _refreshRecommendations() {
    if (widget.users.length <= 3) return;
    setState(() {
      _offset = (_offset + 3) % widget.users.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleUsers = _visibleUsers;

    return Column(
      children: [
        SectionTitle(
          title: '你可能认识的人',
          action: TextButton(
            onPressed: widget.users.length <= 3
                ? null
                : _refreshRecommendations,
            child: const Text(
              '换一换',
              style: TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 172,
          child: ListView.separated(
            padding: kPagePadding,
            scrollDirection: Axis.horizontal,
            itemCount: visibleUsers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final user = visibleUsers[index];
              return SizedBox(width: 112, child: _FriendCard(user: user));
            },
          ),
        ),
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.feed,
    required this.onRefresh,
    super.key,
    this.isRefreshing = false,
  });

  final CampusFeed feed;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthSession.user;
    final currentName = currentUser == null || currentUser.name.trim().isEmpty
        ? '同学'
        : currentUser.name.trim();
    final users = _visibleRealHomeUsers(feed.users);
    final posts = _visibleRealHomePosts(feed.posts);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 92),
            children: [
              if (isRefreshing) const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '早上好，$currentName',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '今天也是元气满满的一天',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        const TabSwitchNotification(2).dispatch(context);
                      },
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: kPagePadding,
                child: SearchField(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
              ),
              const SectionTitle(title: '活跃同学'),
              SizedBox(
                height: 94,
                child: ListView.separated(
                  padding: kPagePadding,
                  scrollDirection: Axis.horizontal,
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _StoryItem(user: users[index]);
                  },
                ),
              ),
              _FriendRecommendationSection(users: users),
              const SectionTitle(title: '校园动态'),
              Padding(
                padding: kPagePadding,
                child: Column(
                  children: [
                    if (posts.isEmpty)
                      CampusCard(
                        padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              color: AppColors.muted,
                              size: 42,
                            ),
                            SizedBox(height: 10),
                            Text(
                              '暂无真实校园动态',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '发布一条帖子后，会自动显示在这里',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final post in posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: PostFeedCard(post: post),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const PublishPostScreen()),
            );
            if (created == true) {
              await onRefresh();
            }
          },
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 8,
          highlightElevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 34),
        ),
      ),
    );
  }
}

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({
    required this.feed,
    required this.onRefresh,
    super.key,
  });

  final CampusFeed feed;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leadingWidth: 92,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: Material(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActivityCheckInScreen(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        color: AppColors.blue,
                        size: 17,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '签到',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        title: const Text('活动'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
              icon: const Icon(Icons.search_rounded, size: 30),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 6),
            _ActivityFilteredSection(feed: feed, onRefresh: onRefresh),
          ],
        ),
      ),
    );
  }
}

const _activityCategories = ['推荐', '社团招新', '讲座', '体育', '文艺', '志愿'];

const _activityShortcuts = [
  _ActivityShortcut(
    icon: Icons.grid_view_rounded,
    label: '全部活动',
    color: AppColors.blue,
    destination: _ActivityShortcutDestination.all,
  ),
  _ActivityShortcut(
    icon: Icons.fact_check_outlined,
    label: '我报名的',
    color: AppColors.green,
    destination: _ActivityShortcutDestination.registered,
  ),
  _ActivityShortcut(
    icon: Icons.groups_2_outlined,
    label: '已签到',
    color: AppColors.orange,
    destination: _ActivityShortcutDestination.participated,
  ),
  _ActivityShortcut(
    icon: Icons.star_border_rounded,
    label: '我的收藏',
    color: Color(0xFFFFB000),
    destination: _ActivityShortcutDestination.favorites,
  ),
  _ActivityShortcut(
    icon: Icons.calendar_month_outlined,
    label: '活动日历',
    color: AppColors.purple,
    destination: _ActivityShortcutDestination.calendar,
  ),
  _ActivityShortcut(
    icon: Icons.event_available_outlined,
    label: '活动签到',
    color: AppColors.blue,
    destination: _ActivityShortcutDestination.checkIn,
  ),
  _ActivityShortcut(
    icon: Icons.notifications_none_rounded,
    label: '活动通知',
    color: AppColors.red,
    destination: _ActivityShortcutDestination.notifications,
  ),
  _ActivityShortcut(
    icon: Icons.manage_accounts_rounded,
    label: '我发起的',
    color: AppColors.green,
    destination: _ActivityShortcutDestination.created,
  ),
];

enum _ActivityShortcutDestination {
  all,
  registered,
  participated,
  favorites,
  calendar,
  checkIn,
  notifications,
  created,
  create,
}

class _ActivityFilteredSection extends StatefulWidget {
  const _ActivityFilteredSection({required this.feed, required this.onRefresh});

  final CampusFeed feed;
  final Future<void> Function() onRefresh;

  @override
  State<_ActivityFilteredSection> createState() =>
      _ActivityFilteredSectionState();
}

class _ActivityFilteredSectionState extends State<_ActivityFilteredSection> {
  String _selectedCategory = '推荐';

  List<CampusActivity> get _filteredActivities {
    if (_selectedCategory == '推荐') return widget.feed.activities;

    return widget.feed.activities
        .where((activity) {
          final text = [
            activity.category,
            activity.title,
            activity.host,
            activity.description,
          ].join(' ');

          if (_selectedCategory == '社团招新') {
            return text.contains('社团') || text.contains('招新');
          }

          return text.contains(_selectedCategory);
        })
        .toList(growable: false);
  }

  void _selectCategory(String category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
  }

  @override
  Widget build(BuildContext context) {
    final activities = _filteredActivities;

    return Column(
      children: [
        _ActivityCategoryBar(
          selectedCategory: _selectedCategory,
          onSelected: _selectCategory,
        ),
        const SizedBox(height: 14),
        const _ActivityRecruitBanner(),
        const SizedBox(height: 14),
        _ActivityShortcutGrid(onReturn: widget.onRefresh),
        const SizedBox(height: 14),
        _HotActivitiesPanel(
          activities: activities,
          onChanged: widget.onRefresh,
          emptyMessage: _selectedCategory == '推荐'
              ? '暂无热门活动'
              : '暂无$_selectedCategory活动',
        ),
      ],
    );
  }
}

class _ActivityCategoryBar extends StatelessWidget {
  const _ActivityCategoryBar({
    required this.selectedCategory,
    required this.onSelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          if (index == _activityCategories.length) {
            return _ActivityCategoryChip(
              label: '更多',
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActivityCategoriesScreen(),
                  ),
                );
              },
            );
          }

          final category = _activityCategories[index];
          return _ActivityCategoryChip(
            label: category,
            selected: category == selectedCategory,
            onTap: () => onSelected(category),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemCount: _activityCategories.length + 1,
      ),
    );
  }
}

class _ActivityCategoryChip extends StatelessWidget {
  const _ActivityCategoryChip({
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.blue : const Color(0xFFF0F3F8);
    final foreground = selected ? Colors.white : const Color(0xFF818A99);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 2),
                Icon(icon, color: foreground, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRecruitBanner extends StatelessWidget {
  const _ActivityRecruitBanner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 793 / 230,
        child: SmartImage(
          url: 'asset:assets/images/activity_recruit_banner.png',
          borderRadius: 14,
        ),
      ),
    );
  }
}

class _ActivityShortcutGrid extends StatelessWidget {
  const _ActivityShortcutGrid({this.onReturn});

  final Future<void> Function()? onReturn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                for (final item in _activityShortcuts.take(4))
                  Expanded(
                    child: _ActivityShortcutTile(
                      item: item,
                      onReturn: onReturn,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final item in _activityShortcuts.skip(4))
                  Expanded(
                    child: _ActivityShortcutTile(
                      item: item,
                      onReturn: onReturn,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityShortcut {
  const _ActivityShortcut({
    required this.icon,
    required this.label,
    required this.color,
    required this.destination,
  });

  final IconData icon;
  final String label;
  final Color color;
  final _ActivityShortcutDestination destination;
}

class _ActivityShortcutTile extends StatelessWidget {
  const _ActivityShortcutTile({required this.item, this.onReturn});

  final _ActivityShortcut item;
  final Future<void> Function()? onReturn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _shortcutDestinationPage(item.destination),
            ),
          );
          await onReturn?.call();
        },
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.icon, color: item.color, size: 28),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _shortcutDestinationPage(_ActivityShortcutDestination destination) {
  switch (destination) {
    case _ActivityShortcutDestination.all:
      return const ActivityAllScreen();
    case _ActivityShortcutDestination.registered:
      return const MyRegisteredActivitiesScreen();
    case _ActivityShortcutDestination.participated:
      return const CheckInRecordsScreen();
    case _ActivityShortcutDestination.favorites:
      return const FavoriteActivitiesScreen();
    case _ActivityShortcutDestination.calendar:
      return const ActivityCalendarScreen();
    case _ActivityShortcutDestination.checkIn:
      return const ActivityCheckInScreen();
    case _ActivityShortcutDestination.notifications:
      return const ActivityNotificationsScreen();
    case _ActivityShortcutDestination.created:
      return const MyCreatedActivitiesScreen();
    case _ActivityShortcutDestination.create:
      return const CreateActivityScreen();
  }
}

class _HotActivitiesPanel extends StatelessWidget {
  const _HotActivitiesPanel({
    required this.activities,
    required this.onChanged,
    this.emptyMessage = '暂无热门活动',
  });

  final List<CampusActivity> activities;
  final Future<void> Function() onChanged;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 16, 12),
              child: Row(
                children: [
                  Text(
                    '热门活动',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 19,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ActivityCategoriesScreen(),
                          ),
                        );
                        await onChanged();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '更多',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.muted,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (activities.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              for (var index = 0; index < activities.length; index++) ...[
                if (index > 0) const Divider(),
                ActivityListCard(
                  activity: activities[index],
                  onChanged: onChanged,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class ActivityListCard extends StatelessWidget {
  const ActivityListCard({
    required this.activity,
    required this.onChanged,
    super.key,
  });

  final CampusActivity activity;
  final Future<void> Function() onChanged;

  Future<void> _openDetail(BuildContext context) async {
    await Navigator.push(
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
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SmartImage(url: activity.posterUrl, width: 92, height: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activity.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        color: AppColors.muted,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${activity.enrolled}人已报名',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineInteractionButton extends StatelessWidget {
  const _InlineInteractionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.text,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, color: color, size: 21),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    required this.feed,
    required this.onRefresh,
    super.key,
  });

  final CampusFeed feed;
  final Future<void> Function() onRefresh;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  CampusDiscover? _discover;
  StreamSubscription<CampusDataEvent>? _communitySubscription;
  var _isLoadingDiscover = false;

  @override
  void initState() {
    super.initState();
    _loadDiscover();
    _communitySubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.groupChanged ||
          event.type == CampusEventType.feedChanged) {
        _loadDiscover();
      }
    });
  }

  @override
  void dispose() {
    _communitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDiscover() async {
    setState(() => _isLoadingDiscover = true);
    final discover = await CampusRepository.instance.fetchDiscover();
    if (!mounted) return;
    setState(() {
      _discover = discover;
      _isLoadingDiscover = false;
    });
  }

  Future<void> _refresh() async {
    await widget.onRefresh();
    await _loadDiscover();
  }

  CampusGroup _syncCommunityGroupState(CampusGroup group) {
    if (group.id.isEmpty) return group;

    for (final cached in CampusRepository.instance.cachedFeed.groups) {
      if (cached.id == group.id) {
        return cached;
      }
    }

    return group;
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    final discover = _discover ?? CampusDiscover.fromFeed(feed);
    final topics = discover.featuredTopics.isEmpty
        ? feed.topics
        : discover.featuredTopics;
    final groups = discover.recommendedGroups.isEmpty
        ? feed.groups
        : discover.recommendedGroups;
    final posts = _realCampusPosts(
      discover.trendingPosts.isEmpty ? feed.posts : discover.trendingPosts,
    );
    final topicNames = topics.isEmpty
        ? hotTopics
        : topics
              .map((topic) => topic.name)
              .followedBy(hotTopics)
              .toSet()
              .take(4)
              .toList(growable: false);
    final selectedTopic = topics.isEmpty ? campusTopic : topics.first;
    final recommendedGroups = groups.isEmpty
        ? [_syncCommunityGroupState(programmingGroup)]
        : groups.take(3).map(_syncCommunityGroupState).toList(growable: false);
    final discussionPosts = posts.take(3).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('社区'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: '我管理的社群',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyManagedGroupsScreen(),
                ),
              );
              if (changed == true) {
                await _refresh();
              }
            },
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 92),
          children: [
            if (_isLoadingDiscover) const LinearProgressIndicator(minHeight: 2),
            const SectionTitle(
              title: '热门话题',
              padding: EdgeInsets.fromLTRB(18, 4, 18, 12),
            ),
            Padding(
              padding: kPagePadding,
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.45,
                children: [
                  for (var i = 0; i < topicNames.length; i++)
                    _TopicTile(
                      title: topicNames[i],
                      discussions: [
                        selectedTopic.discussions,
                        '2.7万讨论',
                        '2.1万讨论',
                        '1.8万讨论',
                      ][i],
                      color: [
                        AppColors.blue,
                        AppColors.red,
                        AppColors.green,
                        AppColors.orange,
                      ][i],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TopicDetailScreen(topic: selectedTopic),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SectionTitle(
              title: '热门讨论',
              icon: Icons.local_fire_department,
              action: Text('全部', style: TextStyle(color: AppColors.muted)),
            ),
            Padding(
              padding: kPagePadding,
              child: Column(
                children: [
                  for (final post in discussionPosts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DiscussionCard(post: post),
                    ),
                ],
              ),
            ),
            const SectionTitle(
              title: '推荐群组',
              action: Text('全部', style: TextStyle(color: AppColors.muted)),
            ),
            Padding(
              padding: kPagePadding,
              child: CampusCard(
                child: Column(
                  children: [
                    for (var i = 0; i < recommendedGroups.length; i++) ...[
                      _GroupTile(
                        group: recommendedGroups[i],
                        name: recommendedGroups[i].name,
                        subtitle:
                            '${recommendedGroups[i].members}人 · ${recommendedGroups[i].tags.take(2).join(' / ')}',
                        imageUser: feed.users.length > i
                            ? feed.users[i]
                            : xiaobei,
                      ),
                      if (i != recommendedGroups.length - 1) const Divider(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MessageCategory { all, interaction, private, notice }

class MessageCenterScreen extends StatefulWidget {
  const MessageCenterScreen({super.key});

  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  var _selectedCategory = _MessageCategory.all;

  Future<void> _markAllRead() async {
    try {
      await CampusRepository.instance.markNotificationsRead();
      if (mounted) {
        _showShellMessage(context, '已全部标记为已读');
        setState(() {});
      }
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MessageCenterHeader(onReadAll: _markAllRead),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _MessageFilterTabs(
                selectedCategory: _selectedCategory,
                onChanged: (category) {
                  setState(() => _selectedCategory = category);
                },
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _MessageList(
                  key: ValueKey(_selectedCategory),
                  category: _selectedCategory,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCenterHeader extends StatelessWidget {
  const _MessageCenterHeader({required this.onReadAll});

  final VoidCallback onReadAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Center(
            child: Text(
              '消息中心',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: TextButton(
              onPressed: onReadAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.blue,
                padding: EdgeInsets.zero,
                minimumSize: const Size(76, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '全部已读',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageFilterTabs extends StatelessWidget {
  const _MessageFilterTabs({
    required this.selectedCategory,
    required this.onChanged,
  });

  final _MessageCategory selectedCategory;
  final ValueChanged<_MessageCategory> onChanged;

  static const _tabs = [
    (label: '全部', category: _MessageCategory.all),
    (label: '互动', category: _MessageCategory.interaction),
    (label: '私信', category: _MessageCategory.private),
    (label: '通知', category: _MessageCategory.notice),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (final tab in _tabs)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(tab.category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedCategory == tab.category
                        ? AppColors.blue.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      color: selectedCategory == tab.category
                          ? AppColors.blue
                          : AppColors.muted,
                      fontSize: 16,
                      fontWeight: selectedCategory == tab.category
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.category, super.key});

  final _MessageCategory category;

  @override
  Widget build(BuildContext context) {
    if (category == _MessageCategory.private) {
      return const _PrivateMessageList();
    }
    if (category == _MessageCategory.notice) {
      return const _NoticeMessageList();
    }

    final remoteCategory = category == _MessageCategory.interaction
        ? 'interaction'
        : null;
    final fallbackMessages = category == _MessageCategory.interaction
        ? _interactionMessageEntries
        : _allMessageEntries;
    final hintLabel = category == _MessageCategory.interaction
        ? '只看互动消息'
        : '已加载全部消息';

    return FutureBuilder<List<CampusNotificationRecord>>(
      future: CampusRepository.instance.fetchNotifications(
        category: remoteCategory,
      ),
      builder: (context, snapshot) {
        final remoteMessages =
            (snapshot.data ?? const <CampusNotificationRecord>[])
                .map(_MessageEntry.fromNotification)
                .toList(growable: false);
        final messages = remoteMessages.isEmpty
            ? fallbackMessages
            : remoteMessages;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return _MessageLoadedHint(label: hintLabel);
            }
            return _MessageCard(entry: messages[index]);
          },
          separatorBuilder: (_, index) =>
              SizedBox(height: index == messages.length - 1 ? 22 : 12),
          itemCount: messages.length + 1,
        );
      },
    );
  }
}

const _allMessageEntries = <_MessageEntry>[];
const _interactionMessageEntries = <_MessageEntry>[];

class _MessageEntry {
  const _MessageEntry({
    required this.title,
    required this.time,
    required this.firstLine,
    required this.badgeIcon,
    required this.badgeColor,
    this.id = '',
    this.user,
    this.secondLine,
    this.systemIcon,
    this.systemColor,
    this.unread = false,
  });

  factory _MessageEntry.fromNotification(CampusNotificationRecord record) {
    final actor = record.actor;
    return _MessageEntry(
      id: record.id,
      user: actor,
      title: actor?.name ?? record.title,
      time: record.createdAt,
      firstLine: record.firstLine,
      secondLine: record.secondLine.isEmpty ? null : record.secondLine,
      systemIcon: actor == null ? _noticeIconFor(record.action) : null,
      systemColor: actor == null ? _noticeColorFor(record.action) : null,
      badgeIcon: _messageBadgeIconFor(record.action),
      badgeColor: _messageBadgeColorFor(record.action),
      unread: record.unread,
    );
  }

  final CampusUser? user;
  final String id;
  final String title;
  final String time;
  final String firstLine;
  final String? secondLine;
  final IconData? systemIcon;
  final Color? systemColor;
  final IconData badgeIcon;
  final Color badgeColor;
  final bool unread;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.entry});

  final _MessageEntry entry;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      onTap: () {
        if (entry.id.isNotEmpty && entry.unread) {
          CampusRepository.instance.markNotificationRead(entry.id).ignore();
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => entry.user == null
                ? _MessageNoticeDetailScreen(entry: _noticeEntries.first)
                : _InteractionDetailScreen(entry: entry),
          ),
        );
      },
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MessageAvatar(entry: entry),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.time,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.firstLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      if (entry.secondLine != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          entry.secondLine!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: entry.unread ? 9 : 0),
            ],
          ),
          if (entry.unread)
            Positioned(right: 0, top: 50, child: _UnreadDot(size: 8)),
        ],
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.entry});

  final _MessageEntry entry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: entry.user == null
                ? Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          entry.systemColor ?? AppColors.blue,
                          (entry.systemColor ?? AppColors.blueDark).withValues(
                            alpha: 0.82,
                          ),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      entry.systemIcon ?? Icons.notifications_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  )
                : CampusAvatar(user: entry.user!, size: 60),
          ),
          Positioned(
            right: 0,
            bottom: 6,
            child: Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: entry.badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(entry.badgeIcon, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateMessageList extends StatefulWidget {
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
      setState(() {
        _future = next;
      });
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
            itemBuilder: (context, index) =>
                _PrivateMessageCard(entry: entries[index], onReturn: _refresh),
            separatorBuilder: (_, _) => const SizedBox(height: 0),
          ),
        );
      },
    );
  }
}

class _PrivateEmptyStateCard extends StatelessWidget {
  const _PrivateEmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 104),
      children: [
        CampusCard(
          padding: const EdgeInsets.fromLTRB(18, 34, 18, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.muted, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivateChatEntry {
  const _PrivateChatEntry({
    required this.user,
    required this.message,
    required this.time,
    this.conversationId = '',
    this.unreadCount = 0,
    this.online = false,
  }) : name = null,
       pinned = false;

  factory _PrivateChatEntry.fromConversation(CampusConversation conversation) {
    return _PrivateChatEntry(
      conversationId: conversation.id,
      user: conversation.contact,
      message: conversation.lastMessage,
      time: _friendlyTime(conversation.updatedAt),
      unreadCount: conversation.unreadCount,
      online: true,
    );
  }

  final CampusUser user;
  final String conversationId;
  final String? name;
  final String message;
  final String time;
  final int unreadCount;
  final bool pinned;
  final bool online;
}

class _PrivateMessageCard extends StatelessWidget {
  const _PrivateMessageCard({required this.entry, this.onReturn});

  final _PrivateChatEntry entry;
  final Future<void> Function()? onReturn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
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
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _PrivateChatAvatar(user: entry.user, online: entry.online),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.name ?? entry.user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (entry.pinned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text(
                              '置顶',
                              style: TextStyle(
                                color: AppColors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      entry.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.time,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (entry.unreadCount > 0)
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${entry.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 26),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateChatAvatar extends StatelessWidget {
  const _PrivateChatAvatar({required this.user, required this.online});

  final CampusUser user;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CampusAvatar(user: user, size: 60),
          if (online)
            Positioned(
              right: 3,
              bottom: 3,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.contact,
    required this.displayName,
    required this.online,
    super.key,
    this.conversationId = '',
  });

  final CampusUser contact;
  final String displayName;
  final bool online;
  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  Timer? _pollingTimer;
  DateTime? _recordingStartedAt;
  String? _playingAudioUrl;
  List<CampusChatMessage> _messages = const [];
  late String _conversationId;
  var _isLoading = false;
  var _isSending = false;
  var _isRecording = false;
  var _showEmojiPanel = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _messageFocusNode.addListener(_handleMessageFocusChange);
    _loadMessages();
    _startPollingMessages();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageFocusNode.removeListener(_handleMessageFocusChange);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startPollingMessages() {
    _pollingTimer?.cancel();

    if (_conversationId.isEmpty) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshMessagesSilently();
    });
  }

  bool _isSameMessageList(
    List<CampusChatMessage> left,
    List<CampusChatMessage> right,
  ) {
    if (left.length != right.length) return false;
    if (left.isEmpty && right.isEmpty) return true;

    return left.last.id == right.last.id &&
        left.last.text == right.last.text &&
        left.last.imageUrl == right.last.imageUrl &&
        left.last.audioUrl == right.last.audioUrl;
  }

  Future<void> _refreshMessagesSilently() async {
    if (_conversationId.isEmpty || _isLoading || _isSending) return;

    try {
      final repo = CampusRepository.instance;
      final messages = await repo.fetchConversationMessages(_conversationId);
      await repo.markConversationRead(_conversationId);

      if (!mounted || _isSameMessageList(_messages, messages)) return;

      setState(() => _messages = messages);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      // 轮询失败不打扰用户，避免网络波动时反复弹错误。
    }
  }

  void _handleMessageFocusChange() {
    if (_messageFocusNode.hasFocus && _showEmojiPanel && mounted) {
      setState(() {
        _showEmojiPanel = false;
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _toggleEmojiPanel() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmojiPanel = !_showEmojiPanel;
    });
  }

  void _insertEmoji(String sticker) {
    final oldValue = _messageController.value;
    final oldText = oldValue.text;
    final selection = oldValue.selection;

    final start = selection.start < 0 ? oldText.length : selection.start;
    final end = selection.end < 0 ? oldText.length : selection.end;

    final nextText = oldText.replaceRange(start, end, sticker);
    _messageController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + sticker.length),
    );
  }

  Future<void> _loadMessages() async {
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureConversation() async {
    if (_conversationId.isNotEmpty) return;
    final conversation = await CampusRepository.instance.startConversation(
      widget.contact,
    );
    _conversationId = conversation.id;
    _startPollingMessages();
  }

  Future<void> _startVoiceRecording() async {
    if (_isSending || _isRecording) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) _showShellMessage(context, '请允许麦克风权限后再发送语音');
        return;
      }

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingStartedAt = DateTime.now();
      });
      _showShellMessage(context, '正在录音，松开发送');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    }
  }

  Future<void> _finishVoiceRecording() async {
    if (!_isRecording) return;

    final startedAt = _recordingStartedAt;
    setState(() {
      _isRecording = false;
      _recordingStartedAt = null;
    });

    try {
      final filePath = await _audioRecorder.stop();
      if (filePath == null || filePath.isEmpty) return;

      final duration = startedAt == null
          ? 1
          : DateTime.now().difference(startedAt).inSeconds.clamp(1, 60).toInt();

      setState(() => _isSending = true);
      await _ensureConversation();

      final audioUrl = await CampusRepository.instance.uploadAudio(
        filePath,
        purpose: 'chat',
      );

      final message = await CampusRepository.instance.sendConversationMessage(
        conversationId: _conversationId,
        text: '[语音]',
        type: 'audio',
        audioUrl: audioUrl,
        duration: duration,
      );

      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _showEmojiPanel = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isRecording) return;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingStartedAt = null;
    });
    _showShellMessage(context, '已取消录音');
  }

  Future<void> _toggleAudioPlayback(CampusChatMessage message) async {
    if (message.audioUrl.isEmpty) return;

    try {
      if (_playingAudioUrl == message.audioUrl && _audioPlayer.playing) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingAudioUrl = null);
        return;
      }

      await _audioPlayer.stop();
      if (mounted) setState(() => _playingAudioUrl = message.audioUrl);
      await _audioPlayer.setUrl(message.audioUrl);
      await _audioPlayer.play();
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted && _playingAudioUrl == message.audioUrl) {
        setState(() => _playingAudioUrl = null);
      }
    }
  }

  Future<void> _sendImageMessage() async {
    if (_isSending) return;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      await _ensureConversation();
      final imageUrl = await CampusRepository.instance.uploadImage(
        picked.path,
        purpose: 'chat',
      );
      final message = await CampusRepository.instance.sendConversationMessage(
        conversationId: _conversationId,
        text: '[图片]',
        type: 'image',
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _showEmojiPanel = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _openContactProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(user: widget.contact),
      ),
    );
  }

  Future<bool> _confirmChatAction({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _clearConversationMessages() async {
    if (_isSending) return;

    if (_conversationId.isEmpty) {
      setState(() => _messages = const []);
      return;
    }

    final confirmed = await _confirmChatAction(
      title: '清空聊天记录',
      content: '确定清空和 ${widget.displayName} 的全部聊天记录吗？',
      confirmText: '清空',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSending = true);
    try {
      await CampusRepository.instance.clearConversationMessages(
        _conversationId,
      );
      if (!mounted) return;
      setState(() => _messages = const []);
      _showShellMessage(context, '聊天记录已清空');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteConversation() async {
    if (_isSending) return;

    final confirmed = await _confirmChatAction(
      title: '删除会话',
      content: '确定删除和 ${widget.displayName} 的会话吗？聊天记录也会一起删除。',
      confirmText: '删除',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSending = true);
    try {
      if (_conversationId.isNotEmpty) {
        await CampusRepository.instance.deleteConversation(_conversationId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      _showShellMessage(context, '会话已删除');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openChatOptions() async {
    FocusScope.of(context).unfocus();

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('查看资料'),
                onTap: () => Navigator.of(sheetContext).pop('profile'),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('清空聊天记录'),
                onTap: () => Navigator.of(sheetContext).pop('clear'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                textColor: AppColors.red,
                iconColor: AppColors.red,
                title: const Text('删除会话'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'profile':
        _openContactProfile();
        break;
      case 'clear':
        await _clearConversationMessages();
        break;
      case 'delete':
        await _deleteConversation();
        break;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _ensureConversation();
      final message = await CampusRepository.instance.sendConversationMessage(
        conversationId: _conversationId,
        text: text,
      );
      _messageController.clear();
      if (mounted) {
        setState(() {
          _messages = [..._messages, message];
          _showEmojiPanel = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        AuthSession.user ??
        const CampusUser(
          name: '我',
          school: '未知学院',
          major: '未填写专业',
          grade: '未填写年级',
          avatarUrl: 'https://i.pravatar.cc/180?img=1',
          bio: '',
        );

    final messageWidgets = _messages
        .map((message) {
          if (message.isImage) {
            return message.isMine
                ? _OutgoingImageChatBubble(
                    user: currentUser,
                    imageUrl: message.imageUrl,
                  )
                : _IncomingImageChatBubble(
                    user: widget.contact,
                    imageUrl: message.imageUrl,
                  );
          }

          if (message.isAudio) {
            return message.isMine
                ? _OutgoingAudioChatBubble(
                    user: currentUser,
                    message: message,
                    isPlaying: _playingAudioUrl == message.audioUrl,
                    onTap: () => _toggleAudioPlayback(message),
                  )
                : _IncomingAudioChatBubble(
                    user: widget.contact,
                    message: message,
                    isPlaying: _playingAudioUrl == message.audioUrl,
                    onTap: () => _toggleAudioPlayback(message),
                  );
          }

          return message.isMine
              ? _OutgoingChatBubble(
                  user: currentUser,
                  text: message.text,
                  sent: true,
                )
              : _IncomingChatBubble(user: widget.contact, text: message.text);
        })
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _ChatHeader(
            contact: widget.contact,
            displayName: widget.displayName,
            online: widget.online,
            onMoreTap: _openChatOptions,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    children: [
                      const _ChatTimeLabel(label: '最近消息'),
                      if (_messages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 120),
                          child: Column(
                            children: const [
                              Icon(
                                Icons.forum_outlined,
                                size: 48,
                                color: AppColors.muted,
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
                              SizedBox(height: 8),
                              Text(
                                '发送第一条消息后，会显示在这里',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...messageWidgets,
                    ],
                  ),
          ),
          if (_showEmojiPanel) _ChatEmojiPanel(onEmojiSelected: _insertEmoji),
          _ChatInputBar(
            controller: _messageController,
            focusNode: _messageFocusNode,
            isSending: _isSending,
            isRecording: _isRecording,
            onSend: _sendMessage,
            onEmojiTap: _toggleEmojiPanel,
            onImageTap: _sendImageMessage,
            onVoiceLongPressStart: _startVoiceRecording,
            onVoiceLongPressEnd: _finishVoiceRecording,
            onVoiceLongPressCancel: _cancelVoiceRecording,
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.contact,
    required this.displayName,
    required this.online,
    required this.onMoreTap,
  });

  final CampusUser contact;
  final String displayName;
  final bool online;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left_rounded, size: 36),
              ),
              const SizedBox(width: 4),
              _ChatHeaderAvatar(user: contact, online: online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: online ? AppColors.green : AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          online ? '在线' : '离线',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMoreTap,
                icon: const Icon(Icons.more_horiz_rounded, size: 30),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeaderAvatar extends StatelessWidget {
  const _ChatHeaderAvatar({required this.user, required this.online});

  final CampusUser user;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CampusAvatar(user: user, size: 48),
          if (online)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatTimeLabel extends StatelessWidget {
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

class _IncomingChatBubble extends StatelessWidget {
  const _IncomingChatBubble({required this.user, required this.text});

  final CampusUser user;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampusAvatar(user: user, size: 40),
          const SizedBox(width: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.66,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _StickerMessageText(text: text, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutgoingChatBubble extends StatelessWidget {
  const _OutgoingChatBubble({required this.text, this.user, this.sent = false});

  final CampusUser? user;
  final String text;
  final bool sent;

  CampusUser get _displayUser {
    return user ??
        AuthSession.user ??
        const CampusUser(
          name: '我',
          school: '未知学院',
          major: '未填写专业',
          grade: '未填写年级',
          avatarUrl: 'https://i.pravatar.cc/180?img=1',
          bio: '',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: sent ? 6 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.66,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF168BFF), AppColors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _StickerMessageText(text: text, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CampusAvatar(user: _displayUser, size: 40),
            ],
          ),
          if (sent) ...[
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(right: 50),
              child: Text(
                '已送达',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatStickerData {
  const _ChatStickerData({
    required this.token,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String token;
  final String label;
  final IconData icon;
  final Color color;
}

class _ChatStickerBook {
  static const stickers = <_ChatStickerData>[
    _ChatStickerData(
      token: '[微笑]',
      label: '微笑',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: Color(0xFF2F80ED),
    ),
    _ChatStickerData(
      token: '[大笑]',
      label: '大笑',
      icon: Icons.sentiment_very_satisfied_rounded,
      color: Color(0xFFFFA726),
    ),
    _ChatStickerData(
      token: '[难过]',
      label: '难过',
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFF6B7280),
    ),
    _ChatStickerData(
      token: '[哭泣]',
      label: '哭泣',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: Color(0xFF5B8DEF),
    ),
    _ChatStickerData(
      token: '[生气]',
      label: '生气',
      icon: Icons.mood_bad_rounded,
      color: Color(0xFFFF4D4F),
    ),
    _ChatStickerData(
      token: '[点赞]',
      label: '点赞',
      icon: Icons.thumb_up_alt_rounded,
      color: Color(0xFF1677FF),
    ),
    _ChatStickerData(
      token: '[爱心]',
      label: '爱心',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF4D6D),
    ),
    _ChatStickerData(
      token: '[星星]',
      label: '星星',
      icon: Icons.star_rounded,
      color: Color(0xFFFFA726),
    ),
    _ChatStickerData(
      token: '[鼓掌]',
      label: '鼓掌',
      icon: Icons.back_hand_rounded,
      color: Color(0xFF13C2C2),
    ),
    _ChatStickerData(
      token: '[抱拳]',
      label: '抱拳',
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFF7C4DFF),
    ),
    _ChatStickerData(
      token: '[加油]',
      label: '加油',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFF7A00),
    ),
    _ChatStickerData(
      token: '[收到]',
      label: '收到',
      icon: Icons.check_circle_rounded,
      color: Color(0xFF22C55E),
    ),
    _ChatStickerData(
      token: '[疑问]',
      label: '疑问',
      icon: Icons.help_outline_rounded,
      color: Color(0xFF64748B),
    ),
    _ChatStickerData(
      token: '[学习]',
      label: '学习',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF2F80ED),
    ),
    _ChatStickerData(
      token: '[拍照]',
      label: '拍照',
      icon: Icons.photo_camera_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _ChatStickerData(
      token: '[运动]',
      label: '运动',
      icon: Icons.sports_basketball_rounded,
      color: Color(0xFFEF4444),
    ),
    _ChatStickerData(
      token: '[游戏]',
      label: '游戏',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF6366F1),
    ),
    _ChatStickerData(
      token: '[干饭]',
      label: '干饭',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFF8A00),
    ),
    _ChatStickerData(
      token: '[咖啡]',
      label: '咖啡',
      icon: Icons.coffee_rounded,
      color: Color(0xFF8B5E3C),
    ),
    _ChatStickerData(
      token: '[晚安]',
      label: '晚安',
      icon: Icons.dark_mode_rounded,
      color: Color(0xFF475569),
    ),
  ];

  static _ChatStickerData? find(String token) {
    for (final sticker in stickers) {
      if (sticker.token == token) return sticker;
    }
    return null;
  }
}

class _StickerMessageText extends StatelessWidget {
  const _StickerMessageText({required this.text, required this.color})
    : fontSize = 15.5;

  final String text;
  final Color color;
  final double fontSize;

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\[[^\]]+\]');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: TextStyle(color: color, fontSize: fontSize, height: 1.55),
          ),
        );
      }

      final token = match.group(0) ?? '';
      final sticker = _ChatStickerBook.find(token);

      if (sticker == null) {
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(color: color, fontSize: fontSize, height: 1.55),
          ),
        );
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sticker.color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sticker.color.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(sticker.icon, size: 18, color: sticker.color),
              ),
            ),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: TextStyle(color: color, fontSize: fontSize, height: 1.55),
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(text: TextSpan(children: _buildSpans()));
  }
}

class _ChatEmojiPanel extends StatelessWidget {
  const _ChatEmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Text(
                    '表情包',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '点击插入',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                itemCount: _ChatStickerBook.stickers.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.98,
                ),
                itemBuilder: (context, index) {
                  final sticker = _ChatStickerBook.stickers[index];
                  return Material(
                    color: const Color(0xFFF5F8FC),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onEmojiSelected(sticker.token),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sticker.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              sticker.icon,
                              color: sticker.color,
                              size: 21,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sticker.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
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
      ),
    );
  }
}

class _OutgoingImageChatBubble extends StatelessWidget {
  const _OutgoingImageChatBubble({required this.user, required this.imageUrl});

  final CampusUser user;
  final String imageUrl;

  void _openPreview(BuildContext context) {
    if (imageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatImagePreviewScreen(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () => _openPreview(context),
              child: Hero(
                tag: 'chat-image-$imageUrl',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: imageUrl.isEmpty
                      ? Container(
                          width: 190,
                          height: 150,
                          alignment: Alignment.center,
                          color: const Color(0xFFEAF2FF),
                          child: const Text(
                            '图片地址为空',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : SmartImage(url: imageUrl, width: 190, height: 150),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CampusAvatar(user: user, size: 36),
        ],
      ),
    );
  }
}

class _IncomingImageChatBubble extends StatelessWidget {
  const _IncomingImageChatBubble({required this.user, required this.imageUrl});

  final CampusUser user;
  final String imageUrl;

  void _openPreview(BuildContext context) {
    if (imageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatImagePreviewScreen(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 72, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CampusAvatar(user: user, size: 36),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: () => _openPreview(context),
              child: Hero(
                tag: 'chat-image-$imageUrl',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: imageUrl.isEmpty
                      ? Container(
                          width: 190,
                          height: 150,
                          alignment: Alignment.center,
                          color: const Color(0xFFEAF2FF),
                          child: const Text(
                            '图片地址为空',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : SmartImage(url: imageUrl, width: 190, height: 150),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatImagePreviewScreen extends StatelessWidget {
  const _ChatImagePreviewScreen({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: const SizedBox.expand(),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: Hero(
                  tag: 'chat-image-$imageUrl',
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            '图片加载失败',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingAudioChatBubble extends StatelessWidget {
  const _OutgoingAudioChatBubble({
    required this.user,
    required this.message,
    required this.isPlaying,
    required this.onTap,
  });

  final CampusUser user;
  final CampusChatMessage message;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AudioBubble(
            duration: message.duration,
            isMine: true,
            isPlaying: isPlaying,
            onTap: onTap,
          ),
          const SizedBox(width: 8),
          CampusAvatar(user: user, size: 36),
        ],
      ),
    );
  }
}

class _IncomingAudioChatBubble extends StatelessWidget {
  const _IncomingAudioChatBubble({
    required this.user,
    required this.message,
    required this.isPlaying,
    required this.onTap,
  });

  final CampusUser user;
  final CampusChatMessage message;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 72, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CampusAvatar(user: user, size: 36),
          const SizedBox(width: 8),
          _AudioBubble(
            duration: message.duration,
            isMine: false,
            isPlaying: isPlaying,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _AudioBubble extends StatelessWidget {
  const _AudioBubble({
    required this.duration,
    required this.isMine,
    required this.isPlaying,
    required this.onTap,
  });

  final int duration;
  final bool isMine;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seconds = duration <= 0 ? 1 : duration;
    final width = (88 + seconds * 4).clamp(104, 210).toDouble();

    return Material(
      color: isMine ? AppColors.blue : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isMine ? AppColors.blue : AppColors.line),
          ),
          child: Row(
            children: [
              Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                color: isMine ? Colors.white : AppColors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPlaying ? '播放中' : '语音消息',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMine ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$seconds"',
                style: TextStyle(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onEmojiTap,
    required this.onImageTap,
    required this.onVoiceLongPressStart,
    required this.onVoiceLongPressEnd,
    required this.onVoiceLongPressCancel,
    required this.isSending,
    required this.isRecording,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onEmojiTap;
  final VoidCallback onImageTap;
  final VoidCallback onVoiceLongPressStart;
  final VoidCallback onVoiceLongPressEnd;
  final VoidCallback onVoiceLongPressCancel;
  final bool isSending;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          _ChatCircleButton(
            icon: isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
            isActive: isRecording,
            onTap: () => _showShellMessage(context, '按住麦克风录音，松开发送'),
            onLongPressStart: isSending ? null : onVoiceLongPressStart,
            onLongPressEnd: isSending ? null : onVoiceLongPressEnd,
            onLongPressCancel: isSending ? null : onVoiceLongPressCancel,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!isSending) onSend();
                      },
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: TextStyle(color: AppColors.muted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onEmojiTap,
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: AppColors.text,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    splashRadius: 20,
                  ),
                  IconButton(
                    onPressed: isSending ? null : onImageTap,
                    icon: const Icon(
                      Icons.image_outlined,
                      color: AppColors.text,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isSending ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(isSending ? '发送中' : '发送'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatCircleButton extends StatelessWidget {
  const _ChatCircleButton({
    required this.icon,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressCancel,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: onLongPressStart == null
          ? null
          : (_) => onLongPressStart?.call(),
      onLongPressEnd: onLongPressEnd == null
          ? null
          : (_) => onLongPressEnd?.call(),
      onLongPressCancel: onLongPressCancel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive ? AppColors.blue : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.blue : AppColors.line,
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : AppColors.text,
            size: 23,
          ),
        ),
      ),
    );
  }
}

class _NoticeMessageList extends StatelessWidget {
  const _NoticeMessageList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusNotificationRecord>>(
      future: CampusRepository.instance.fetchNotifications(category: 'notice'),
      builder: (context, snapshot) {
        final remoteEntries =
            (snapshot.data ?? const <CampusNotificationRecord>[])
                .map(_NoticeEntry.fromNotification)
                .toList(growable: false);
        final entries = remoteEntries.isEmpty ? _noticeEntries : remoteEntries;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          itemCount: entries.length + 1,
          itemBuilder: (context, index) {
            if (index == entries.length) {
              return const _MessageLoadedHint(label: '已加载全部通知');
            }
            return _NoticeMessageCard(entry: entries[index]);
          },
          separatorBuilder: (_, index) =>
              SizedBox(height: index == entries.length - 1 ? 18 : 12),
        );
      },
    );
  }
}

const _noticeEntries = [
  _NoticeEntry(
    title: '报名成功',
    time: '2分钟前',
    firstLine: '你已成功报名「校园歌手大赛」。',
    secondLine: '活动时间：5月25日 18:30，地点：大学生活动中心',
    icon: Icons.assignment_turned_in_rounded,
    color: AppColors.green,
    unread: true,
  ),
  _NoticeEntry(
    title: '活动提醒',
    time: '1小时前',
    firstLine: '「摄影入门工作坊」将于明天 14:00 开始，',
    secondLine: '请做好准备，期待你的参与！',
    icon: Icons.notifications_rounded,
    color: AppColors.blue,
    unread: true,
  ),
  _NoticeEntry(
    title: '审核通知',
    time: '3小时前',
    firstLine: '你发布的活动「旧书漂流计划」已通过审核，',
    secondLine: '现已正式上线，快去分享给更多同学吧！',
    icon: Icons.history_edu_rounded,
    color: AppColors.orange,
    unread: true,
  ),
  _NoticeEntry(
    title: '社区公告',
    time: '昨天 10:30',
    firstLine: '关于优化社区发帖规范的公告',
    secondLine: '请大家共同维护良好的社区氛围！',
    icon: Icons.campaign_rounded,
    color: AppColors.purple,
    unread: true,
  ),
  _NoticeEntry(
    title: '功能更新',
    time: '昨天 09:15',
    firstLine: '新版本已上线！支持活动日历订阅和消息分组管理，',
    secondLine: '快去体验吧！',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.blue,
  ),
  _NoticeEntry(
    title: '安全提醒',
    time: '2天前',
    firstLine: '为保障你的账号安全，建议开启登录保护功能，',
    secondLine: '守护你的校园社交体验。',
    icon: Icons.verified_user_rounded,
    color: Color(0xFF22C7B8),
  ),
  _NoticeEntry(
    title: '认证结果',
    time: '3天前',
    firstLine: '你的学生身份认证已通过，已解锁更多校园专属权益！',
    icon: Icons.how_to_reg_rounded,
    color: AppColors.orange,
  ),
];

class _NoticeEntry {
  const _NoticeEntry({
    required this.title,
    required this.time,
    required this.firstLine,
    required this.icon,
    required this.color,
    this.id = '',
    this.secondLine,
    this.unread = false,
  });

  factory _NoticeEntry.fromNotification(CampusNotificationRecord record) {
    return _NoticeEntry(
      id: record.id,
      title: record.title,
      time: record.createdAt,
      firstLine: record.firstLine,
      secondLine: record.secondLine.isEmpty ? null : record.secondLine,
      icon: _noticeIconFor(record.action),
      color: _noticeColorFor(record.action),
      unread: record.unread,
    );
  }

  final String title;
  final String id;
  final String time;
  final String firstLine;
  final String? secondLine;
  final IconData icon;
  final Color color;
  final bool unread;
}

class _NoticeMessageCard extends StatelessWidget {
  const _NoticeMessageCard({required this.entry});

  final _NoticeEntry entry;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      onTap: () {
        if (entry.id.isNotEmpty && entry.unread) {
          CampusRepository.instance.markNotificationRead(entry.id).ignore();
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _MessageNoticeDetailScreen(entry: entry),
          ),
        );
      },
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NoticeIcon(icon: entry.icon, color: entry.color),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.time,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.firstLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      if (entry.secondLine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.secondLine!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: entry.unread ? 9 : 0),
            ],
          ),
          if (entry.unread)
            Positioned(right: 0, top: 48, child: _UnreadDot(size: 8)),
        ],
      ),
    );
  }
}

class _NoticeIcon extends StatelessWidget {
  const _NoticeIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.72), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.blue,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MessageLoadedHint extends StatelessWidget {
  const _MessageLoadedHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 28, child: Divider(color: Color(0xFFC8D0DD))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
          const SizedBox(width: 28, child: Divider(color: Color(0xFFC8D0DD))),
        ],
      ),
    );
  }
}

IconData _messageBadgeIconFor(String action) {
  if (action.contains('like')) return Icons.favorite_rounded;
  if (action.contains('comment')) return Icons.more_horiz_rounded;
  if (action.contains('favorite')) return Icons.star_rounded;
  if (action.contains('follow')) return Icons.person_add_alt_1_rounded;
  if (action.contains('activity')) return Icons.check_rounded;
  return Icons.notifications_rounded;
}

Color _messageBadgeColorFor(String action) {
  if (action.contains('like')) return AppColors.red;
  if (action.contains('favorite')) return AppColors.orange;
  if (action.contains('activity')) return AppColors.green;
  return AppColors.blue;
}

IconData _noticeIconFor(String action) {
  if (action.contains('group_join')) return Icons.how_to_reg_rounded;
  if (action.contains('group_announcement')) return Icons.campaign_rounded;
  if (action.contains('group_activity')) return Icons.event_available_rounded;
  if (action.contains('group')) return Icons.groups_2_rounded;
  if (action.contains('activity')) return Icons.assignment_turned_in_rounded;
  if (action.contains('system')) return Icons.campaign_rounded;
  if (action.contains('verify')) return Icons.how_to_reg_rounded;
  return Icons.notifications_rounded;
}

Color _noticeColorFor(String action) {
  if (action.contains('group_join_rejected')) return AppColors.red;
  if (action.contains('group_join')) return AppColors.orange;
  if (action.contains('group_announcement')) return AppColors.purple;
  if (action.contains('group_activity')) return AppColors.green;
  if (action.contains('group')) return AppColors.blue;
  if (action.contains('activity')) return AppColors.green;
  if (action.contains('system')) return AppColors.purple;
  if (action.contains('verify')) return AppColors.orange;
  return AppColors.blue;
}

const _messageNoticeActivity = CampusActivity(
  title: '校园歌手大赛',
  category: '文艺演出',
  posterUrl: 'asset:assets/images/activity_music_thumb.png',
  date: '5月25日',
  time: '18:30',
  location: '大学生活动中心',
  host: '校学生会文艺部',
  enrolled: 218,
  capacity: 300,
  price: '免费',
  description: '面向全校同学开放的校园歌手舞台，欢迎热爱音乐的同学报名参赛或到场观演。',
  highlights: ['校园舞台', '专业评委', '现场互动'],
  guests: <CampusUser>[],
);

class _MessageNoticeDetailScreen extends StatelessWidget {
  const _MessageNoticeDetailScreen({required this.entry});

  final _NoticeEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('通知详情'),
        actions: [
          IconButton(
            onPressed: () => _showShellMessage(context, '更多操作正在完善中'),
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _NoticeDetailHero(entry: entry),
          const SizedBox(height: 16),
          const _NoticeInfoCard(),
          const SizedBox(height: 16),
          _DetailSectionCard(
            title: '通知内容',
            child: Text(
              _noticeDetailContent(entry),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _NoticeTipsCard(),
          const SizedBox(height: 22),
          _PrimaryActionButton(
            label: '查看活动',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityEnrollmentDetailScreen(
                    activity: _messageNoticeActivity,
                    initialRegistered:
                        _messageNoticeActivity.activityStatus.isNotEmpty ||
                        _messageNoticeActivity.isCheckInNotStarted ||
                        _messageNoticeActivity.isCheckInAvailable ||
                        _messageNoticeActivity.isCheckedIn ||
                        _messageNoticeActivity.isEnded,
                    initialFavorite: _messageNoticeActivity.isFavorited,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _OutlineActionButton(
            icon: Icons.calendar_month_outlined,
            label: '添加到日历',
            onTap: () => _showShellMessage(context, '该功能正在完善中'),
          ),
        ],
      ),
    );
  }
}

class _NoticeDetailHero extends StatelessWidget {
  const _NoticeDetailHero({required this.entry});

  final _NoticeEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            entry.color.withValues(alpha: 0.12),
            entry.color.withValues(alpha: 0.04),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: entry.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _NoticeIcon(icon: entry.icon, color: entry.color),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.firstLine.replaceAll('。', ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeInfoCard extends StatelessWidget {
  const _NoticeInfoCard();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (icon: Icons.event_note_outlined, label: '活动名称', value: '校园歌手大赛'),
      (icon: Icons.schedule_rounded, label: '活动时间', value: '5月25日  18:30'),
      (icon: Icons.location_on_outlined, label: '活动地点', value: '大学生活动中心'),
      (icon: Icons.tag_rounded, label: '报名编号', value: 'BM20260525018'),
      (icon: Icons.check_circle_outline_rounded, label: '状态', value: '已报名'),
    ];

    return _DetailSectionCard(
      title: '报名信息',
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _InfoRow(
              icon: rows[index].icon,
              label: rows[index].label,
              value: rows[index].value,
              valueColor: index == rows.length - 1 ? AppColors.green : null,
            ),
            if (index != rows.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _NoticeTipsCard extends StatelessWidget {
  const _NoticeTipsCard();

  @override
  Widget build(BuildContext context) {
    const tips = [
      '请提前15分钟到达活动现场，以便顺利签到。',
      '请携带校园卡，用于现场身份核验。',
      '如需取消报名，请在活动开始前通过活动页面操作。',
    ];

    return _DetailSectionCard(
      title: '温馨提示',
      titleIcon: Icons.tips_and_updates_outlined,
      titleIconColor: AppColors.blue,
      child: Column(
        children: [
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: _UnreadDot(size: 7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InteractionDetailScreen extends StatelessWidget {
  const _InteractionDetailScreen({required this.entry});

  final _MessageEntry entry;

  @override
  Widget build(BuildContext context) {
    final user = entry.user ?? kexin;
    const post = sunsetPost;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('互动详情'),
        actions: [
          IconButton(
            onPressed: () => _showShellMessage(context, '更多操作正在完善中'),
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          CampusCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                  child: Row(
                    children: [
                      CampusAvatar(user: user, size: 74),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Pill(
                              label: _interactionActionLabel(entry),
                              color: AppColors.blue,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.time,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.muted,
                        size: 30,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                  child: _InteractionPostPreview(entry: entry, post: post),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OriginalPostCard(post: post),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _PrimaryActionButton(
                  icon: Icons.reply_rounded,
                  label: '回复评论',
                  onTap: () => _showShellMessage(context, '该功能正在完善中'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OutlineActionButton(
                  icon: Icons.article_outlined,
                  label: '查看原帖',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PostDetailScreen(post: post),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractionPostPreview extends StatelessWidget {
  const _InteractionPostPreview({required this.entry, required this.post});

  final _MessageEntry entry;
  final CampusPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SmartImage(url: post.images.first, width: 96, height: 96),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      post.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entry.secondLine != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              entry.title,
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Pill(label: '评论', color: AppColors.blue),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.secondLine!,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OriginalPostCard extends StatelessWidget {
  const _OriginalPostCard({required this.post});

  final CampusPost post;

  @override
  Widget build(BuildContext context) {
    return _DetailSectionCard(
      title: '原帖内容',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.body,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InlineStat(icon: Icons.favorite_border_rounded, label: '点赞 128'),
              _InlineStat(icon: Icons.mode_comment_outlined, label: '评论 24'),
              _InlineStat(icon: Icons.star_border_rounded, label: '收藏 15'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({
    required this.title,
    required this.child,
    this.titleIcon,
    this.titleIconColor,
  });

  final String title;
  final Widget child;
  final IconData? titleIcon;
  final Color? titleIconColor;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Icon(titleIcon, color: titleIconColor ?? AppColors.blue),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 22),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 16),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 24),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.blue, width: 1.4),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.muted, size: 24),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _noticeDetailContent(_NoticeEntry entry) {
  if (entry.title == '报名成功') {
    return '你已成功报名本次活动，请准时到场签到，祝你活动愉快！';
  }
  return '${entry.firstLine}${entry.secondLine ?? ''}';
}

String _interactionActionLabel(_MessageEntry entry) {
  if (entry.firstLine.contains('评论')) return '评论了你的帖子';
  if (entry.firstLine.contains('点赞')) return '点赞了你的帖子';
  if (entry.firstLine.contains('收藏')) return '收藏了你的帖子';
  if (entry.firstLine.contains('关注')) return '关注了你';
  if (entry.firstLine.contains('@')) return '@ 了你';
  return '与你互动';
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  CampusUser get _user => AuthSession.user ?? xiaobei;

  StreamSubscription<CampusDataEvent>? _profileSubscription;
  var _isLoadingProfileCounters = false;
  var _hasLoadedProfileCounters = false;

  int? _followingCount;
  int? _followersCount;
  int? _likedCount;
  int? _activityCount;
  int? _favoritePostCount;
  int? _draftCount;
  int? _groupCount;

  String _countText(int? value) {
    if (value == null && _isLoadingProfileCounters) return '...';
    return '${value ?? 0}';
  }

  bool _shouldReloadProfileCounters(CampusDataEvent event) {
    return event.type == CampusEventType.feedChanged ||
        event.type == CampusEventType.postChanged ||
        event.type == CampusEventType.activityChanged ||
        event.type == CampusEventType.activityCommentChanged ||
        event.type == CampusEventType.groupChanged ||
        event.type == CampusEventType.profileChanged ||
        event.type == CampusEventType.notificationChanged;
  }

  @override
  void initState() {
    super.initState();
    _loadProfileCounters();
    _profileSubscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted || !_shouldReloadProfileCounters(event)) return;
      _loadProfileCounters(silent: true);
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileCounters({bool silent = false}) async {
    if (_isLoadingProfileCounters) return;
    if (mounted) setState(() => _isLoadingProfileCounters = true);

    try {
      final result = await Future.wait<dynamic>([
        CampusRepository.instance.fetchFollowing(),
        CampusRepository.instance.fetchFollowers(),
        CampusRepository.instance.fetchLikesReceived(),
        CampusRepository.instance.fetchMyActivities(),
        CampusRepository.instance.fetchFavorites(),
        CampusRepository.instance.fetchDrafts(),
        CampusRepository.instance.fetchMyGroups(),
      ]);

      final following = result[0] as List<CampusUser>;
      final followers = result[1] as List<CampusUser>;
      final likes = result[2] as List<CampusLikeRecord>;
      final activities = result[3] as List<CampusActivity>;
      final favorites = result[4] as List<CampusFavoriteRecord>;
      final drafts = result[5] as List<CampusDraft>;
      final groups = result[6] as List<CampusGroup>;

      if (!mounted) return;
      setState(() {
        _followingCount = following.length;
        _followersCount = followers.length;
        _likedCount = likes.length;
        _activityCount = activities.length;
        _favoritePostCount = favorites
            .where((record) => record.kind == 'post')
            .length;
        _draftCount = drafts.length;
        _groupCount = groups.length;
        _hasLoadedProfileCounters = true;
      });
    } catch (error) {
      if (mounted && !silent && !_hasLoadedProfileCounters) {
        _showShellMessage(context, _shellError(error));
      }
    } finally {
      if (mounted) setState(() => _isLoadingProfileCounters = false);
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push<CampusUser>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result != null && mounted) {
      setState(() {});
      _loadProfileCounters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              22,
              MediaQuery.paddingOf(context).top + 18,
              22,
              28,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1681FF), Color(0xFF0F6BEE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          _showShellMessage(context, '二维码名片功能正在完善中'),
                      color: Colors.white,
                      icon: const Icon(Icons.crop_free),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      color: Colors.white,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                Row(
                  children: [
                    CampusAvatar(user: user, size: 78),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Lv.5',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${user.school} · ${user.major} · ${user.grade}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  user.bio.isEmpty ? '这个同学还没有填写简介。' : user.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MyProfileStat(
                      value: _countText(_followingCount),
                      label: '关注',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _FollowingScreen(),
                          ),
                        );
                      },
                    ),
                    _MyProfileStat(
                      value: _countText(_followersCount),
                      label: '粉丝',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _FollowersScreen(),
                          ),
                        );
                      },
                    ),
                    _MyProfileStat(
                      value: _countText(_likedCount),
                      label: '获赞',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _LikedRecordsScreen(),
                          ),
                        );
                      },
                    ),
                    _MyProfileStat(
                      value: _countText(_activityCount),
                      label: '活动',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _MyActivitiesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 92),
              child: Column(
                children: [
                  CampusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '我的动态',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MyShortcut(
                              icon: Icons.article_outlined,
                              label: '我的帖子',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _MyPostsScreen(user: user),
                                  ),
                                );
                              },
                            ),
                            _MyShortcut(
                              icon: Icons.chat_bubble_outline,
                              label: '我的评论',
                              color: AppColors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _MyCommentsScreen(user: user),
                                  ),
                                );
                              },
                            ),
                            _MyShortcut(
                              icon: Icons.star_border_rounded,
                              label: '我的收藏',
                              color: AppColors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _MyFavoritesScreen(user: user),
                                  ),
                                );
                              },
                            ),
                            _MyShortcut(
                              icon: Icons.history,
                              label: '浏览记录',
                              color: AppColors.blueDark,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const _BrowsingHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CampusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '我的内容',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _ProfileListRow(
                          icon: Icons.star_border_rounded,
                          title: '我收藏的帖子',
                          value: _countText(_favoritePostCount),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const _FavoritePostsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _ProfileListRow(
                          icon: Icons.event_available_outlined,
                          title: '我参加的活动',
                          value: _countText(_activityCount),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const _MyActivitiesScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _ProfileListRow(
                          icon: Icons.groups_2_outlined,
                          title: '我的社群',
                          value: _countText(_groupCount),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const _MyGroupsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _ProfileListRow(
                          icon: Icons.drafts_outlined,
                          title: '草稿箱',
                          value: _countText(_draftCount),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const _DraftBoxScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CampusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '常用功能',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 0.9,
                          children: [
                            _FunctionButton(
                              icon: Icons.person_outline,
                              label: '个人资料',
                              onTap: _openEditProfile,
                            ),
                            const _FunctionButton(
                              icon: Icons.verified_user_outlined,
                              label: '账号与安全',
                            ),
                            _FunctionButton(
                              icon: Icons.lock_outline,
                              label: '隐私设置',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PrivacySettingsScreen(),
                                  ),
                                );
                              },
                            ),
                            _FunctionButton(
                              icon: Icons.notifications_none,
                              label: '通知设置',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                            ),
                            const _FunctionButton(
                              icon: Icons.help_outline,
                              label: '帮助与反馈',
                            ),
                            const _FunctionButton(
                              icon: Icons.info_outline,
                              label: '关于我们',
                            ),
                            const _FunctionButton(
                              icon: Icons.person_add_alt,
                              label: '邀请好友',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _settings = CampusUserSettings.defaults();
  var _darkMode = false;
  var _isSavingSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await CampusRepository.instance.fetchSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      // Keep local defaults when the user is offline or not logged in.
    }
  }

  Future<void> _updateSettings(CampusUserSettings settings) async {
    setState(() {
      _settings = settings;
      _isSavingSettings = true;
    });
    try {
      final saved = await CampusRepository.instance.updateSettings(settings);
      if (mounted) setState(() => _settings = saved);
    } catch (error) {
      if (mounted) _showTip(_shellError(error));
      _loadSettings();
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  void _showTip(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1300),
      ),
    );
  }

  void _logout() {
    AuthSession.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _SettingsHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _SettingsUserCard(onUpdated: () => setState(() {})),
                  if (_isSavingSettings)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: '账号与安全',
                    children: [
                      _SettingsRow(
                        icon: Icons.verified_user_outlined,
                        title: '账号安全',
                        onTap: () => _showTip('账号安全功能开发中'),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        title: '修改密码',
                        onTap: () => _showTip('修改密码功能开发中'),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.phone_iphone_rounded,
                        title: '绑定手机',
                        onTap: () => _showTip('当前绑定手机：138****5621'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: '通知设置',
                    children: [
                      _SettingsSwitchRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: '消息提醒',
                        value: _settings.messageReminder,
                        onChanged: (value) {
                          _updateSettings(
                            _settings.copyWith(messageReminder: value),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchRow(
                        icon: Icons.notifications_none_rounded,
                        title: '活动通知',
                        value: _settings.activityNotice,
                        onChanged: (value) {
                          _updateSettings(
                            _settings.copyWith(activityNotice: value),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsSwitchRow(
                        icon: Icons.volume_up_outlined,
                        title: '系统通知',
                        value: _settings.systemNotice,
                        onChanged: (value) {
                          _updateSettings(
                            _settings.copyWith(systemNotice: value),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: '隐私设置',
                    children: [
                      _SettingsRow(
                        icon: Icons.person_outline_rounded,
                        title: '谁可以看我的动态',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacySettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.block_rounded,
                        title: '黑名单管理',
                        onTap: () => _showTip('黑名单管理功能开发中'),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.filter_alt_outlined,
                        title: '屏蔽词设置',
                        onTap: () => _showTip('屏蔽词设置功能开发中'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: '通用',
                    children: [
                      _SettingsSwitchRow(
                        icon: Icons.dark_mode_outlined,
                        title: '深色模式',
                        value: _darkMode,
                        onChanged: (value) {
                          setState(() => _darkMode = value);
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.delete_outline_rounded,
                        title: '清理缓存',
                        value: '23.6MB',
                        onTap: () => _showTip('缓存已清理'),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.language_rounded,
                        title: '语言设置',
                        onTap: () => _showTip('当前语言：简体中文'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: '校园服务',
                    children: [
                      _SettingsRow(
                        icon: Icons.workspace_premium_outlined,
                        title: '校园认证',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CampusVerificationScreen(),
                            ),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.school_outlined,
                        title: '学籍信息',
                        onTap: () => _showTip('学籍信息功能开发中'),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.help_outline_rounded,
                        title: '反馈与帮助',
                        onTap: () => _showTip('反馈与帮助功能开发中'),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        title: '关于我们',
                        onTap: () => _showTip('校园活动圈 v0.1.0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SettingsLogoutButton(onTap: _logout),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.ink,
                size: 34,
              ),
            ),
          ),
          const Text(
            '设置',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsUserCard extends StatelessWidget {
  const _SettingsUserCard({required this.onUpdated});

  final VoidCallback onUpdated;

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.user ?? xiaobei;
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        ).then((_) => onUpdated());
      },
      child: Row(
        children: [
          CampusAvatar(user: user, size: 62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user.school,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 28,
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 25),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue, size: 25),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.78,
            child: Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.blue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD8DFEA),
              onChanged: onChanged,
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(indent: 39, height: 1);
  }
}

class _SettingsLogoutButton extends StatelessWidget {
  const _SettingsLogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('退出登录'),
              content: const Text('你确定要退出登录吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('确定退出'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            onTap();
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.red,
          side: const BorderSide(color: AppColors.red),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text('退出登录'),
      ),
    );
  }
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  var _settings = CampusUserSettings.defaults();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await CampusRepository.instance.fetchSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      // Local defaults are fine when the backend is offline.
    }
  }

  Future<void> _updateSettings(CampusUserSettings settings) async {
    setState(() => _settings = settings);
    try {
      final saved = await CampusRepository.instance.updateSettings(settings);
      if (mounted) setState(() => _settings = saved);
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _PrivacyHeader(onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  const _PrivacyBanner(),
                  const SizedBox(height: 26),
                  const _PrivacySectionCard(
                    children: [
                      _PrivacyOptionRow(
                        icon: Icons.visibility_outlined,
                        iconColor: AppColors.blue,
                        title: '谁可以看我的动态',
                        subtitle: '设置哪些人可以查看你发布的动态内容',
                        value: '仅好友可见',
                      ),
                      _PrivacyDivider(),
                      _PrivacyOptionRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        iconColor: AppColors.green,
                        title: '谁可以给我发私信',
                        subtitle: '设置哪些人可以给你发送私信消息',
                        value: '好友及关注的人',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PrivacySectionCard(
                    children: [
                      _PrivacySwitchRow(
                        icon: Icons.search_rounded,
                        iconColor: AppColors.orange,
                        title: '允许通过学号/昵称搜索我',
                        subtitle: '关闭后，其他人将无法通过学号或昵称\n搜索到你',
                        value: _settings.allowSearch,
                        onChanged: (value) {
                          _updateSettings(
                            _settings.copyWith(allowSearch: value),
                          );
                        },
                      ),
                      const _PrivacyDivider(),
                      _PrivacySwitchRow(
                        icon: Icons.mark_chat_unread_outlined,
                        iconColor: AppColors.red,
                        title: '屏蔽陌生人评论',
                        subtitle: '开启后，非好友将无法对你的动态进行\n评论和回复',
                        value: _settings.blockStrangerComments,
                        onChanged: (value) {
                          _updateSettings(
                            _settings.copyWith(blockStrangerComments: value),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _PrivacySectionCard(
                    children: [
                      _PrivacyOptionRow(
                        icon: Icons.calendar_month_outlined,
                        iconColor: AppColors.purple,
                        title: '活动报名信息是否公开',
                        subtitle: '关闭后，其他人将看不到你的报名记录\n和参与活动',
                        value: '公开',
                      ),
                      _PrivacyDivider(),
                      _PrivacyOptionRow(
                        icon: Icons.location_on_outlined,
                        iconColor: AppColors.blue,
                        title: '地理位置展示权限',
                        subtitle: '设置你发布动态或签到时的位置信息\n可见范围',
                        value: '仅好友可见',
                      ),
                      _PrivacyDivider(),
                      _PrivacyOptionRow(
                        icon: Icons.person_remove_alt_1_outlined,
                        iconColor: AppColors.ink,
                        title: '黑名单管理',
                        subtitle: '管理被你拉黑的用户，拉黑后对方将无\n法访问你的主页和内容',
                        value: '12 人',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _PrivacyProtectionCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyHeader extends StatelessWidget {
  const _PrivacyHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      height: topInset + 70,
      color: Colors.white,
      padding: EdgeInsets.only(top: topInset),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const SizedBox(
                width: 46,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.ink,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          const Text(
            '隐私设置',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FC),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.blue, size: 18),
            SizedBox(width: 8),
            Text(
              '你的隐私由你掌控，安心分享校园生活',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySectionCard extends StatelessWidget {
  const _PrivacySectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _PrivacyOptionRow extends StatelessWidget {
  const _PrivacyOptionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _PrivacyRowShell(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _PrivacySwitchRow extends StatelessWidget {
  const _PrivacySwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PrivacyRowShell(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.blue,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFD5DCE7),
        onChanged: onChanged,
      ),
    );
  }
}

class _PrivacyRowShell extends StatelessWidget {
  const _PrivacyRowShell({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PrivacyIcon(icon: icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _PrivacyIcon extends StatelessWidget {
  const _PrivacyIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }
}

class _PrivacyDivider extends StatelessWidget {
  const _PrivacyDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 84),
      child: Divider(height: 1),
    );
  }
}

class _PrivacyProtectionCard extends StatelessWidget {
  const _PrivacyProtectionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          _PrivacyIcon(icon: Icons.security_rounded, color: AppColors.blue),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '隐私保护，实时生效',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '你的所有隐私设置修改后将立即生效，我们会全力保护你的个人信息安全。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({required this.user, super.key});

  final CampusUser user;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _selectedTab = 0;
  late Future<_RealUserProfileBundle> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  static const _tabs = ['动态', '帖子', '活动', '相册'];

  bool get _isCurrentProfile {
    final authUser = AuthSession.user;
    if (authUser == null) return false;

    if (widget.user.id.isNotEmpty && authUser.id.isNotEmpty) {
      return widget.user.id == authUser.id;
    }

    return widget.user.name == authUser.name;
  }

  CampusUser get _displayUser {
    if (_isCurrentProfile) return AuthSession.user ?? widget.user;
    return widget.user;
  }

  @override
  void initState() {
    super.initState();
    _future = _loadProfile();

    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.activityChanged) {
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
    final next = _loadProfile();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<_RealUserProfileBundle> _loadProfile() async {
    final user = _displayUser;

    if (user.id.trim().isEmpty) {
      if (_isCurrentProfile) {
        return _loadCurrentProfileFallback(user);
      }

      return _RealUserProfileBundle.empty(user);
    }

    try {
      final profile = await CampusRepository.instance.fetchUserProfile(user);
      final profileUser = profile.user;

      if (_isCurrentProfile) {
        AuthSession.updateUser(
          profileUser.copyWith(
            followers: profile.followersCount,
            following: profile.followingCount,
          ),
        );
      }

      return _RealUserProfileBundle(
        user: profileUser.copyWith(
          followers: profile.followersCount,
          following: profile.followingCount,
        ),
        posts: profile.posts,
        activities: profile.activities,
        followingCount: profile.followingCount,
        followersCount: profile.followersCount,
        likesReceivedCount: profile.likesReceivedCount,
      );
    } catch (error) {
      if (_isCurrentProfile) {
        return _loadCurrentProfileFallback(
          user,
          errorMessage: _shellError(error),
        );
      }

      return _RealUserProfileBundle.empty(
        user,
        errorMessage: _shellError(error),
      );
    }
  }

  Future<_RealUserProfileBundle> _loadCurrentProfileFallback(
    CampusUser user, {
    String? errorMessage,
  }) async {
    try {
      final repo = CampusRepository.instance;

      final results = await Future.wait<Object>([
        repo.fetchMyPosts(),
        repo.fetchMyActivities(),
        repo.fetchCreatedActivities(),
        repo.fetchFollowing(),
        repo.fetchFollowers(),
        repo.fetchLikesReceived(),
      ]);

      final posts = results[0] as List<CampusPost>;
      final joinedActivities = results[1] as List<CampusActivity>;
      final createdActivities = results[2] as List<CampusActivity>;
      final following = results[3] as List<CampusUser>;
      final followers = results[4] as List<CampusUser>;
      final likesReceived = results[5] as List<CampusLikeRecord>;

      final activityMap = <String, CampusActivity>{};
      for (final activity in [...joinedActivities, ...createdActivities]) {
        final key = activity.id.isNotEmpty
            ? activity.id
            : '${activity.title}|${activity.date}|${activity.time}';
        activityMap[key] = activity;
      }

      return _RealUserProfileBundle(
        user: AuthSession.user ?? user,
        posts: posts,
        activities: activityMap.values.toList(growable: false),
        followingCount: following.length,
        followersCount: followers.length,
        likesReceivedCount: likesReceived.length,
        errorMessage: errorMessage,
      );
    } catch (fallbackError) {
      return _RealUserProfileBundle.empty(
        user,
        errorMessage: errorMessage ?? _shellError(fallbackError),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RealUserProfileBundle>(
      future: _future,
      builder: (context, snapshot) {
        final bundle =
            snapshot.data ?? _RealUserProfileBundle.empty(_displayUser);
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null;

        return Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (isLoading) const LinearProgressIndicator(minHeight: 2),
                _UserProfileHeader(
                  user: bundle.user,
                  stats: _profileStatsFromBundle(bundle),
                  onChanged: () {
                    _refresh();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    children: [
                      if (bundle.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        CampusCard(
                          child: Text(
                            bundle.errorMessage!,
                            style: const TextStyle(color: AppColors.red),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildShortcutCard(bundle.user),
                      const SizedBox(height: 8),
                      _buildIntroCard(bundle.user),
                      const SizedBox(height: 8),
                      CampusCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildTabBar(),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                14,
                                14,
                                16,
                              ),
                              child: _buildTabContent(bundle),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
          bottomNavigationBar: BottomTabs(
            currentIndex: 4,
            onTap: (index) => navigateToTab(context, index),
          ),
        );
      },
    );
  }

  Widget _buildShortcutCard(CampusUser user) {
    return CampusCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MyShortcut(
            icon: Icons.article_outlined,
            label: '我的帖子',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _MyPostsScreen(user: user)),
              );
            },
          ),
          _MyShortcut(
            icon: Icons.chat_bubble_outline,
            label: '我的评论',
            color: AppColors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _MyCommentsScreen(user: user),
                ),
              );
            },
          ),
          _MyShortcut(
            icon: Icons.star_border_rounded,
            label: '我的收藏',
            color: AppColors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _MyFavoritesScreen(user: user),
                ),
              );
            },
          ),
          _MyShortcut(
            icon: Icons.history,
            label: '浏览记录',
            color: AppColors.blueDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const _BrowsingHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard(CampusUser user) {
    return CampusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '个人简介',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.bio.trim().isEmpty ? '这个同学还没有填写简介。' : user.bio.trim(),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _infoChip(Icons.school_outlined, user.school),
              _infoChip(Icons.menu_book_outlined, user.major),
              _infoChip(Icons.workspace_premium_outlined, user.grade),
              if (user.role?.trim().isNotEmpty == true)
                _infoChip(Icons.verified_user_outlined, user.role!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String value) {
    final label = value.trim().isEmpty ? '未填写' : value.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blue, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.blue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        for (var index = 0; index < _tabs.length; index++)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Text(
                      _tabs[index],
                      style: TextStyle(
                        color: _selectedTab == index
                            ? AppColors.blue
                            : AppColors.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _selectedTab == index ? 30 : 0,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabContent(_RealUserProfileBundle bundle) {
    return switch (_selectedTab) {
      2 => _buildActivityList(bundle.activities),
      3 => _buildAlbumEmpty(),
      _ => _buildPostList(bundle.posts),
    };
  }

  Widget _buildPostList(List<CampusPost> posts) {
    if (posts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: '暂无真实动态',
        subtitle: '发布帖子后，会自动显示在这里',
      );
    }

    return Column(
      children: [
        for (final post in posts) ...[
          _ProfileRealPostTile(post: post),
          if (post != posts.last) const Divider(height: 26),
        ],
      ],
    );
  }

  Widget _buildActivityList(List<CampusActivity> activities) {
    if (activities.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available_outlined,
        title: '暂无真实活动',
        subtitle: '报名或创建活动后，会自动显示在这里',
      );
    }

    return Column(
      children: [
        for (final activity in activities) ...[
          _ProfileRealActivityTile(activity: activity),
          if (activity != activities.last) const Divider(height: 26),
        ],
      ],
    );
  }

  Widget _buildAlbumEmpty() {
    return _buildEmptyState(
      icon: Icons.photo_library_outlined,
      title: '暂无真实相册',
      subtitle: '当前后端还没有相册接口，暂不展示演示图片',
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 42),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RealUserProfileBundle {
  const _RealUserProfileBundle({
    required this.user,
    required this.posts,
    required this.activities,
    required this.followingCount,
    required this.followersCount,
    required this.likesReceivedCount,
    this.errorMessage,
  });

  final CampusUser user;
  final List<CampusPost> posts;
  final List<CampusActivity> activities;
  final int followingCount;
  final int followersCount;
  final int likesReceivedCount;
  final String? errorMessage;

  factory _RealUserProfileBundle.empty(
    CampusUser user, {
    String? errorMessage,
  }) {
    return _RealUserProfileBundle(
      user: user,
      posts: const [],
      activities: const [],
      followingCount: user.following,
      followersCount: user.followers,
      likesReceivedCount: 0,
      errorMessage: errorMessage,
    );
  }
}

class _ProfileRealPostTile extends StatelessWidget {
  const _ProfileRealPostTile({required this.post});

  final CampusPost post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampusAvatar(user: post.author, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.author.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _shellFriendlyTime(post.createdAt),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(width: 8),
                    _CompactBadge(
                      label: '# ${post.topic}',
                      color: AppColors.blue,
                    ),
                    const Spacer(),
                    const Icon(Icons.more_horiz, color: AppColors.muted),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                    if (post.images.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      SmartImage(
                        url: post.images.first,
                        width: 108,
                        height: 82,
                        borderRadius: 10,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ProfileActionMetric(
                      icon: Icons.favorite_border_rounded,
                      value: post.likes,
                    ),
                    const SizedBox(width: 28),
                    _ProfileActionMetric(
                      icon: Icons.mode_comment_outlined,
                      value: post.comments,
                    ),
                    const SizedBox(width: 28),
                    _ProfileActionMetric(
                      icon: Icons.star_border_rounded,
                      value: post.saves,
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

class _ProfileRealActivityTile extends StatelessWidget {
  const _ProfileRealActivityTile({required this.activity});

  final CampusActivity activity;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartImage(
            url: activity.posterUrl,
            width: 92,
            height: 76,
            borderRadius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${activity.date} ${activity.time}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  activity.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  '${activity.enrolled}/${activity.capacity} 人报名',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _UserProfileHeader extends StatelessWidget {
  const _UserProfileHeader({required this.user, this.stats, this.onChanged});

  final CampusUser user;
  final _ProfileHeaderStats? stats;
  final VoidCallback? onChanged;

  bool get _isCurrentUser {
    final authUser = AuthSession.user;
    if (authUser == null) return false;

    final currentId = authUser.id.trim();
    final targetId = user.id.trim();
    if (currentId.isNotEmpty && targetId.isNotEmpty) {
      return currentId == targetId;
    }

    return authUser.name.trim() == user.name.trim();
  }

  Future<void> _openPrivateChat(BuildContext context) async {
    if (_isCurrentUser) {
      _showShellMessage(context, '不能给自己发私信');
      return;
    }

    try {
      final conversation = await CampusRepository.instance.startConversation(
        user,
      );
      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            contact: conversation.contact.id.isEmpty
                ? user
                : conversation.contact,
            conversationId: conversation.id,
            displayName: user.name,
            online: true,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(contact: user, displayName: user.name, online: true),
        ),
      );
      _showShellMessage(context, _shellError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    const headerHeight = 326.0;
    const coverHeight = 154.0;
    const panelTop = 126.0;
    const avatarTop = 128.0;
    const avatarSize = 68.0;
    const infoInset = 104.0;
    const sidePadding = 22.0;

    final profileBio = _profileBioFor(user);
    final profileGrade = _profileGradeFor(user);
    final profileClub = _profileClubFor(user);
    final profileStats = stats ?? _profileStatsFor(user);

    return SizedBox(
      height: headerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverHeight,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
              child: Image.asset(
                'assets/images/user_profile_cover.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 6,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Material(
                  color: Colors.white.withValues(alpha: 0.72),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.maybePop(context),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.ink,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                _RoundIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => _showShellMessage(context, '分享功能正在完善中'),
                ),
                const SizedBox(width: 12),
                _RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: () => _showShellMessage(context, '更多操作正在完善中'),
                ),
              ],
            ),
          ),
          const Positioned(
            top: panelTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
              ),
            ),
          ),
          Positioned(
            top: avatarTop,
            left: 18,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CampusAvatar(user: user, size: avatarSize),
            ),
          ),
          Positioned(
            top: panelTop + 24,
            right: sidePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileFollowButton(user: user, onChanged: onChanged),
                if (!_isCurrentUser) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 104,
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed: () => _openPrivateChat(context),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 17,
                      ),
                      label: const Text('私信'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: BorderSide(
                          color: AppColors.blue.withValues(alpha: 0.72),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: panelTop + 22,
            left: infoInset,
            right: 150,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _GenderBadge(),
                  const SizedBox(width: 8),
                  _CompactBadge(label: user.school, color: AppColors.blue),
                ],
              ),
            ),
          ),
          Positioned(
            top: panelTop + 58,
            left: infoInset,
            right: 150,
            child: Text(
              profileBio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          Positioned(
            top: panelTop + 92,
            left: infoInset,
            right: 138,
            child: Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _CompactBadge(label: profileGrade, color: AppColors.blue),
                _CompactBadge(label: profileClub, color: AppColors.blue),
              ],
            ),
          ),
          Positioned(
            top: panelTop + 132,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ProfileStat(value: '${profileStats.following}', label: '关注'),
                _ProfileStat(value: '${profileStats.followers}', label: '粉丝'),
                _ProfileStat(value: '${profileStats.likes}', label: '获赞'),
                _ProfileStat(value: '${profileStats.activities}', label: '活动'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _profileBioFor(CampusUser user) {
  final bio = user.bio.trim();
  return bio.isEmpty ? '这个同学还没有填写简介。' : bio;
}

String _profileGradeFor(CampusUser user) {
  final grade = user.grade.trim();
  return grade.isEmpty ? '未填写年级' : grade;
}

String _profileClubFor(CampusUser user) {
  final role = user.role?.trim() ?? '';
  if (role.isNotEmpty) return role;

  final major = user.major.trim();
  return major.isEmpty ? '未填写专业' : major;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.ink, size: 25),
        ),
      ),
    );
  }
}

class _GenderBadge extends StatelessWidget {
  const _GenderBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.female, color: AppColors.red, size: 16),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileSubPageShell extends StatelessWidget {
  const _ProfileSubPageShell({
    required this.title,
    required this.child,
    this.trailing,
    this.bottomNavigationBar,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar:
          bottomNavigationBar ??
          BottomTabs(
            currentIndex: 4,
            onTap: (index) => navigateToTab(context, index),
          ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: trailing ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SubPageTextAction extends StatelessWidget {
  const _SubPageTextAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.blue,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SegmentedFilterTabs extends StatelessWidget {
  const _SegmentedFilterTabs({required this.tabs, this.compact = false});

  final List<String> tabs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 48 : 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == 0
                      ? AppColors.blue.withValues(alpha: compact ? 1.0 : 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: compact && i != 0
                      ? Border.all(color: AppColors.line)
                      : null,
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: i == 0
                        ? (compact ? Colors.white : AppColors.blue)
                        : AppColors.muted,
                    fontSize: 15,
                    fontWeight: i == 0 ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileEmptyCard extends StatelessWidget {
  const _ProfileEmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Icon(icon, size: 46, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyPostsScreen extends StatefulWidget {
  const _MyPostsScreen({required this.user});

  final CampusUser user;

  @override
  State<_MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<_MyPostsScreen> {
  late Future<List<CampusPost>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchMyPosts();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.profileChanged) {
        _refreshPosts();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _refreshPosts() {
    if (!mounted) return;
    setState(() {
      _future = CampusRepository.instance.fetchMyPosts();
    });
  }

  Future<void> _editPost(CampusPost post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PublishPostScreen(initialPost: post)),
    );

    if (changed == true && mounted) {
      _refreshPosts();
      _showShellMessage(context, '帖子已更新');
    }
  }

  Future<void> _deletePost(CampusPost post) async {
    try {
      await CampusRepository.instance.deletePost(post);
      if (!mounted) return;
      setState(() {
        _future = CampusRepository.instance.fetchMyPosts();
      });
      _showShellMessage(context, '帖子已删除');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '我的帖子',
      trailing: const Icon(
        Icons.search_rounded,
        color: AppColors.ink,
        size: 30,
      ),
      child: FutureBuilder<List<CampusPost>>(
        future: _future,
        builder: (context, snapshot) {
          final remotePosts = snapshot.data ?? const <CampusPost>[];
          final posts = remotePosts;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const _SegmentedFilterTabs(tabs: ['全部', '已发布', '审核中', '草稿']),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (posts.isEmpty)
                CampusCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.article_outlined,
                        size: 46,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '暂无真实帖子数据',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '发布一条动态后，会自动显示在这里',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      PrimaryButton(
                        label: '去发布帖子',
                        onPressed: () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PublishPostScreen(),
                            ),
                          );
                          if (created == true) _refreshPosts();
                        },
                      ),
                    ],
                  ),
                ),
              for (final post in posts) ...[
                _PostManageCard(
                  post: post,
                  onDelete: remotePosts.isEmpty
                      ? null
                      : () => _deletePost(post),
                ),
                if (remotePosts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _PostManageInlineActions(
                    onEdit: () => _editPost(post),
                    onDelete: () => _deletePost(post),
                  ),
                ],
                const SizedBox(height: 14),
              ],
              const Center(
                child: Text(
                  '— 已加载全部内容 —',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MyCommentsScreen extends StatefulWidget {
  const _MyCommentsScreen({required this.user});

  final CampusUser user;

  @override
  State<_MyCommentsScreen> createState() => _MyCommentsScreenState();
}

class _MyCommentsScreenState extends State<_MyCommentsScreen> {
  late Future<List<CampusMyCommentRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchMyComments();
  }

  List<_CommentEntry> _fallbackComments() {
    return [
      _CommentEntry(
        title: '图书馆座位预约也太难了！',
        meta: '今天 08:30 · 校园生活',
        image: 'asset:assets/images/comment_library.png',
        icon: Icons.article_rounded,
        iconColor: AppColors.blue,
        time: '2小时前',
        target: '回复给 林小北',
        body: '我也遇到过这种情况，建议大家可以试试早上 7:30 放号的那一波，会好抢很多～',
        likes: 32,
        replyLabel: '查看 5 条回复',
      ),
      _CommentEntry(
        title: '校园秋日摄影大赛作品征集',
        meta: '10月12日 15:20 · 校园话题',
        image: 'asset:assets/images/comment_autumn.png',
        icon: Icons.tag_rounded,
        iconColor: AppColors.blue,
        time: '昨天',
        target: '评论于 摄影作品分享',
        body: '第三张光影绝了！是用什么镜头拍的呀？感觉氛围感拉满了～',
        likes: 18,
        replyLabel: '查看 3 条回复',
      ),
      _CommentEntry(
        title: '设计学院开放日｜探索创意的无限可能',
        meta: '10月15日 10:00 · 活动',
        image: 'asset:assets/images/comment_design_day.png',
        icon: Icons.event_available_rounded,
        iconColor: AppColors.orange,
        time: '3天前',
        target: '回复给 活动小助手',
        body: '请问需要提前报名吗？可以带朋友一起参加吗～很期待！',
        likes: 15,
        replyLabel: '1 条新回复',
        replyColor: AppColors.orange,
      ),
      _CommentEntry(
        title: '期末复习怎么高效规划时间？',
        meta: '10月10日 21:45 · 学习交流',
        image: 'asset:assets/images/comment_study.png',
        icon: Icons.chat_bubble_rounded,
        iconColor: AppColors.blue,
        time: '5天前',
        target: '回复给 学霸小明',
        body: '你的方法很实用！我打算试试番茄钟 + 思维导图，之前效率确实不太高，感谢分享～',
        likes: 24,
        replyLabel: '查看 2 条回复',
      ),
    ];
  }

  Future<void> _deleteComment(CampusMyCommentRecord comment) async {
    try {
      await CampusRepository.instance.deleteComment(comment);
      if (!mounted) return;
      setState(() => _future = CampusRepository.instance.fetchMyComments());
      _showShellMessage(context, '评论已删除');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '我的评论',
      trailing: const Icon(
        Icons.search_rounded,
        color: AppColors.ink,
        size: 30,
      ),
      child: FutureBuilder<List<CampusMyCommentRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <CampusMyCommentRecord>[];
          final entries = records.isEmpty
              ? _fallbackComments()
              : records.map(_CommentEntry.fromRecord).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              const _SegmentedFilterTabs(
                tabs: ['全部', '帖子评论', '活动评论', '回复'],
                compact: true,
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < entries.length; index++) ...[
                _CommentManageCard(
                  user: widget.user,
                  entry: entries[index],
                  onDelete: records.isEmpty
                      ? null
                      : () => _deleteComment(records[index]),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MyFavoritesScreen extends StatefulWidget {
  const _MyFavoritesScreen({required this.user});

  final CampusUser user;

  @override
  State<_MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<_MyFavoritesScreen> {
  late Future<List<CampusFavoriteRecord>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchFavorites();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.activityChanged ||
          event.type == CampusEventType.feedChanged ||
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

  void _refresh() {
    setState(() {
      _future = CampusRepository.instance.fetchFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '我的收藏',
      child: FutureBuilder<List<CampusFavoriteRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <CampusFavoriteRecord>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              CampusCard(
                child: Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? '正在同步收藏数据'
                      : '共 ${records.length} 条收藏',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  records.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (records.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.star_border_rounded,
                  title: '暂无收藏',
                  subtitle: '收藏帖子或活动后，会自动显示在这里',
                )
              else
                for (final record in records) ...[
                  _RealFavoriteRecordTile(record: record),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _RealFavoriteRecordTile extends StatelessWidget {
  const _RealFavoriteRecordTile({required this.record, this.postOnly = false});

  final CampusFavoriteRecord record;
  final bool postOnly;

  @override
  Widget build(BuildContext context) {
    final isActivity = record.kind == 'activity';
    final title = isActivity ? record.activity.title : record.post.title;
    final subtitle = isActivity
        ? '${record.activity.date}  ${record.activity.time} · ${record.activity.location}'
        : record.post.body;
    final image = isActivity
        ? record.activity.posterUrl
        : (record.post.images.isEmpty
              ? record.post.author.avatarUrl
              : record.post.images.first);

    return CampusCard(
      child: Row(
        children: [
          SmartImage(url: image, width: 72, height: 72, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pill(
                  label: isActivity ? '活动' : '帖子',
                  color: isActivity ? AppColors.green : AppColors.blue,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  '收藏于 ${_friendlyTime(record.createdAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyGroupsScreen extends StatefulWidget {
  const _MyGroupsScreen();

  @override
  State<_MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<_MyGroupsScreen> {
  late Future<List<CampusGroup>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchMyGroups();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.groupChanged ||
          event.type == CampusEventType.feedChanged ||
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

  void _refresh() {
    setState(() {
      _future = CampusRepository.instance.fetchMyGroups();
    });
  }

  String _membershipLabel(CampusGroup group) {
    if (group.canManage) return '管理中';
    if (group.membershipStatus == 'pending') return '审核中';
    if (group.joined) return '已加入';
    return '未加入';
  }

  Color _membershipColor(CampusGroup group) {
    if (group.canManage) return AppColors.blue;
    if (group.membershipStatus == 'pending') return AppColors.orange;
    if (group.joined) return AppColors.green;
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '我的社群',
      child: FutureBuilder<List<CampusGroup>>(
        future: _future,
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <CampusGroup>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              CampusCard(
                child: Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? '正在同步社群数据'
                      : '共 ${groups.length} 个社群',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  groups.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (groups.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.groups_2_outlined,
                  title: '暂无社群',
                  subtitle: '加入或创建社群后，会自动显示在这里',
                )
              else
                for (final group in groups) ...[
                  CampusCard(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(group: group),
                        ),
                      );
                      if (mounted) _refresh();
                    },
                    child: Row(
                      children: [
                        SmartImage(
                          url: group.iconUrl,
                          width: 58,
                          height: 58,
                          borderRadius: 14,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${group.members} 位成员 · ${group.tags.take(2).join(' / ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 8),
                              Pill(
                                label: _membershipLabel(group),
                                color: _membershipColor(group),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _BrowsingHistoryScreen extends StatefulWidget {
  const _BrowsingHistoryScreen();

  @override
  State<_BrowsingHistoryScreen> createState() => _BrowsingHistoryScreenState();
}

class _BrowsingHistoryScreenState extends State<_BrowsingHistoryScreen> {
  late Future<List<CampusHistoryRecord>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchHistory();

    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;

      if (event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.feedChanged ||
          event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.activityChanged ||
          event.type == CampusEventType.groupChanged) {
        setState(() {
          _future = CampusRepository.instance.fetchHistory();
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _clear() async {
    // 临时日志：页面层
    // ignore: avoid_print
    print('[front:ui:clearHistory] tap');
    try {
      await CampusRepository.instance.clearHistory();
      if (!mounted) return;
      setState(() {
        _future = Future.value(const <CampusHistoryRecord>[]);
      });
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

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '浏览记录',
      trailing: GestureDetector(
        onTap: _clear,
        child: const _SubPageTextAction(label: '清空'),
      ),
      bottomNavigationBar: BottomTabs(
        currentIndex: 4,
        onTap: (index) => navigateToTab(context, index),
      ),
      child: FutureBuilder<List<CampusHistoryRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <CampusHistoryRecord>[];
          if (records.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: const [
                _ProfileEmptyCard(
                  icon: Icons.history_rounded,
                  title: '暂无浏览记录',
                  subtitle: '查看帖子、活动或社群详情后，会自动显示在这里',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _HistorySection(
                title: '最近',
                items: records.map(_historyEntryForRecord).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FavoritePostsScreen extends StatefulWidget {
  const _FavoritePostsScreen();

  @override
  State<_FavoritePostsScreen> createState() => _FavoritePostsScreenState();
}

class _FavoritePostsScreenState extends State<_FavoritePostsScreen> {
  late Future<List<CampusFavoriteRecord>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchFavorites();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.postChanged ||
          event.type == CampusEventType.feedChanged ||
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

  void _refresh() {
    setState(() {
      _future = CampusRepository.instance.fetchFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '我收藏的帖子',
      child: FutureBuilder<List<CampusFavoriteRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final records = (snapshot.data ?? const <CampusFavoriteRecord>[])
              .where((record) => record.kind == 'post')
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              const _SegmentedFilterTabs(
                tabs: ['全部', '最新收藏', '最多点赞'],
                compact: true,
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  records.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (records.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.star_border_rounded,
                  title: '暂无收藏帖子',
                  subtitle: '收藏帖子后，会自动显示在这里',
                )
              else
                for (final record in records) ...[
                  _RealFavoriteRecordTile(record: record, postOnly: true),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _DraftBoxScreen extends StatefulWidget {
  const _DraftBoxScreen();

  @override
  State<_DraftBoxScreen> createState() => _DraftBoxScreenState();
}

class _DraftBoxScreenState extends State<_DraftBoxScreen> {
  late Future<List<CampusDraft>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchDrafts();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.profileChanged ||
          event.type == CampusEventType.feedChanged) {
        setState(() {
          _future = CampusRepository.instance.fetchDrafts();
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _deleteDraft(CampusDraft draft) async {
    try {
      await CampusRepository.instance.deleteDraft(draft);
      if (!mounted) return;
      setState(() {
        _future = CampusRepository.instance.fetchDrafts();
      });
      _showShellMessage(context, '草稿已删除');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    }
  }

  Future<void> _openDraft(CampusDraft draft) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PublishPostScreen(initialDraft: draft)),
    );

    if (changed == true && mounted) {
      setState(() {
        _future = CampusRepository.instance.fetchDrafts();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSubPageShell(
      title: '草稿箱',
      trailing: const Icon(
        Icons.more_horiz_rounded,
        color: AppColors.ink,
        size: 30,
      ),
      child: FutureBuilder<List<CampusDraft>>(
        future: _future,
        builder: (context, snapshot) {
          final allDrafts = snapshot.data ?? const <CampusDraft>[];
          final drafts = allDrafts
              .where((draft) => draft.kind != 'activity')
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              const _SegmentedFilterTabs(tabs: ['全部', '帖子草稿'], compact: true),
              const SizedBox(height: 14),
              if (drafts.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.drafts_outlined,
                  title: '暂无草稿',
                  subtitle: '保存草稿后，会自动显示在这里',
                )
              else
                for (final draft in drafts) ...[
                  _DraftTile.fromDraft(
                    draft: draft,
                    onEdit: () => _openDraft(draft),
                    onDelete: () => _deleteDraft(draft),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _FollowingScreen extends StatefulWidget {
  const _FollowingScreen();

  @override
  State<_FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<_FollowingScreen> {
  late Future<List<CampusUser>> _followingFuture;

  @override
  void initState() {
    super.initState();
    _followingFuture = CampusRepository.instance.fetchFollowing();
  }

  Future<void> _unfollow(CampusUser user) async {
    try {
      await CampusRepository.instance.unfollowUser(user);
      setState(() {
        _followingFuture = CampusRepository.instance.fetchFollowing();
      });
      if (mounted) _showShellMessage(context, '已取消关注 ${user.name}');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StatModuleShell(
      title: '我的关注',
      tabs: const ['全部', '特别关注', '同学院'],
      child: FutureBuilder<List<CampusUser>>(
        future: _followingFuture,
        builder: (context, snapshot) {
          final remoteUsers = snapshot.data ?? const <CampusUser>[];
          final users = remoteUsers.isNotEmpty
              ? remoteUsers
              : [
                  _chenKexinUser,
                  _wangZihaoUser,
                  _liuSiyuUser,
                  _linXiaobeiUser,
                  _zhangYutongUser,
                  _zhouMingyuanUser,
                ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              for (var index = 0; index < users.length; index++) ...[
                _RelationUserCard(
                  user: users[index],
                  badgeIcon: index == 0 ? Icons.stars_rounded : null,
                  badgeColor: AppColors.red,
                  description: users[index].bio.isEmpty
                      ? '这个同学还没有填写简介'
                      : users[index].bio,
                  tag: users[index].school,
                  primaryAction: users[index].followsMe ? '互相关注' : '已关注',
                  primaryIsActive: users[index].followsMe,
                  onPrimaryTap: remoteUsers.isEmpty
                      ? null
                      : () => _unfollow(users[index]),
                ),
                const SizedBox(height: 14),
              ],
              const Center(
                child: Text(
                  '已经到底啦～',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FollowersScreen extends StatefulWidget {
  const _FollowersScreen();

  @override
  State<_FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<_FollowersScreen> {
  late Future<List<CampusUser>> _followersFuture;

  @override
  void initState() {
    super.initState();
    _followersFuture = CampusRepository.instance.fetchFollowers();
  }

  Future<void> _followBack(CampusUser user) async {
    try {
      await CampusRepository.instance.followUser(user);
      setState(() {
        _followersFuture = CampusRepository.instance.fetchFollowers();
      });
      if (mounted) _showShellMessage(context, '已回关 ${user.name}');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StatModuleShell(
      title: '我的粉丝',
      tabs: const ['全部', '互相关注', '新关注'],
      child: FutureBuilder<List<CampusUser>>(
        future: _followersFuture,
        builder: (context, snapshot) {
          final remoteUsers = snapshot.data ?? const <CampusUser>[];
          final users = remoteUsers.isNotEmpty
              ? remoteUsers
              : [
                  _linXiaUser,
                  _chenYuhangUser,
                  _zhouKexinUser,
                  _liMingyuanUser,
                  _suYaqingUser,
                  _zhangYifanUser,
                  _zhaoXinyiUser,
                ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              for (var index = 0; index < users.length; index++) ...[
                _FollowerUserCard(
                  user: users[index],
                  time: users[index].followedAt.isEmpty
                      ? [
                          '刚刚关注了你',
                          '2 小时前关注了你',
                          '5 小时前关注了你',
                          '昨天 10:23 关注了你',
                          '昨天 21:15 关注了你',
                          '2天前关注了你',
                          '3天前关注了你',
                        ][index]
                      : '关注了你',
                  action: remoteUsers.isEmpty && index == users.length - 1
                      ? '移除粉丝'
                      : users[index].followedByMe
                      ? '已互关'
                      : '回关',
                  mutedAction: users[index].followedByMe,
                  dangerAction:
                      remoteUsers.isEmpty && index == users.length - 1,
                  onTap:
                      remoteUsers.isEmpty ||
                          users[index].followedByMe ||
                          index == users.length - 1
                      ? null
                      : () => _followBack(users[index]),
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LikedRecordsScreen extends StatefulWidget {
  const _LikedRecordsScreen();

  @override
  State<_LikedRecordsScreen> createState() => _LikedRecordsScreenState();
}

class _LikedRecordsScreenState extends State<_LikedRecordsScreen> {
  late Future<List<CampusLikeRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = CampusRepository.instance.fetchLikesReceived();
  }

  @override
  Widget build(BuildContext context) {
    return _StatModuleShell(
      title: '获赞记录',
      tabs: const ['全部', '帖子赞', '评论赞'],
      selectedStyle: _StatTabsStyle.filled,
      child: FutureBuilder<List<CampusLikeRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <CampusLikeRecord>[];
          if (records.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: const [
                _LikeRecordCard(
                  user: _chenKexinUser,
                  actionText: '赞了你的帖子',
                  title: '《校园日落拍摄地推荐》',
                  time: '2分钟前',
                  image: 'asset:assets/images/profile_sunset.png',
                ),
                SizedBox(height: 14),
                _LikeRecordCard(
                  user: _wangZihaoUser,
                  actionText: '赞了你的评论',
                  comment: '这张照片拍得好有氛围，学长是用什么相机拍的吗？',
                  time: '今天 14:20',
                  image: 'asset:assets/images/comment_study.png',
                ),
                SizedBox(height: 14),
                _LikeRecordCard(
                  user: _linXiaomanUser,
                  actionText: '赞了你的帖子',
                  title: '《图书馆自习指南》',
                  time: '今天 11:07',
                  image: 'asset:assets/images/comment_library.png',
                ),
                SizedBox(height: 14),
                _LikeRecordCard(
                  user: _zhaoYihangUser,
                  actionText: '赞了你的评论',
                  comment: '确实很实用！收藏了慢慢看～',
                  time: '昨天 23:45',
                  image: 'asset:assets/images/comment_autumn.png',
                ),
                SizedBox(height: 14),
                _LikeRecordCard(
                  user: _suQingUser,
                  actionText: '赞了你的帖子',
                  title: '《期末复习计划表分享》',
                  time: '昨天 21:16',
                  image: 'asset:assets/images/profile_book.png',
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              for (final record in records) ...[
                _LikeRecordCard(
                  user: record.user,
                  actionText: record.actionText,
                  title: '《${record.post.title}》',
                  time: record.createdAt,
                  image: record.post.images.isEmpty
                      ? 'asset:assets/images/profile_book.png'
                      : record.post.images.first,
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MyActivitiesScreen extends StatefulWidget {
  const _MyActivitiesScreen();

  @override
  State<_MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<_MyActivitiesScreen> {
  late Future<List<CampusActivity>> _future;
  StreamSubscription<CampusDataEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchMyActivities();
    _subscription = CampusEventBus.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.type == CampusEventType.activityChanged ||
          event.type == CampusEventType.feedChanged ||
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

  void _refresh() {
    setState(() {
      _future = CampusRepository.instance.fetchMyActivities();
    });
  }

  bool _isEndedActivity(CampusActivity activity) {
    final status = activity.activityStatus.trim();
    return activity.isEnded ||
        status == 'ended' ||
        status == 'finished' ||
        status == 'completed';
  }

  bool _isUpcomingActivity(CampusActivity activity) {
    return activity.isCheckInNotStarted ||
        activity.activityStatus.trim() == 'registered';
  }

  String _statusLabel(CampusActivity activity) {
    if (activity.isCheckedIn) return '已签到';
    if (_isEndedActivity(activity)) return '已结束';
    if (activity.isCheckInAvailable) return '待签到';
    if (_isUpcomingActivity(activity)) return '已报名';
    return '已报名';
  }

  Color _statusColor(CampusActivity activity) {
    if (activity.isCheckedIn) return AppColors.green;
    if (_isEndedActivity(activity)) return AppColors.muted;
    if (activity.isCheckInAvailable) return AppColors.orange;
    return AppColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return _StatModuleShell(
      title: '我的活动',
      tabs: const ['全部', '进行中', '已结束'],
      child: FutureBuilder<List<CampusActivity>>(
        future: _future,
        builder: (context, snapshot) {
          final activities = snapshot.data ?? const <CampusActivity>[];
          final endedCount = activities.where(_isEndedActivity).length;
          final upcomingCount = activities.where(_isUpcomingActivity).length;
          final ongoingCount = activities.length - endedCount;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ActivitySummaryCard(
                      label: '进行中',
                      value: '$ongoingCount',
                      icon: Icons.flag_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActivitySummaryCard(
                      label: '即将开始',
                      value: '$upcomingCount',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActivitySummaryCard(
                      label: '已结束',
                      value: '$endedCount',
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  activities.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (activities.isEmpty)
                const _ProfileEmptyCard(
                  icon: Icons.event_busy_outlined,
                  title: '暂无活动',
                  subtitle: '报名、签到或参与活动后，会自动显示在这里',
                )
              else
                for (final activity in activities) ...[
                  _MyActivityModuleCard(
                    title: activity.title,
                    image: activity.posterUrl,
                    time: '${activity.date}  ${activity.time}',
                    location: activity.location,
                    tags: [
                      _TinyTag(
                        label: _statusLabel(activity),
                        color: _statusColor(activity),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          );
        },
      ),
    );
  }
}

enum _StatTabsStyle { underline, filled }

class _StatModuleShell extends StatelessWidget {
  const _StatModuleShell({
    required this.title,
    required this.tabs,
    required this.child,
    this.selectedStyle = _StatTabsStyle.underline,
  });

  final String title;
  final List<String> tabs;
  final Widget child;
  final _StatTabsStyle selectedStyle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  SizedBox(
                    height: 70,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 76,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: Icon(Icons.search_rounded, size: 34),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatTabs(tabs: tabs, style: selectedStyle),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _StatTabs extends StatelessWidget {
  const _StatTabs({required this.tabs, required this.style});

  final List<String> tabs;
  final _StatTabsStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: style == _StatTabsStyle.filled && i == 0
                    ? Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tabs[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 58,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              tabs[i],
                              style: TextStyle(
                                color: i == 0 ? AppColors.blue : AppColors.text,
                                fontSize: 17,
                                fontWeight: i == 0
                                    ? FontWeight.w900
                                    : FontWeight.w500,
                              ),
                            ),
                            if (i == 0 && style == _StatTabsStyle.underline)
                              Positioned(
                                bottom: 5,
                                child: Container(
                                  width: 42,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.blue,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 4,
            bottom: 2,
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.22),
              size: 38,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 35,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyActivityModuleCard extends StatelessWidget {
  const _MyActivityModuleCard({
    required this.title,
    required this.image,
    required this.time,
    required this.location,
    required this.tags,
  });

  final String title;
  final String image;
  final String time;
  final String location;
  final List<_TinyTag> tags;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SmartImage(url: image, width: 144, height: 122, borderRadius: 8),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _BlueIconLine(icon: Icons.schedule_rounded, label: time),
                const SizedBox(height: 9),
                _BlueIconLine(
                  icon: Icons.location_on_outlined,
                  label: location,
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: tags),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueIconLine extends StatelessWidget {
  const _BlueIconLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.blue, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FollowerUserCard extends StatelessWidget {
  const _FollowerUserCard({
    required this.user,
    required this.time,
    required this.action,
    this.mutedAction = false,
    this.dangerAction = false,
    this.onTap,
  });

  final CampusUser user;
  final String time;
  final String action;
  final bool mutedAction;
  final bool dangerAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          CampusAvatar(user: user, size: 70),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${user.school} · ${user.grade}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onTap,
            child: _RelationActionButton(
              label: action,
              active: !mutedAction && !dangerAction,
              danger: dangerAction,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationUserCard extends StatelessWidget {
  const _RelationUserCard({
    required this.user,
    required this.description,
    required this.tag,
    required this.primaryAction,
    this.primaryIsActive = false,
    this.badgeIcon,
    this.badgeColor = AppColors.blue,
    this.onPrimaryTap,
  });

  final CampusUser user;
  final String description;
  final String tag;
  final String primaryAction;
  final bool primaryIsActive;
  final IconData? badgeIcon;
  final Color badgeColor;
  final VoidCallback? onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          CampusAvatar(user: user, size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (badgeIcon != null) ...[
                      const SizedBox(width: 6),
                      Icon(badgeIcon, color: badgeColor, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${user.school} · ${user.grade}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black, fontSize: 15),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _TinyTag(label: tag, color: AppColors.blue),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              GestureDetector(
                onTap: onPrimaryTap,
                child: _RelationActionButton(
                  label: primaryAction,
                  active: primaryIsActive,
                ),
              ),
              const SizedBox(height: 9),
              _MessageActionButton(user: user),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelationActionButton extends StatelessWidget {
  const _RelationActionButton({
    required this.label,
    this.active = false,
    this.danger = false,
  });

  final String label;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foreground = danger
        ? AppColors.red
        : active
        ? Colors.white
        : AppColors.text;
    final border = danger ? AppColors.red : AppColors.line;
    return Container(
      width: 88,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: active ? null : Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({required this.user});

  final CampusUser user;

  Future<void> _openChat(BuildContext context) async {
    try {
      final conversation = await CampusRepository.instance.startConversation(
        user,
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            contact: conversation.contact.id.isEmpty
                ? user
                : conversation.contact,
            conversationId: conversation.id,
            displayName: user.name,
            online: true,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(contact: user, displayName: user.name, online: true),
        ),
      );
      _showShellMessage(context, _shellError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openChat(context),
      child: Container(
        width: 88,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.blue, width: 1.2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.blue,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              '发消息',
              style: TextStyle(
                color: AppColors.blue,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeRecordCard extends StatelessWidget {
  const _LikeRecordCard({
    required this.user,
    required this.actionText,
    required this.time,
    required this.image,
    this.title,
    this.comment,
  });

  final CampusUser user;
  final String actionText;
  final String time;
  final String image;
  final String? title;
  final String? comment;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampusAvatar(user: user, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: actionText,
                            style: const TextStyle(
                              color: AppColors.blue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (title != null) TextSpan(text: '  $title'),
                        ],
                      ),
                    ),
                    if (comment != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          comment!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SmartImage(url: image, width: 78, height: 78, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '查看原内容',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: AppColors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _linXiaUser = CampusUser(
  name: '林小夏',
  school: '计算机学院',
  major: '软件工程',
  grade: '大三',
  avatarUrl:
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
  bio: '刚刚关注了你',
);

const _chenYuhangUser = CampusUser(
  name: '陈宇航',
  school: '电子信息学院',
  major: '通信工程',
  grade: '大二',
  avatarUrl:
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
  bio: '校园技术爱好者',
);

const _zhouKexinUser = CampusUser(
  name: '周可欣',
  school: '经济管理学院',
  major: '金融学',
  grade: '大三',
  avatarUrl:
      'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=300&q=80',
  bio: '数据与生活观察者',
);

const _liMingyuanUser = CampusUser(
  name: '李明远',
  school: '机械工程学院',
  major: '机械设计',
  grade: '大四',
  avatarUrl:
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=300&q=80',
  bio: '热爱运动和摄影',
);

const _suYaqingUser = CampusUser(
  name: '苏雅晴',
  school: '外国语学院',
  major: '英语',
  grade: '大二',
  avatarUrl:
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=300&q=80',
  bio: '喜欢记录校园日常',
);

const _zhangYifanUser = CampusUser(
  name: '张一凡',
  school: '设计艺术学院',
  major: '视觉传达',
  grade: '大三',
  avatarUrl:
      'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?auto=format&fit=crop&w=300&q=80',
  bio: '设计灵感收集者',
);

const _zhaoXinyiUser = CampusUser(
  name: '赵心怡',
  school: '法学院',
  major: '法学',
  grade: '大二',
  avatarUrl:
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
  bio: '咖啡续命中',
);

const _chenKexinUser = CampusUser(
  name: '陈可欣',
  school: '计算机学院',
  major: '软件工程',
  grade: '大二',
  avatarUrl: 'asset:assets/images/kexin_avatar.png',
  bio: '热爱生活，追逐光和梦想',
);

const _wangZihaoUser = CampusUser(
  name: '王子豪',
  school: '计算机学院',
  major: '软件工程',
  grade: '大三',
  avatarUrl: 'asset:assets/images/avatar_zihao.jpg',
  bio: '代码敲不完，咖啡续命',
);

const _liuSiyuUser = CampusUser(
  name: '刘思雨',
  school: '新闻与传播学院',
  major: '新闻学',
  grade: '大三',
  avatarUrl: 'asset:assets/images/avatar_siyu.jpg',
  bio: '记录生活，喜欢拍照',
);

const _linXiaobeiUser = CampusUser(
  name: '林小北',
  school: '电子工程学院',
  major: '电子信息',
  grade: '大二',
  avatarUrl: 'asset:assets/images/avatar_xiaobei.jpg',
  bio: '篮球爱好者，寻找球搭子',
);

const _zhangYutongUser = CampusUser(
  name: '张语桐',
  school: '外国语学院',
  major: '英语',
  grade: '大三',
  avatarUrl:
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
  bio: '喜欢阅读和旅行',
);

const _zhouMingyuanUser = CampusUser(
  name: '周明远',
  school: '经济管理学院',
  major: '经济学',
  grade: '大二',
  avatarUrl:
      'https://images.unsplash.com/photo-1527980965255-d3b416303d12?auto=format&fit=crop&w=300&q=80',
  bio: '经济学探索者',
);

const _linXiaomanUser = CampusUser(
  name: '林小满',
  school: '图书情报学院',
  major: '信息管理',
  grade: '大二',
  avatarUrl:
      'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=300&q=80',
  bio: '图书馆常驻',
);

const _zhaoYihangUser = CampusUser(
  name: '赵一航',
  school: '计算机学院',
  major: '软件工程',
  grade: '大一',
  avatarUrl:
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
  bio: '学习搭子在线',
);

const _suQingUser = CampusUser(
  name: '苏晴',
  school: '外国语学院',
  major: '英语',
  grade: '大二',
  avatarUrl:
      'https://images.unsplash.com/photo-1520813792240-56fc4a3765a7?auto=format&fit=crop&w=300&q=80',
  bio: '期末冲刺中',
);

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    this.onEdit,
    required this.title,
    required this.body,
    required this.image,
    required this.meta,
    required this.action,
    required this.actionColor,
    this.onDelete,
  });

  final String title;
  final String body;
  final String image;
  final String meta;
  final String action;
  final Color actionColor;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  factory _DraftTile.fromDraft({
    required CampusDraft draft,
    required VoidCallback onEdit,
    VoidCallback? onDelete,
  }) {
    return _DraftTile(
      onEdit: onEdit,
      title: draft.title,
      body: draft.body.isEmpty ? '还没有填写正文内容' : draft.body,
      image: draft.images.isEmpty
          ? 'asset:assets/images/profile_sunset.png'
          : draft.images.first,
      meta: '上次编辑 ${_friendlyTime(draft.updatedAt)}',
      action: draft.status == 'pending' ? '待发布' : '继续编辑',
      actionColor: draft.status == 'pending' ? AppColors.muted : AppColors.blue,
      onDelete: onDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartImage(url: image, width: 124, height: 100, borderRadius: 9),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      action,
                      style: TextStyle(
                        color: actionColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: actionColor,
                      size: 22,
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '删除草稿',
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.red,
                          size: 20,
                        ),
                      ),
                    ],
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

class _PostManageCard extends StatelessWidget {
  const _PostManageCard({required this.post, this.onDelete});

  final CampusPost post;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartImage(
            url: post.images.isEmpty
                ? 'asset:assets/images/profile_sunset.png'
                : post.images.first,
            width: 132,
            height: 116,
            borderRadius: 10,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: onDelete == null ? '更多' : '删除帖子',
                      onPressed: onDelete,
                      icon: Icon(
                        onDelete == null
                            ? Icons.more_horiz
                            : Icons.delete_outline_rounded,
                        color: onDelete == null
                            ? AppColors.muted
                            : AppColors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  post.createdAt,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ProfileActionMetric(
                      icon: Icons.visibility_outlined,
                      value: post.saves + post.likes,
                    ),
                    _ProfileActionMetric(
                      icon: Icons.thumb_up_alt_outlined,
                      value: post.likes,
                    ),
                    _ProfileActionMetric(
                      icon: Icons.mode_comment_outlined,
                      value: post.comments,
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

class _CommentEntry {
  const _CommentEntry({
    required this.title,
    required this.meta,
    required this.image,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.target,
    required this.body,
    required this.likes,
    required this.replyLabel,
    this.replyColor = AppColors.blue,
  });

  final String title;
  final String meta;
  final String image;
  final IconData icon;
  final Color iconColor;
  final String time;
  final String target;
  final String body;
  final int likes;
  final String replyLabel;
  final Color replyColor;

  factory _CommentEntry.fromRecord(CampusMyCommentRecord record) {
    final image = record.post.images.isEmpty
        ? 'asset:assets/images/profile_sunset.png'
        : record.post.images.first;
    return _CommentEntry(
      title: record.post.title,
      meta: '${record.post.createdAt} · ${record.post.topic}',
      image: image,
      icon: Icons.article_rounded,
      iconColor: AppColors.blue,
      time: _friendlyTime(record.createdAt),
      target: '评论于 ${record.post.author.name}',
      body: record.text,
      likes: record.likes,
      replyLabel: '查看原内容',
    );
  }
}

class _CommentManageCard extends StatelessWidget {
  const _CommentManageCard({
    required this.user,
    required this.entry,
    this.onDelete,
  });

  final CampusUser user;
  final _CommentEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartImage(
            url: entry.image,
            width: 124,
            height: 108,
            borderRadius: 10,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: onDelete == null ? '更多' : '删除评论',
                      onPressed: onDelete,
                      icon: Icon(
                        onDelete == null
                            ? Icons.more_horiz
                            : Icons.delete_outline_rounded,
                        color: onDelete == null
                            ? AppColors.muted
                            : AppColors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '我的评论：${entry.body}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.time,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 9),
                Text(
                  '原内容：${entry.meta}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyTime(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value.isEmpty ? '刚刚' : value;
  final now = DateTime.now();
  final difference = now.difference(parsed);
  if (difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes}分钟前';
  if (difference.inDays < 1) return '${difference.inHours}小时前';
  if (difference.inDays == 1) return '昨天';
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}

_HistoryEntry _historyEntryForRecord(CampusHistoryRecord record) {
  final icon = switch (record.kind) {
    'activity' => Icons.event_available_outlined,
    'group' => Icons.account_balance_rounded,
    'topic' => Icons.tag_rounded,
    'user' => Icons.person_outline_rounded,
    _ => Icons.article_outlined,
  };
  final tag = switch (record.kind) {
    'activity' => '活动',
    'group' => '社区',
    'topic' => '话题',
    'user' => '用户',
    _ => '帖子',
  };
  final color = switch (record.kind) {
    'activity' => AppColors.green,
    'topic' => AppColors.blue,
    'group' => AppColors.purple,
    'user' => AppColors.orange,
    _ => AppColors.blue,
  };
  return _HistoryEntry(
    title: record.title,
    tag: tag,
    meta: record.subtitle.isEmpty ? '校园内容' : record.subtitle,
    time: _friendlyTime(record.updatedAt),
    image: record.imageUrl.isEmpty ? null : record.imageUrl,
    icon: icon,
    color: color,
  );
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.title,
    required this.tag,
    required this.meta,
    required this.time,
    required this.icon,
    required this.color,
    this.image,
  }) : user = null;

  final String title;
  final String tag;
  final String meta;
  final String time;
  final IconData icon;
  final Color color;
  final String? image;
  final CampusUser? user;
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.title, required this.items});

  final String title;
  final List<_HistoryEntry> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        CampusCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _HistoryTile(entry: items[i]),
                if (i != items.length - 1)
                  const Divider(indent: 112, endIndent: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          _HistoryThumb(entry: entry),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _HistoryTag(entry: entry),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        entry.meta,
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
          const SizedBox(width: 8),
          Text(
            entry.time,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _HistoryThumb extends StatelessWidget {
  const _HistoryThumb({required this.entry});

  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final image = entry.image;
    final user = entry.user;
    return Container(
      width: 92,
      height: 58,
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image != null
          ? SmartImage(url: image, width: 92, height: 58, borderRadius: 0)
          : user != null
          ? CampusAvatar(user: user, size: 44)
          : Icon(entry.icon, color: entry.color, size: 30),
    );
  }
}

class _HistoryTag extends StatelessWidget {
  const _HistoryTag({required this.entry});

  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(entry.icon, color: entry.color, size: 15),
          const SizedBox(width: 4),
          Text(
            entry.tag,
            style: TextStyle(
              color: entry.color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionMetric extends StatelessWidget {
  const _ProfileActionMetric({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.text, size: 24),
        const SizedBox(width: 7),
        Text(
          '$value',
          style: const TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      ],
    );
  }
}

class _PostManageInlineActions extends StatelessWidget {
  const _PostManageInlineActions({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('编辑'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('删除'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
          ),
        ),
      ],
    );
  }
}

class PostFeedCard extends StatefulWidget {
  const PostFeedCard({required this.post, super.key});

  final CampusPost post;

  @override
  State<PostFeedCard> createState() => _PostFeedCardState();
}

class _PostFeedCardState extends State<PostFeedCard> {
  late CampusPost _post = widget.post;
  late bool _liked = widget.post.likedByMe;
  late bool _favorited = widget.post.favoritedByMe;
  var _isLiking = false;
  var _isFavoriting = false;

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

  void _syncPostState(CampusPost post, {bool? favorited}) {
    _post = post;
    _liked = post.likedByMe;

    _favorited = favorited ?? post.favoritedByMe;
  }

  @override
  void didUpdateWidget(covariant PostFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post != widget.post) {
      _syncPostState(widget.post);
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
        _liked = post.likedByMe;
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
        _syncPostState(post);
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
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: _post)),
    );

    if (!mounted) return;

    final latest = _cachedPostById(_post.id);
    if (latest != null) {
      setState(() => _syncPostState(latest));
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
                onPressed: () => _showShellMessage(context, '更多操作正在完善中'),
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
                    Expanded(
                      child: SmartImage(url: post.images[i], height: 92),
                    ),
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
                    : (_favorited
                          ? Icons.star_rounded
                          : Icons.star_border_rounded),
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

class DiscussionCard extends StatelessWidget {
  const DiscussionCard({required this.post, super.key});

  final CampusPost post;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: CampusAvatar(user: post.author, size: 42),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 6),
                Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CampusAvatar(user: post.author, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      post.author.name,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.mode_comment_outlined,
                      size: 17,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.comments}',
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

class _StoryItem extends StatelessWidget {
  const _StoryItem({required this.user});

  final CampusUser user;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.blue, AppColors.green],
              ),
            ),
            child: SmartImage(
              url: user.avatarUrl,
              width: 52,
              height: 52,
              borderRadius: 999,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatefulWidget {
  const _FriendCard({required this.user});

  final CampusUser user;

  @override
  State<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<_FriendCard> {
  late CampusUser _user = widget.user;
  var _isFollowing = false;

  @override
  void didUpdateWidget(covariant _FriendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _user = widget.user;
      _isFollowing = false;
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowing) return;
    setState(() => _isFollowing = true);
    try {
      final nextUser = _user.followedByMe
          ? await CampusRepository.instance.unfollowUser(_user)
          : await CampusRepository.instance.followUser(_user);
      if (!mounted) return;
      setState(() => _user = nextUser);
      _showShellMessage(
        context,
        nextUser.followedByMe ? '已关注 ${nextUser.name}' : '已取消关注',
      );
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isFollowing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return CampusCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
        );
      },
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          CampusAvatar(user: user, size: 58),
          const SizedBox(height: 8),
          Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            '${user.school} · ${user.grade}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const Spacer(),
          SizedBox(
            height: 30,
            child: FilledButton(
              onPressed: _isFollowing ? null : _toggleFollow,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                _isFollowing
                    ? '处理中'
                    : user.followedByMe
                    ? '已关注'
                    : '关注',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.title,
    required this.discussions,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String discussions;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '# $title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(discussions, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTile extends StatefulWidget {
  const _GroupTile({
    required this.group,
    required this.subtitle,
    required this.imageUser,
    this.name,
  });

  final CampusGroup group;
  final String? name;
  final String subtitle;
  final CampusUser imageUser;

  @override
  State<_GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends State<_GroupTile> {
  late CampusGroup _group = widget.group;
  StreamSubscription<CampusDataEvent>? _groupSubscription;
  var _isSubmitting = false;

  void _syncFromCachedGroup(CampusDataEvent event) {
    if (!mounted) return;
    final currentId = _group.id;
    if (currentId.isEmpty) return;

    if (!event.matches(CampusEventType.groupChanged, refId: currentId) &&
        event.type != CampusEventType.feedChanged) {
      return;
    }

    final payload = event.payload;
    if (payload is CampusGroup && payload.id == currentId) {
      setState(() => _group = payload);
      return;
    }

    for (final cached in CampusRepository.instance.cachedFeed.groups) {
      if (cached.id == currentId) {
        setState(() => _group = cached);
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _groupSubscription = CampusEventBus.instance.stream.listen(
      _syncFromCachedGroup,
    );
  }

  @override
  void didUpdateWidget(covariant _GroupTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _group = widget.group;
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleJoin() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final nextGroup = _group.joined
          ? await CampusRepository.instance.leaveGroup(_group)
          : await CampusRepository.instance.joinGroup(_group);
      if (!mounted) return;
      setState(() => _group = nextGroup);
      if (nextGroup.membershipStatus == 'pending') {
        _showShellMessage(context, '入群申请已提交，等待管理员审核');
      } else {
        _showShellMessage(
          context,
          nextGroup.joined ? '已加入 ${nextGroup.name}' : '已退出 ${nextGroup.name}',
        );
      }
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String get _buttonLabel {
    if (_isSubmitting) return '处理中';
    if (_group.membershipStatus == 'pending') return '审核中';
    if (_group.joined) return '已加入';
    return '加入';
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CampusAvatar(user: widget.imageUser, size: 46),
      title: Text(widget.name ?? '摄影爱好者联盟'),
      subtitle: Text(widget.subtitle),
      trailing: FilledButton(
        onPressed:
            _group.joined ||
                _group.membershipStatus == 'pending' ||
                _isSubmitting
            ? null
            : _toggleJoin,
        style: FilledButton.styleFrom(
          minimumSize: const Size(66, 34),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(_buttonLabel),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
        );
      },
    );
  }
}

class _MyProfileStat extends StatelessWidget {
  const _MyProfileStat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyShortcut extends StatelessWidget {
  const _MyShortcut({
    required this.icon,
    required this.label,
    this.color = AppColors.blue,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Column(
          children: [
            IconBubble(icon: icon, color: color),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileListRow extends StatelessWidget {
  const _ProfileListRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.orange),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: AppColors.muted)),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _FunctionButton extends StatelessWidget {
  const _FunctionButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 27),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

_ProfileHeaderStats _profileStatsFromBundle(_RealUserProfileBundle bundle) {
  return _ProfileHeaderStats(
    following: bundle.followingCount,
    followers: bundle.followersCount,
    likes: bundle.likesReceivedCount,
    activities: bundle.activities.length,
  );
}

class _ProfileHeaderStats {
  const _ProfileHeaderStats({
    required this.following,
    required this.followers,
    required this.likes,
    required this.activities,
  });

  final int following;
  final int followers;
  final int likes;
  final int activities;
}

_ProfileHeaderStats _profileStatsFor(CampusUser user) {
  final targetId = user.id.trim();
  final targetName = user.name.trim();

  bool isTargetPost(CampusPost post) {
    final authorId = post.author.id.trim();
    final authorName = post.author.name.trim();

    if (targetId.isNotEmpty && authorId.isNotEmpty) {
      return targetId == authorId;
    }

    return targetName.isNotEmpty && authorName == targetName;
  }

  final posts = CampusRepository.instance.cachedFeed.posts
      .where(isTargetPost)
      .toList(growable: false);

  final likes = posts.fold<int>(0, (sum, post) => sum + post.likes);

  final isCurrentUser =
      AuthSession.user != null &&
      ((targetId.isNotEmpty &&
              AuthSession.user!.id.trim().isNotEmpty &&
              targetId == AuthSession.user!.id.trim()) ||
          (targetName.isNotEmpty &&
              targetName == AuthSession.user!.name.trim()));

  final activityCount = isCurrentUser
      ? CampusRepository.instance.cachedFeed.activities.length
      : 0;

  return _ProfileHeaderStats(
    following: user.following,
    followers: user.followers,
    likes: likes,
    activities: activityCount,
  );
}

class _ProfileFollowButton extends StatefulWidget {
  const _ProfileFollowButton({required this.user, this.onChanged});

  final CampusUser user;
  final VoidCallback? onChanged;

  @override
  State<_ProfileFollowButton> createState() => _ProfileFollowButtonState();
}

class _ProfileFollowButtonState extends State<_ProfileFollowButton> {
  late bool _followed = widget.user.followedByMe;
  var _isSubmitting = false;

  bool get _isCurrentUser {
    final authUser = AuthSession.user;
    if (authUser == null) return false;

    final currentId = authUser.id.trim();
    final targetId = widget.user.id.trim();
    if (currentId.isNotEmpty && targetId.isNotEmpty) {
      return currentId == targetId;
    }

    return authUser.name.trim() == widget.user.name.trim();
  }

  @override
  void didUpdateWidget(covariant _ProfileFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.followedByMe != widget.user.followedByMe) {
      _followed = widget.user.followedByMe;
    }
  }

  Future<void> _toggleFollow() async {
    if (_isSubmitting || _isCurrentUser) return;

    setState(() => _isSubmitting = true);
    try {
      final next = _followed
          ? await CampusRepository.instance.unfollowUser(widget.user)
          : await CampusRepository.instance.followUser(widget.user);

      if (!mounted) return;

      setState(() {
        _followed = next.followedByMe;
      });

      widget.onChanged?.call();

      _showShellMessage(context, _followed ? '已关注 ${next.name}' : '已取消关注');
    } catch (error) {
      if (mounted) _showShellMessage(context, _shellError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCurrentUser) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.person_rounded, size: 18),
        label: const Text('本人'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(74, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
    }

    final label = _isSubmitting
        ? '处理中'
        : _followed
        ? '已关注'
        : widget.user.followsMe
        ? '回关'
        : '关注';

    final icon = _isSubmitting
        ? Icons.hourglass_top_rounded
        : _followed
        ? Icons.check_rounded
        : Icons.add;

    return OutlinedButton.icon(
      onPressed: _isSubmitting ? null : _toggleFollow,
      icon: Icon(icon, size: 19),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.blue),
        minimumSize: const Size(82, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}
