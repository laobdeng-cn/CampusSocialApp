from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_replace_user_profile_header_safe_v1")
if not bak.exists():
    bak.write_text(text)

start = text.find("class _UserProfileHeader extends StatelessWidget {")
end = text.find("\nString _profileBioFor", start)

if start == -1:
    raise SystemExit("❌ 没找到 class _UserProfileHeader")
if end == -1:
    raise SystemExit("❌ 没找到 String _profileBioFor，无法确定 header 结束位置")

new_header = r'''class _UserProfileHeader extends StatelessWidget {
  const _UserProfileHeader({
    required this.user,
    this.stats,
    this.onChanged,
  });

  final CampusUser user;
  final _ProfileHeaderStats? stats;
  final VoidCallback? onChanged;

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
    final topInset = MediaQuery.paddingOf(context).top;
    const headerHeight = 306.0;
    const coverHeight = 154.0;
    const panelTop = 118.0;
    const avatarTop = 86.0;
    const avatarSize = 88.0;
    const infoInset = 112.0;
    const sidePadding = 24.0;

    final profileBio = _profileBioFor(user);
    final profileGrade = _profileGradeFor(user);
    final profileClub = _profileClubFor(user);
    final profileStats = stats ?? _profileStatsFor(user);
    final displayId = user.id.trim().isEmpty ? '未生成' : user.id.trim();

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
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 18,
            left: 20,
            right: 18,
            child: Row(
              children: [
                _RoundIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.maybePop(context),
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
            top: panelTop + 18,
            right: sidePadding,
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: '发消息',
                  onPressed: () => _openChat(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.blue.withValues(alpha: 0.1),
                    foregroundColor: AppColors.blue,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                ),
                const SizedBox(width: 8),
                _ProfileFollowButton(user: user, onChanged: onChanged),
              ],
            ),
          ),
          Positioned(
            top: panelTop + 17,
            left: infoInset,
            right: 154,
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
            top: panelTop + 51,
            left: infoInset,
            right: sidePadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ID：$displayId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy_all_outlined, size: 18, color: AppColors.muted),
              ],
            ),
          ),
          Positioned(
            top: panelTop + 78,
            left: infoInset,
            right: sidePadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    profileBio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.wb_sunny_rounded,
                  color: AppColors.orange,
                  size: 16,
                ),
              ],
            ),
          ),
          Positioned(
            top: panelTop + 106,
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

'''

text = text[:start] + new_header + text[end:]

if "class _ProfileHeaderStats" not in text:
    text += r'''

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

  return _ProfileHeaderStats(
    following: user.following,
    followers: user.followers,
    likes: likes,
    activities: 0,
  );
}
'''

if "_ProfileHeaderStats _profileStatsFromBundle" not in text:
    insert_at = text.find("class _ProfileHeaderStats")
    if insert_at != -1:
        text = text[:insert_at] + r'''_ProfileHeaderStats _profileStatsFromBundle(_RealUserProfileBundle bundle) {
  return _ProfileHeaderStats(
    following: bundle.followingCount,
    followers: bundle.followersCount,
    likes: bundle.likesReceivedCount,
    activities: bundle.activities.length,
  );
}

''' + text[insert_at:]

if "class _ProfileFollowButton" not in text:
    text += r'''

class _ProfileFollowButton extends StatefulWidget {
  const _ProfileFollowButton({
    required this.user,
    this.onChanged,
  });

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

      _showShellMessage(
        context,
        _followed ? '已关注 ${next.name}' : '已取消关注',
      );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
'''

MAIN.write_text(text)
print("✅ 已重写 _UserProfileHeader，修复括号结构")
