from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_use_real_user_profile_header_v1")
if not bak.exists():
    bak.write_text(text)

old = "                _buildHeader(bundle),"
new = """                _UserProfileHeader(
                  user: bundle.user,
                  stats: _profileStatsFromBundle(bundle),
                  onChanged: () {
                    _refresh();
                  },
                ),"""

count = text.count(old)
text = text.replace(old, new, 1)

MAIN.write_text(text)

if count:
    print("✅ 已把个人资料页顶部切换为 _UserProfileHeader，关注按钮会显示")
else:
    print("⚠️ 没找到 _buildHeader(bundle)，可能已经改过")
