from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_profile_header_follow_stats_v2")
if not bak.exists():
    bak.write_text(text)

# 1. _UserProfileHeader 构造增加 stats / onChanged
text = text.replace(
    "const _UserProfileHeader({required this.user});",
    "const _UserProfileHeader({required this.user, this.stats, this.onChanged});",
    1,
)

text = text.replace(
    "final CampusUser user;\n\n  Future<void> _openChat",
    "final CampusUser user;\n  final _ProfileHeaderStats? stats;\n  final VoidCallback? onChanged;\n\n  Future<void> _openChat",
    1,
)

# 2. build 内 stats 优先用外部传入的真实 bundle 统计
text = text.replace(
    "final profileStats = _profileStatsFor(user);",
    "final profileStats = stats ?? _profileStatsFor(user);",
    1,
)

# 3. UserProfileScreen 中调用 _UserProfileHeader 时传入 bundle 统计
# 自动识别 FutureBuilder 里 snapshot.data 的变量名
bundle_var = None
m = re.search(r"final\s+(\w+)\s*=\s*snapshot\.data\s*\?\?", text)
if m:
    bundle_var = m.group(1)

if bundle_var:
    pattern = re.compile(
        r"_UserProfileHeader\(\s*user:\s*([^,\n\)]+),\s*\)",
        re.S,
    )

    def repl(match):
        user_expr = match.group(1).strip()
        if "stats:" in match.group(0):
            return match.group(0)
        return (
            "_UserProfileHeader(\n"
            f"                  user: {user_expr},\n"
            f"                  stats: _profileStatsFromBundle({bundle_var}),\n"
            "                  onChanged: _refresh,\n"
            "                )"
        )

    text, count = pattern.subn(repl, text, count=1)
    print(f"✅ 已给 _UserProfileHeader 传入真实统计：{count}")
else:
    print("⚠️ 没识别到 bundle 变量，稍后如有 error 把 UserProfileScreen build 发我")

# 4. 把固定 ID 改成真实 id
text = text.replace(
    "const Positioned(\n            top: panelTop + 51,",
    "Positioned(\n            top: panelTop + 51,",
    1,
)

text = text.replace(
    "child: Row(\n              children: [\n                Text(\n                  'ID：1029384756',",
    "child: Row(\n              children: [\n                Text(\n                  'ID：${user.id.trim().isEmpty ? '未生成' : user.id.trim()}',",
    1,
)

# 如果上面由于格式差异没命中，单独兜底
text = text.replace(
    "'ID：1029384756'",
    "'ID：${user.id.trim().isEmpty ? '未生成' : user.id.trim()}'",
    1,
)

# 5. 关注按钮区域替换为真实联动组件
follow_button_pattern = re.compile(
    r"""OutlinedButton\.icon\(
\s*onPressed:\s*\(\)\s*\{\},
\s*icon:\s*const Icon\(Icons\.add,\s*size:\s*19\),
\s*label:\s*const Text\('关注'\),
\s*style:\s*OutlinedButton\.styleFrom\(
.*?
\s*\),
\s*\)""",
    re.S,
)

text, follow_count = follow_button_pattern.subn(
    "_ProfileFollowButton(user: user, onChanged: onChanged)",
    text,
    count=1,
)
print(f"✅ 已替换关注按钮：{follow_count}")

# 6. 去掉陈可欣等特殊假简介逻辑
text = re.sub(
    r"""String _profileBioFor\(CampusUser user\) \{
.*?
\}

String _profileGradeFor""",
    """String _profileBioFor(CampusUser user) {
  final bio = user.bio.trim();
  return bio.isEmpty ? '这个同学还没有填写简介。' : bio;
}

String _profileGradeFor""",
    text,
    count=1,
    flags=re.S,
)

text = re.sub(
    r"""String _profileGradeFor\(CampusUser user\) \{
.*?
\}

String _profileClubFor""",
    """String _profileGradeFor(CampusUser user) {
  final grade = user.grade.trim();
  return grade.isEmpty ? '未填写年级' : grade;
}

String _profileClubFor""",
    text,
    count=1,
    flags=re.S,
)

text = re.sub(
    r"""String _profileClubFor\(CampusUser user\) \{
.*?
\}

class _ProfileActivityEntry""",
    """String _profileClubFor(CampusUser user) {
  final role = user.role?.trim() ?? '';
  if (role.isNotEmpty) return role;

  final major = user.major.trim();
  return major.isEmpty ? '未填写专业' : major;
}

class _ProfileActivityEntry""",
    text,
    count=1,
    flags=re.S,
)

# 7. 增加 bundle -> stats 转换函数
if "_ProfileHeaderStats _profileStatsFromBundle" not in text:
    insert_pos = text.find("class _ProfileHeaderStats")
    if insert_pos == -1:
        # 如果之前没有 _ProfileHeaderStats，则一起补上
        helper = r'''

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

_ProfileHeaderStats _profileStatsFromBundle(_RealUserProfileBundle bundle) {
  return _ProfileHeaderStats(
    following: bundle.followingCount,
    followers: bundle.followersCount,
    likes: bundle.likesReceivedCount,
    activities: bundle.activities.length,
  );
}

'''
        text += helper
    else:
        helper = r'''_ProfileHeaderStats _profileStatsFromBundle(_RealUserProfileBundle bundle) {
  return _ProfileHeaderStats(
    following: bundle.followingCount,
    followers: bundle.followersCount,
    likes: bundle.likesReceivedCount,
    activities: bundle.activities.length,
  );
}

'''
        text = text[:insert_pos] + helper + text[insert_pos:]
    print("✅ 已新增 _profileStatsFromBundle")
else:
    print("ℹ️ _profileStatsFromBundle 已存在")

# 8. 增加真实关注按钮组件
if "class _ProfileFollowButton" not in text:
    component = r'''

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
    text += component
    print("✅ 已新增 _ProfileFollowButton")
else:
    print("ℹ️ _ProfileFollowButton 已存在")

MAIN.write_text(text)
print("🎉 个人资料页顶部统计 + 关注按钮真实联动 v2 完成")
