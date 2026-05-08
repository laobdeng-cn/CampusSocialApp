from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_profile_header_style_no_id_v1")
if not bak.exists():
    bak.write_text(text)

start = text.find("class _UserProfileHeader extends StatelessWidget {")
end = text.find("\nString _profileBioFor", start)

if start == -1 or end == -1:
    raise SystemExit("❌ 没找到 _UserProfileHeader，请把 6348-6620 行发我")

new_header = r'''class _UserProfileHeader extends StatelessWidget {
  const _UserProfileHeader({required this.user, this.stats, this.onChanged});

  final CampusUser user;
  final _ProfileHeaderStats? stats;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    const headerHeight = 322.0;
    const coverHeight = 150.0;
    const panelTop = 114.0;
    const avatarTop = 86.0;
    const avatarSize = 84.0;
    const infoInset = 112.0;
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
            top: topInset + 10,
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
                _RoundIconButton(icon: Icons.ios_share_rounded, onTap: () {}),
                const SizedBox(width: 12),
                _RoundIconButton(icon: Icons.more_horiz_rounded, onTap: () {}),
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
            top: panelTop + 30,
            right: sidePadding,
            child: _ProfileFollowButton(user: user, onChanged: onChanged),
          ),
          Positioned(
            top: panelTop + 26,
            left: infoInset,
            right: 136,
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
            top: panelTop + 62,
            left: infoInset,
            right: sidePadding,
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
            right: sidePadding,
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
            top: panelTop + 142,
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

'''

text = text[:start] + new_header + text[end:]
MAIN.write_text(text)

print("✅ 已修复个人主页顶部样式：移除 ID 行、恢复返回按钮、保留关注按钮")
