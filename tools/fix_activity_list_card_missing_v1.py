from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

if "class ActivityListCard extends StatelessWidget" in text:
    print("ℹ️ ActivityListCard 已存在，跳过")
else:
    marker = "\nclass _ActivityTag extends StatelessWidget"
    if marker not in text:
        raise SystemExit("❌ 没找到 _ActivityTag 插入点，请把 880-930 行发我")

    component = r'''
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
      MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: activity)),
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
            SmartImage(
              url: activity.posterUrl,
              width: 92,
              height: 72,
              radius: 16,
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

'''
    text = text.replace(marker, "\n" + component + marker, 1)
    MAIN.write_text(text)
    print("✅ 已补充 ActivityListCard 组件")
