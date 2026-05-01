import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../models/campus_models.dart';
import '../repositories/campus_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/campus_widgets.dart';

const _stageImage = 'asset:assets/images/activity_stage_blue.png';
const _aiImage = 'asset:assets/images/activity_ai_head.png';
const _basketballImage = 'asset:assets/images/activity_basketball_court.png';
const _photoImage = 'asset:assets/images/activity_photo_camera.png';
const _volunteerImage = 'asset:assets/images/activity_volunteer_hands.png';
const _qrImage = 'asset:assets/images/activity_checkin_qr.png';

void _showFeatureMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _featureError(Object error) {
  final text = error.toString();
  const marker = 'CampusApiException: ';
  if (text.startsWith(marker)) return text.substring(marker.length);
  return '操作失败，请确认后端服务已启动';
}

class ActivityAllScreen extends StatelessWidget {
  const ActivityAllScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '全部活动',
      showBottomTabs: true,
      actions: const [
        Icon(Icons.search_rounded, size: 30),
        SizedBox(width: 18),
        Icon(Icons.filter_alt_outlined, size: 28),
        SizedBox(width: 18),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 18),
        children: [
          const _FilterBar(labels: ['全部', '今天', '本周', '文艺', '体育', '讲座', '志愿']),
          const _UnderlineTabs(labels: ['推荐', '最新', '热门', '离我最近']),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final item in _activityItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ActivitySummaryCard(
                      item: item,
                      actionLabel: item.registered ? '已报名' : '报名中',
                      actionOutlined: item.registered,
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

class ActivityCategoriesScreen extends StatelessWidget {
  const ActivityCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '活动分类',
      showBottomTabs: true,
      actions: const [
        Icon(Icons.search_rounded, size: 31),
        SizedBox(width: 18),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: const [
          _CategorySearchBar(),
          SizedBox(height: 18),
          _AllCategoryPanel(),
          SizedBox(height: 16),
          _RecommendedCategoryPanel(),
          SizedBox(height: 16),
          _StatusFilterPanel(),
        ],
      ),
    );
  }
}

class MyRegisteredActivitiesScreen extends StatefulWidget {
  const MyRegisteredActivitiesScreen({super.key});

  @override
  State<MyRegisteredActivitiesScreen> createState() =>
      _MyRegisteredActivitiesScreenState();
}

class _MyRegisteredActivitiesScreenState
    extends State<MyRegisteredActivitiesScreen> {
  late Future<List<CampusActivity>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = CampusRepository.instance.fetchMyActivities();
  }

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '我报名的',
      actions: const [
        Icon(Icons.filter_alt_outlined, size: 29),
        SizedBox(width: 18),
      ],
      child: FutureBuilder<List<CampusActivity>>(
        future: _activitiesFuture,
        builder: (context, snapshot) {
          final remoteItems = (snapshot.data ?? const <CampusActivity>[])
              .map(_ActivityItem.fromActivity)
              .toList(growable: false);
          final items = remoteItems.isNotEmpty
              ? remoteItems
              : [_activityItems[0], _activityItems[1], _activityItems[3]];

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const _FilterBar(labels: ['全部', '进行中', '待开始', '已结束']),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? '正在同步报名活动'
                      : '共 ${items.length} 个报名活动',
                  style: const TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _ActivitySummaryCard(
                        item: items[index],
                        actionLabel: remoteItems.isNotEmpty ? '已报名' : '待参加',
                        actionOutlined: true,
                      ),
                      if (index != items.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Center(
                child: Text('没有更多了', style: TextStyle(color: AppColors.muted)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MyParticipatedActivitiesScreen extends StatefulWidget {
  const MyParticipatedActivitiesScreen({super.key});

  @override
  State<MyParticipatedActivitiesScreen> createState() =>
      _MyParticipatedActivitiesScreenState();
}

class _MyParticipatedActivitiesScreenState
    extends State<MyParticipatedActivitiesScreen> {
  late Future<List<CampusCheckInRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = CampusRepository.instance.fetchCheckInRecords();
  }

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '我参与的',
      actions: const [Icon(Icons.tune_rounded, size: 29), SizedBox(width: 18)],
      child: FutureBuilder<List<CampusCheckInRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          final remoteItems = (snapshot.data ?? const <CampusCheckInRecord>[])
              .map((record) => _ActivityItem.fromActivity(record.activity))
              .toList(growable: false);
          final items = remoteItems.isNotEmpty
              ? remoteItems
              : [_activityItems[0], _activityItems[1], _activityItems[3]];

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const _FilterBar(labels: ['全部', '已签到', '待评价', '已完成']),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _ParticipatedActivityCard(
                        item: items[index],
                        status: remoteItems.isNotEmpty ? '已签到' : '已完成',
                        footer: index.isEven
                            ? const _TwoActionFooter(
                                leftIcon: Icons.image_outlined,
                                leftLabel: '查看照片',
                                rightIcon: Icons.article_outlined,
                                rightLabel: '活动回顾',
                              )
                            : const _CertificateBanner(),
                      ),
                      if (index != items.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FavoriteActivitiesScreen extends StatelessWidget {
  const FavoriteActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '我的收藏',
      showBottomTabs: true,
      actions: const [
        Text(
          '编辑',
          style: TextStyle(
            color: AppColors.blue,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 18),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 18),
        children: [
          const _FilterBar(labels: ['全部', '文艺', '讲座', '体育', '志愿']),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Text(
              '共收藏 12 个活动',
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final item in _activityItems.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FavoriteActivityCard(item: item),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityCalendarScreen extends StatelessWidget {
  const ActivityCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '活动日历',
      actions: const [
        Icon(Icons.calendar_month_outlined, size: 29),
        SizedBox(width: 18),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: const [
          _CalendarPanel(),
          SizedBox(height: 22),
          _TodaySchedule(),
          SizedBox(height: 22),
          _WeekActivities(),
          SizedBox(height: 14),
          _CalendarLegend(),
        ],
      ),
    );
  }
}

class ActivityCheckInScreen extends StatelessWidget {
  const ActivityCheckInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '活动签到',
      actions: const [
        Icon(Icons.event_available_outlined, size: 29),
        SizedBox(width: 18),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          const _CheckInHeroCard(),
          const SizedBox(height: 14),
          const _PasswordCheckInCard(),
          const SizedBox(height: 14),
          const _CheckInRulesCard(),
          const SizedBox(height: 22),
          _SectionHeader(
            title: '我的签到记录',
            action: '全部记录',
            onActionTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckInRecordsScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          const _CheckInRecordList(),
        ],
      ),
    );
  }
}

class CheckInRecordsScreen extends StatefulWidget {
  const CheckInRecordsScreen({super.key});

  @override
  State<CheckInRecordsScreen> createState() => _CheckInRecordsScreenState();
}

class _CheckInRecordsScreenState extends State<CheckInRecordsScreen> {
  late Future<List<CampusCheckInRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = CampusRepository.instance.fetchCheckInRecords();
  }

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '签到记录',
      actions: const [
        Icon(Icons.filter_alt_outlined, size: 30),
        SizedBox(width: 18),
      ],
      child: FutureBuilder<List<CampusCheckInRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          final remoteRecords = (snapshot.data ?? const <CampusCheckInRecord>[])
              .map(_CheckInRecordData.fromRecord)
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
            children: [
              const _CheckInStatsRow(),
              const SizedBox(height: 16),
              const _CheckInRecordFilterBar(),
              const SizedBox(height: 14),
              _FullCheckInRecordList(
                records: remoteRecords.isEmpty ? null : remoteRecords,
              ),
            ],
          );
        },
      ),
    );
  }
}

class ActivityNotificationsScreen extends StatelessWidget {
  const ActivityNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '活动通知',
      actions: const [
        Text(
          '全部已读',
          style: TextStyle(
            color: AppColors.blue,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 18),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _FilterBar(labels: ['全部', '报名', '提醒', '变更']),
          const SizedBox(height: 10),
          const ColoredBox(
            color: AppColors.surface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: Column(
                children: [
                  _NotificationCard(
                    icon: Icons.event_available_rounded,
                    color: AppColors.green,
                    title: '报名成功',
                    body: '你已成功报名「AI 未来发展趋势讲座」',
                    time: '2分钟前',
                  ),
                  _NotificationCard(
                    icon: Icons.notifications_none_rounded,
                    color: AppColors.blue,
                    title: '活动提醒',
                    body: '「校园篮球友谊赛」即将开始',
                    time: '30分钟前',
                  ),
                  _NotificationCard(
                    icon: Icons.error_outline_rounded,
                    color: AppColors.orange,
                    title: '活动变更',
                    body: '「摄影社团采风活动」时间调整通知',
                    time: '1小时前',
                  ),
                  _NotificationCard(
                    icon: Icons.block_rounded,
                    color: AppColors.red,
                    title: '活动取消',
                    body: '「校园音乐之夜」活动已取消',
                    time: '昨天 20:15',
                  ),
                  _NotificationCard(
                    icon: Icons.groups_rounded,
                    color: AppColors.purple,
                    title: '候补成功',
                    body: '你已候补成功「AI 未来发展趋势讲座」名额，欢迎参加！',
                    time: '昨天 18:32',
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 22),
                    child: Text(
                      '已加载全部通知',
                      style: TextStyle(color: AppColors.muted),
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

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  bool allowComments = true;
  bool publicDisplay = true;

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: '发起活动',
      actions: const [
        Text(
          '发布',
          style: TextStyle(
            color: AppColors.blue,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 18),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          const _CoverUploadCard(),
          const SizedBox(height: 12),
          const _CreateFormMainCard(),
          const SizedBox(height: 12),
          const _CreateDescriptionCard(),
          const SizedBox(height: 12),
          _SwitchSettingsCard(
            allowComments: allowComments,
            publicDisplay: publicDisplay,
            onCommentsChanged: (value) => setState(() => allowComments = value),
            onPublicChanged: (value) => setState(() => publicDisplay = value),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '预览并发布',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureScaffold extends StatelessWidget {
  const _FeatureScaffold({
    required this.title,
    required this.child,
    this.actions = const [],
    this.showBottomTabs = false,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool showBottomTabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 25),
        ),
        title: Text(title),
        actions: actions,
      ),
      body: child,
      bottomNavigationBar: showBottomTabs
          ? BottomTabs(
              currentIndex: 1,
              onTap: (index) => navigateToTab(context, index),
            )
          : null,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 0, 14),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return _FilterChip(label: labels[index], selected: index == 0);
          },
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemCount: labels.length,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : const Color(0xFFF0F2F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.text,
          fontSize: 15,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _CategorySearchBar extends StatelessWidget {
  const _CategorySearchBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(23),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, color: AppColors.muted, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '搜索活动、关键词或分类',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.filter_alt_outlined, color: AppColors.muted, size: 25),
        const SizedBox(width: 5),
        const Text(
          '筛选',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AllCategoryPanel extends StatelessWidget {
  const _AllCategoryPanel();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '全部分类',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            itemCount: _categoryItems.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: 86,
            ),
            itemBuilder: (context, index) {
              return _CategoryIconTile(item: _categoryItems[index]);
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryIconTile extends StatelessWidget {
  const _CategoryIconTile({required this.item});

  final _CategoryItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.icon, color: item.color, size: 36),
        const SizedBox(height: 10),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RecommendedCategoryPanel extends StatelessWidget {
  const _RecommendedCategoryPanel();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                '推荐分类',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              Text(
                '查看全部',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < _recommendedCategories.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == _recommendedCategories.length - 1 ? 0 : 10,
              ),
              child: _RecommendedCategoryRow(
                item: _recommendedCategories[index],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecommendedCategoryRow extends StatelessWidget {
  const _RecommendedCategoryRow({required this.item});

  final _RecommendedCategory item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            item.color.withValues(alpha: 0.13),
            item.color.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: item.color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
        ],
      ),
    );
  }
}

class _StatusFilterPanel extends StatelessWidget {
  const _StatusFilterPanel();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '按状态筛选',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FilterChip(label: '全部', selected: true),
              _FilterChip(label: '可报名'),
              _FilterChip(label: '进行中'),
              _FilterChip(label: '已结束'),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnderlineTabs extends StatelessWidget {
  const _UnderlineTabs({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: index == 0 ? AppColors.blue : AppColors.muted,
                      fontSize: 15,
                      fontWeight: index == 0
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 22,
                    height: 3,
                    decoration: BoxDecoration(
                      color: index == 0 ? AppColors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
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

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.item,
    this.actionLabel,
    this.actionOutlined = false,
    this.showFavorite = false,
    this.collectDate,
  });

  final _ActivityItem item;
  final String? actionLabel;
  final bool actionOutlined;
  final bool showFavorite;
  final String? collectDate;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartImage(
                url: item.imageUrl,
                width: 116,
                height: 116,
                borderRadius: 8,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (showFavorite)
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB000),
                            size: 32,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _TagWrap(tags: item.tags),
                    const SizedBox(height: 9),
                    _MetaLine(
                      icon: Icons.schedule_rounded,
                      label: '${item.date}  ${item.time}',
                    ),
                    const SizedBox(height: 6),
                    _MetaLine(
                      icon: Icons.location_on_outlined,
                      label: item.location,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        AvatarStack(users: item.guests, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.people}人已报名',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && collectDate == null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  height: 116,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: _ActionButton(
                      label: actionLabel!,
                      color: AppColors.blue,
                      outlined: actionOutlined,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (collectDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (collectDate != null)
                  Text(
                    collectDate!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                const Spacer(),
                if (actionLabel != null)
                  _ActionButton(
                    label: actionLabel!,
                    color: AppColors.blue,
                    outlined: actionOutlined,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipatedActivityCard extends StatelessWidget {
  const _ParticipatedActivityCard({
    required this.item,
    required this.status,
    required this.footer,
  });

  final _ActivityItem item;
  final String status;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartImage(
                url: item.imageUrl,
                width: 116,
                height: 116,
                borderRadius: 8,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _StatusChip(label: status, color: AppColors.green),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _TagWrap(tags: item.tags),
                    const SizedBox(height: 9),
                    _MetaLine(
                      icon: Icons.schedule_rounded,
                      label: '${item.date}  ${item.time}',
                    ),
                    const SizedBox(height: 6),
                    _MetaLine(
                      icon: Icons.location_on_outlined,
                      label: item.location,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        AvatarStack(users: item.guests, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.people}人已参与',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          footer,
        ],
      ),
    );
  }
}

class _FavoriteActivityCard extends StatelessWidget {
  const _FavoriteActivityCard({required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return _ActivitySummaryCard(
      item: item,
      showFavorite: true,
      collectDate: '收藏于 5月20日',
      actionLabel: item.registered ? '查看详情' : '提醒我',
      actionOutlined: !item.registered,
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.tags});

  final List<_ActivityTagData> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 5,
      children: [
        for (final tag in tags) _SmallTag(label: tag.label, color: tag.color),
      ],
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.text),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: outlined ? Colors.white : color,
        borderRadius: BorderRadius.circular(18),
        border: outlined ? Border.all(color: color) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: outlined ? color : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TwoActionFooter extends StatelessWidget {
  const _TwoActionFooter({
    required this.leftIcon,
    required this.leftLabel,
    required this.rightIcon,
    required this.rightLabel,
  });

  final IconData leftIcon;
  final String leftLabel;
  final IconData rightIcon;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FooterAction(icon: leftIcon, label: leftLabel),
          ),
          const VerticalDivider(),
          Expanded(
            child: _FooterAction(icon: rightIcon, label: rightLabel),
          ),
        ],
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.text, size: 21),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CertificateBanner extends StatelessWidget {
  const _CertificateBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.green.withValues(alpha: 0.1), Colors.white],
        ),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.green,
            size: 43,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '恭喜你完成本次活动！',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '感谢你的参与，期待下次再见～',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const _ActionButton(
            label: '电子证书',
            color: AppColors.text,
            outlined: true,
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 39),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  time,
                  style: const TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: AppColors.blue,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInHeroCard extends StatelessWidget {
  const _CheckInHeroCard();

  @override
  Widget build(BuildContext context) {
    final item = _activityItems[0];

    return CampusCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartImage(
                url: item.imageUrl,
                width: 118,
                height: 118,
                borderRadius: 8,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SmallTag(label: '今天', color: AppColors.blue),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MetaLine(
                      icon: Icons.schedule_rounded,
                      label: '${item.date} ${item.time}',
                    ),
                    const SizedBox(height: 8),
                    _MetaLine(
                      icon: Icons.location_on_outlined,
                      label: item.location,
                    ),
                    const SizedBox(height: 8),
                    _MetaLine(
                      icon: Icons.groups_2_outlined,
                      label: '${item.people}人已报名',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(),
          ),
          Row(
            children: [
              SmartImage(
                url: _qrImage,
                width: 106,
                height: 106,
                borderRadius: 8,
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '签到二维码',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '请在活动现场出示二维码给工作人员扫码',
                      style: TextStyle(color: AppColors.text, fontSize: 14),
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: AppColors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '点击刷新二维码',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BigOutlineButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: '扫码签到',
                  filled: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigOutlineButton(
                  icon: Icons.format_list_bulleted_rounded,
                  label: '签到记录',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CheckInRecordsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigOutlineButton extends StatelessWidget {
  const _BigOutlineButton({
    required this.icon,
    required this.label,
    this.filled = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.blue : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.blue),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: filled ? Colors.white : AppColors.blue,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : AppColors.blue,
                  fontSize: 16,
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

class _PasswordCheckInCard extends StatefulWidget {
  const _PasswordCheckInCard();

  @override
  State<_PasswordCheckInCard> createState() => _PasswordCheckInCardState();
}

class _PasswordCheckInCardState extends State<_PasswordCheckInCard> {
  final _codeController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showFeatureMessage(context, '请输入签到口令');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final record = await CampusRepository.instance.checkInWithCode(
        code: code,
      );
      if (!mounted) return;
      _showFeatureMessage(context, '${record.activity.title} 签到成功');
    } catch (error) {
      if (mounted) _showFeatureMessage(context, _featureError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PasswordCheckInIcon(),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '签到口令',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '如无法扫码，可输入活动口令完成签到',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _codeController,
                    onSubmitted: (_) => _submit(),
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '请输入签到口令',
                      hintStyle: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFB8C2D1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.blue,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 116,
                height: 46,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    _isSubmitting ? '签到中' : '口令签到',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '示例： MUSIC2026  ·  口令由现场工作人员公布',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PasswordCheckInIcon extends StatelessWidget {
  const _PasswordCheckInIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E8BFF), AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.lock_outline_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class _CheckInRulesCard extends StatelessWidget {
  const _CheckInRulesCard();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.article_rounded, color: AppColors.blue, size: 24),
              SizedBox(width: 10),
              Text(
                '签到说明',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          _BulletText('请在活动开始后30分钟内完成签到，逾期将无法签到'),
          _BulletText('签到二维码仅限本人使用，不可转让或代签'),
          _BulletText('如遇问题，请联系现场工作人员或活动负责人'),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '•  $text',
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onActionTap});

  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (action != null) ...[
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onActionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckInStatsRow extends StatelessWidget {
  const _CheckInStatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _CheckInStatCard(
            icon: Icons.event_available_rounded,
            label: '全部',
            value: '12',
            color: AppColors.blue,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _CheckInStatCard(
            icon: Icons.check_rounded,
            label: '已签到',
            value: '4',
            color: AppColors.green,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _CheckInStatCard(
            icon: Icons.check_circle_rounded,
            label: '已完成',
            value: '8',
            color: AppColors.green,
          ),
        ),
      ],
    );
  }
}

class _CheckInStatCard extends StatelessWidget {
  const _CheckInStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.75), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1,
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

class _CheckInRecordFilterBar extends StatelessWidget {
  const _CheckInRecordFilterBar();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(10),
      child: const Row(
        children: [
          Expanded(child: _RecordFilterChip(label: '全部', selected: true)),
          SizedBox(width: 10),
          Expanded(child: _RecordFilterChip(label: '已签到')),
          SizedBox(width: 10),
          Expanded(child: _RecordFilterChip(label: '已完成')),
          SizedBox(width: 10),
          Expanded(child: _RecordFilterChip(label: '未签到')),
        ],
      ),
    );
  }
}

class _RecordFilterChip extends StatelessWidget {
  const _RecordFilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: selected ? null : Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FullCheckInRecordList extends StatelessWidget {
  const _FullCheckInRecordList({this.records});

  final List<_CheckInRecordData>? records;

  @override
  Widget build(BuildContext context) {
    final items = records ?? _fullCheckInRecords;

    return Column(
      children: [
        for (final record in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FullCheckInRecordTile(record: record),
          ),
      ],
    );
  }
}

class _FullCheckInRecordTile extends StatelessWidget {
  const _FullCheckInRecordTile({required this.record});

  final _CheckInRecordData record;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SmartImage(
            url: record.imageUrl,
            width: 82,
            height: 74,
            borderRadius: 8,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _MetaLine(icon: Icons.schedule_rounded, label: record.time),
                const SizedBox(height: 5),
                _MetaLine(
                  icon: Icons.location_on_outlined,
                  label: record.location,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ActionButton(
            label: record.status,
            color: AppColors.green,
            outlined: true,
          ),
        ],
      ),
    );
  }
}

class _CheckInRecordList extends StatefulWidget {
  const _CheckInRecordList();

  @override
  State<_CheckInRecordList> createState() => _CheckInRecordListState();
}

class _CheckInRecordListState extends State<_CheckInRecordList> {
  late Future<List<CampusCheckInRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = CampusRepository.instance.fetchCheckInRecords();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusCheckInRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        final remoteItems = (snapshot.data ?? const <CampusCheckInRecord>[])
            .map((record) => _ActivityItem.fromActivity(record.activity))
            .toList(growable: false);
        final records = remoteItems.isNotEmpty
            ? remoteItems
            : [_activityItems[1], _activityItems[2], _activityItems[3]];

        return Column(
          children: [
            for (var index = 0; index < records.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CheckInRecordTile(
                  item: records[index],
                  status: remoteItems.isNotEmpty || index == 0 ? '已签到' : '已完成',
                  time: remoteItems.isNotEmpty
                      ? '${records[index].date} ${records[index].time} 签到'
                      : [
                          '05.25 周日 14:05 签到',
                          '05.20 周二 18:45 签到',
                          '05.18 周日 09:10 签到',
                        ][index],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CheckInRecordTile extends StatelessWidget {
  const _CheckInRecordTile({
    required this.item,
    required this.status,
    required this.time,
  });

  final _ActivityItem item;
  final String status;
  final String time;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SmartImage(
            url: item.imageUrl,
            width: 70,
            height: 62,
            borderRadius: 6,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                _MetaLine(icon: Icons.schedule_rounded, label: time),
                const SizedBox(height: 5),
                _MetaLine(
                  icon: Icons.location_on_outlined,
                  label: item.location,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ActionButton(label: status, color: AppColors.green, outlined: true),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.chevron_left_rounded, size: 32),
              Expanded(
                child: Center(
                  child: Text(
                    '2025年5月',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 32),
            ],
          ),
          const SizedBox(height: 18),
          const _WeekdayHeader(),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _calendarCells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemBuilder: (context, index) {
              return _CalendarDayCell(cell: _calendarCells[index]);
            },
          ),
          const Divider(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.purple, label: '文艺'),
              SizedBox(width: 26),
              _LegendDot(color: AppColors.green, label: '体育'),
              SizedBox(width: 26),
              _LegendDot(color: AppColors.blue, label: '讲座'),
              SizedBox(width: 26),
              _LegendDot(color: AppColors.orange, label: '志愿'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in const ['日', '一', '二', '三', '四', '五', '六'])
          Expanded(
            child: Center(
              child: Text(
                day,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.cell});

  final _CalendarCellData cell;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 31,
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cell.selected ? AppColors.blue : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            cell.label,
            style: TextStyle(
              color: cell.selected
                  ? Colors.white
                  : cell.muted
                  ? const Color(0xFFC4CBD5)
                  : AppColors.ink,
              fontSize: 16,
              fontWeight: cell.selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final dot in cell.dots)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodaySchedule extends StatelessWidget {
  const _TodaySchedule();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SectionHeader(title: '今日安排', action: '共 3 项活动'),
        const SizedBox(height: 10),
        CampusCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            children: [
              _ScheduleTile(
                item: _activityItems[3],
                start: '09:00',
                end: '12:00',
                lineColor: AppColors.purple,
              ),
              const Divider(),
              _ScheduleTile(
                item: _activityItems[4],
                start: '13:30',
                end: '17:00',
                lineColor: AppColors.orange,
              ),
              const Divider(),
              _ScheduleTile(
                item: _activityItems[0],
                start: '19:00',
                end: '21:30',
                lineColor: AppColors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.item,
    required this.start,
    required this.end,
    required this.lineColor,
  });

  final _ActivityItem item;
  final String start;
  final String end;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 3, height: 42, color: lineColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Text(
                  start,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(end, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SmartImage(
            url: item.imageUrl,
            width: 58,
            height: 58,
            borderRadius: 6,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                _TagWrap(tags: item.tags),
                const SizedBox(height: 5),
                _MetaLine(
                  icon: Icons.location_on_outlined,
                  label: item.location,
                ),
              ],
            ),
          ),
          _ActionButton(
            label: item.registered ? '已报名' : '报名中',
            color: item.registered ? AppColors.green : AppColors.blue,
            outlined: item.registered,
          ),
        ],
      ),
    );
  }
}

class _WeekActivities extends StatelessWidget {
  const _WeekActivities();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SectionHeader(title: '本周活动', action: '5.27 - 6.2'),
        const SizedBox(height: 10),
        CampusCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _WeekActivityTile(
                item: _activityItems[1],
                date: '05.28',
                week: '周三',
              ),
              const Divider(),
              _WeekActivityTile(
                item: _activityItems[2],
                date: '05.30',
                week: '周五',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekActivityTile extends StatelessWidget {
  const _WeekActivityTile({
    required this.item,
    required this.date,
    required this.week,
  });

  final _ActivityItem item;
  final String date;
  final String week;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(week, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            height: 54,
            child: VerticalDivider(color: AppColors.line),
          ),
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  item.time.split('-').first,
                  style: const TextStyle(color: AppColors.ink, fontSize: 15),
                ),
                const SizedBox(height: 7),
                Text(
                  item.time.split('-').last,
                  style: const TextStyle(color: AppColors.text, fontSize: 15),
                ),
              ],
            ),
          ),
          SmartImage(
            url: item.imageUrl,
            width: 70,
            height: 62,
            borderRadius: 6,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _TagWrap(tags: item.tags),
                const SizedBox(height: 5),
                _MetaLine(
                  icon: Icons.location_on_outlined,
                  label: item.location,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            label: item.registered ? '已报名' : '报名中',
            color: item.registered ? AppColors.green : AppColors.blue,
            outlined: item.registered,
          ),
        ],
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: const [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 20),
              SizedBox(width: 7),
              Text('图例说明', style: TextStyle(color: AppColors.text)),
            ],
          ),
          _LegendDot(color: AppColors.purple, label: '文艺：演出、展览、社团活动等'),
          _LegendDot(color: AppColors.green, label: '体育：比赛、健身、户外活动等'),
          _LegendDot(color: AppColors.blue, label: '讲座：学术、科技、分享会等'),
          _LegendDot(color: AppColors.orange, label: '志愿：公益、志愿服务等'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
      ],
    );
  }
}

class _CoverUploadCard extends StatelessWidget {
  const _CoverUploadCard();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '活动封面',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '建议尺寸 16:9，JPG/PNG，\n不超过 5MB',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 150,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFD),
              border: Border.all(
                color: const Color(0xFFD9DFEA),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.blue,
                  size: 34,
                ),
                SizedBox(height: 8),
                Text('上传封面', style: TextStyle(color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateFormMainCard extends StatelessWidget {
  const _CreateFormMainCard();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: const [
          _FormRow(label: '活动名称', hint: '请输入活动名称（2-30字）', required: true),
          Divider(),
          _CategoryFormRow(),
          Divider(),
          _FormRow(
            label: '开始时间',
            hint: '选择开始时间',
            icon: Icons.schedule_rounded,
            required: true,
            trailing: Icons.chevron_right_rounded,
          ),
          Divider(),
          _FormRow(
            label: '结束时间',
            hint: '选择结束时间',
            icon: Icons.schedule_rounded,
            required: true,
            trailing: Icons.chevron_right_rounded,
          ),
          Divider(),
          _FormRow(
            label: '活动地点',
            hint: '请输入详细地点',
            icon: Icons.location_on_outlined,
            required: true,
            trailing: Icons.map_outlined,
          ),
          Divider(),
          _FormRow(
            label: '人数上限',
            hint: '请输入人数上限',
            icon: Icons.groups_2_outlined,
            required: true,
            suffix: '人',
          ),
          Divider(),
          _FormRow(
            label: '费用',
            hint: '免费或输入费用',
            icon: Icons.currency_yen_rounded,
            suffix: '元',
          ),
          Divider(),
          _FormRow(
            label: '主办方',
            hint: '请输入主办方名称',
            icon: Icons.apartment_rounded,
            required: true,
            trailing: Icons.chevron_right_rounded,
          ),
        ],
      ),
    );
  }
}

class _CategoryFormRow extends StatelessWidget {
  const _CategoryFormRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          const _FormLabel(label: '活动分类', required: true),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 8,
              children: const [
                _FormCategoryChip(label: '文艺', selected: true),
                _FormCategoryChip(label: '体育'),
                _FormCategoryChip(label: '讲座'),
                _FormCategoryChip(label: '志愿'),
                _FormCategoryChip(label: '社团'),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.text),
        ],
      ),
    );
  }
}

class _FormCategoryChip extends StatelessWidget {
  const _FormCategoryChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : Colors.white,
        border: Border.all(color: selected ? AppColors.blue : AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.label,
    required this.hint,
    this.icon,
    this.required = false,
    this.trailing,
    this.suffix,
  });

  final String label;
  final String hint;
  final IconData? icon;
  final bool required;
  final IconData? trailing;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          _FormLabel(label: label, required: required),
          const SizedBox(width: 14),
          if (icon != null) ...[
            Icon(icon, color: AppColors.blue, size: 21),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFADB5C2), fontSize: 15),
            ),
          ),
          if (suffix != null)
            Text(
              suffix!,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
            ),
          if (trailing != null) Icon(trailing, color: AppColors.text, size: 25),
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Row(
        children: [
          if (required)
            const Text(
              '* ',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.w900,
              ),
            ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateDescriptionCard extends StatelessWidget {
  const _CreateDescriptionCard();

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FormLabel(label: '活动简介', required: true),
                const SizedBox(height: 10),
                Container(
                  height: 88,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '请输入活动简介，介绍活动内容、亮点与安排等（10-500字）',
                          style: TextStyle(
                            color: Color(0xFFADB5C2),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          '0/500',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const _FormRow(
            label: '亮点标签',
            hint: '选择活动亮点标签（可多选）',
            icon: Icons.sell_outlined,
            trailing: Icons.chevron_right_rounded,
          ),
          const Divider(),
          const _FormRow(
            label: '报名截止时间',
            hint: '选择报名截止时间',
            icon: Icons.schedule_rounded,
            trailing: Icons.chevron_right_rounded,
          ),
        ],
      ),
    );
  }
}

class _SwitchSettingsCard extends StatelessWidget {
  const _SwitchSettingsCard({
    required this.allowComments,
    required this.publicDisplay,
    required this.onCommentsChanged,
    required this.onPublicChanged,
  });

  final bool allowComments;
  final bool publicDisplay;
  final ValueChanged<bool> onCommentsChanged;
  final ValueChanged<bool> onPublicChanged;

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SwitchRow(
            title: '允许评论',
            subtitle: '开启后，参与者可在活动页面发表评论',
            value: allowComments,
            onChanged: onCommentsChanged,
          ),
          const Divider(),
          _SwitchRow(
            title: '公开展示',
            subtitle: '开启后，活动将对全校公开展示',
            value: publicDisplay,
            onChanged: onPublicChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.text, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.blue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _RecommendedCategory {
  const _RecommendedCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.imageUrl,
    required this.tags,
    required this.date,
    required this.time,
    required this.location,
    required this.people,
    required this.guests,
    this.registered = false,
  });

  factory _ActivityItem.fromActivity(CampusActivity activity) {
    return _ActivityItem(
      title: activity.title,
      imageUrl: activity.posterUrl,
      tags: [
        _ActivityTagData(activity.category, AppColors.blue),
        if (activity.highlights.isNotEmpty)
          _ActivityTagData(activity.highlights.first, AppColors.green),
      ],
      date: activity.date,
      time: activity.time,
      location: activity.location,
      people: activity.enrolled,
      guests: activity.guests,
      registered: true,
    );
  }

  final String title;
  final String imageUrl;
  final List<_ActivityTagData> tags;
  final String date;
  final String time;
  final String location;
  final int people;
  final List<CampusUser> guests;
  final bool registered;
}

class _CheckInRecordData {
  const _CheckInRecordData({
    required this.title,
    required this.imageUrl,
    required this.time,
    required this.location,
    required this.status,
  });

  factory _CheckInRecordData.fromRecord(CampusCheckInRecord record) {
    final activity = record.activity;
    return _CheckInRecordData(
      title: activity.title,
      imageUrl: activity.posterUrl,
      time: '${activity.date} ${activity.time} 签到',
      location: activity.location,
      status: record.status == 'checked_in' ? '已签到' : '已完成',
    );
  }

  final String title;
  final String imageUrl;
  final String time;
  final String location;
  final String status;
}

class _ActivityTagData {
  const _ActivityTagData(this.label, this.color);

  final String label;
  final Color color;
}

class _CalendarCellData {
  const _CalendarCellData(
    this.label, {
    this.muted = false,
    this.selected = false,
    this.dots = const [],
  });

  final String label;
  final bool muted;
  final bool selected;
  final List<Color> dots;
}

const _categoryItems = [
  _CategoryItem(
    label: '社团招新',
    icon: Icons.groups_rounded,
    color: Color(0xFF4F86F7),
  ),
  _CategoryItem(
    label: '讲座论坛',
    icon: Icons.co_present_rounded,
    color: AppColors.orange,
  ),
  _CategoryItem(
    label: '体育赛事',
    icon: Icons.emoji_events_rounded,
    color: AppColors.green,
  ),
  _CategoryItem(
    label: '文艺演出',
    icon: Icons.theater_comedy_rounded,
    color: AppColors.purple,
  ),
  _CategoryItem(
    label: '志愿公益',
    icon: Icons.volunteer_activism_rounded,
    color: AppColors.red,
  ),
  _CategoryItem(
    label: '比赛竞赛',
    icon: Icons.workspace_premium_rounded,
    color: AppColors.blue,
  ),
  _CategoryItem(
    label: '校园服务',
    icon: Icons.apartment_rounded,
    color: Color(0xFF14B8A6),
  ),
  _CategoryItem(
    label: '二手闲置',
    icon: Icons.shopping_bag_rounded,
    color: AppColors.orange,
  ),
  _CategoryItem(
    label: '学习打卡',
    icon: Icons.fact_check_rounded,
    color: AppColors.blue,
  ),
  _CategoryItem(
    label: '校友交流',
    icon: Icons.group_rounded,
    color: AppColors.purple,
  ),
  _CategoryItem(
    label: '创新创业',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.green,
  ),
  _CategoryItem(
    label: '其他分类',
    icon: Icons.grid_view_rounded,
    color: AppColors.muted,
  ),
];

const _recommendedCategories = [
  _RecommendedCategory(
    title: '热门活动',
    subtitle: '全校最受欢迎的活动精选',
    icon: Icons.local_fire_department_rounded,
    color: AppColors.orange,
  ),
  _RecommendedCategory(
    title: '本周精选',
    subtitle: '本周值得参加的优质活动',
    icon: Icons.star_rounded,
    color: Color(0xFF5B8DFF),
  ),
  _RecommendedCategory(
    title: '最新发布',
    subtitle: '最近发布的新活动速览',
    icon: Icons.fiber_new_rounded,
    color: AppColors.green,
  ),
  _RecommendedCategory(
    title: '即将开始',
    subtitle: '即将开始的活动提前了解',
    icon: Icons.schedule_rounded,
    color: AppColors.purple,
  ),
];

const _activityItems = [
  _ActivityItem(
    title: '校园音乐之夜',
    imageUrl: _stageImage,
    tags: [
      _ActivityTagData('文艺', AppColors.purple),
      _ActivityTagData('校园文化', AppColors.blue),
    ],
    date: '05.24 周六',
    time: '19:00-21:30',
    location: '大学生活动中心大礼堂',
    people: 328,
    registered: false,
    guests: [kexin, zihao, siyu, xiaobei, xiaochen],
  ),
  _ActivityItem(
    title: 'AI 未来发展趋势讲座',
    imageUrl: _aiImage,
    tags: [
      _ActivityTagData('讲座', AppColors.orange),
      _ActivityTagData('科技', AppColors.blue),
    ],
    date: '05.25 周日',
    time: '14:00-16:00',
    location: '图书馆报告厅',
    people: 256,
    registered: false,
    guests: [xiaobei, zihao, kexin, siyu, xiaochen],
  ),
  _ActivityItem(
    title: '校园篮球友谊赛',
    imageUrl: _basketballImage,
    tags: [
      _ActivityTagData('体育', AppColors.green),
      _ActivityTagData('竞技', AppColors.blue),
    ],
    date: '05.26 周一',
    time: '18:30-20:30',
    location: '东区篮球场',
    people: 192,
    registered: true,
    guests: [zihao, siyu, xiaobei, kexin, xiaochen],
  ),
  _ActivityItem(
    title: '摄影社团采风活动',
    imageUrl: _photoImage,
    tags: [
      _ActivityTagData('文艺', AppColors.purple),
      _ActivityTagData('社团', AppColors.blue),
    ],
    date: '05.27 周二',
    time: '09:00-12:00',
    location: '南山植物园',
    people: 78,
    registered: false,
    guests: [kexin, zihao, xiaobei, siyu, xiaochen],
  ),
  _ActivityItem(
    title: '志愿者在行动',
    imageUrl: _volunteerImage,
    tags: [
      _ActivityTagData('志愿', AppColors.red),
      _ActivityTagData('公益', AppColors.green),
    ],
    date: '05.28 周三',
    time: '13:30-17:00',
    location: '校外社区服务中心',
    people: 163,
    registered: false,
    guests: [kexin, siyu, xiaobei, xiaochen, zihao],
  ),
];

const _fullCheckInRecords = [
  _CheckInRecordData(
    title: 'AI 未来发展趋势讲座',
    imageUrl: _aiImage,
    time: '05.25 周日 14:05 签到',
    location: '图书馆报告厅',
    status: '已签到',
  ),
  _CheckInRecordData(
    title: '校园篮球友谊赛',
    imageUrl: _basketballImage,
    time: '05.20 周二 18:45 签到',
    location: '东区篮球场',
    status: '已完成',
  ),
  _CheckInRecordData(
    title: '摄影社团采风活动',
    imageUrl: _photoImage,
    time: '05.18 周日 09:10 签到',
    location: '南山植物园',
    status: '已完成',
  ),
  _CheckInRecordData(
    title: '志愿者在行动',
    imageUrl: _volunteerImage,
    time: '05.12 周一 13:35 签到',
    location: '校外社区服务中心',
    status: '已完成',
  ),
  _CheckInRecordData(
    title: '校园歌手大赛',
    imageUrl: _stageImage,
    time: '05.08 周四 19:20 签到',
    location: '大学生活动中心',
    status: '已完成',
  ),
  _CheckInRecordData(
    title: '创新创业分享会',
    imageUrl:
        'https://images.unsplash.com/photo-1560439514-4e9645039924?auto=format&fit=crop&w=600&q=80',
    time: '05.03 周六 15:00 签到',
    location: '经管楼 201',
    status: '已签到',
  ),
];

const _calendarCells = [
  _CalendarCellData('27', muted: true),
  _CalendarCellData('28', muted: true),
  _CalendarCellData('29', muted: true),
  _CalendarCellData('30', muted: true),
  _CalendarCellData('1', dots: [AppColors.orange]),
  _CalendarCellData('2', dots: [AppColors.blue]),
  _CalendarCellData('3', dots: [AppColors.green]),
  _CalendarCellData('4', dots: [AppColors.purple, AppColors.orange]),
  _CalendarCellData('5', dots: [AppColors.blue]),
  _CalendarCellData('6'),
  _CalendarCellData('7', dots: [AppColors.green]),
  _CalendarCellData('8', dots: [AppColors.blue, AppColors.orange]),
  _CalendarCellData('9'),
  _CalendarCellData('10', dots: [AppColors.green]),
  _CalendarCellData('11', dots: [AppColors.purple]),
  _CalendarCellData('12', dots: [AppColors.blue]),
  _CalendarCellData('13', dots: [AppColors.orange]),
  _CalendarCellData('14', dots: [AppColors.green]),
  _CalendarCellData('15', dots: [AppColors.blue]),
  _CalendarCellData('16'),
  _CalendarCellData('17', dots: [AppColors.purple]),
  _CalendarCellData('18', dots: [AppColors.green]),
  _CalendarCellData('19', dots: [AppColors.blue, AppColors.purple]),
  _CalendarCellData('20'),
  _CalendarCellData('21', dots: [AppColors.orange]),
  _CalendarCellData('22', dots: [AppColors.blue]),
  _CalendarCellData('23'),
  _CalendarCellData('24', dots: [AppColors.green, AppColors.orange]),
  _CalendarCellData('25', dots: [AppColors.purple]),
  _CalendarCellData('26', dots: [AppColors.blue]),
  _CalendarCellData(
    '27',
    selected: true,
    dots: [AppColors.blue, AppColors.green, AppColors.orange, AppColors.purple],
  ),
  _CalendarCellData('28'),
  _CalendarCellData('29', dots: [AppColors.blue]),
  _CalendarCellData('30'),
  _CalendarCellData('31', dots: [AppColors.green]),
];
