from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_loosen_profile_header_layout_v1")
if not bak.exists():
    bak.write_text(text)

replacements = {
    "const headerHeight = 322.0;": "const headerHeight = 352.0;",
    "const coverHeight = 150.0;": "const coverHeight = 154.0;",
    "const panelTop = 114.0;": "const panelTop = 126.0;",
    "const avatarTop = 86.0;": "const avatarTop = 96.0;",
    "const avatarSize = 84.0;": "const avatarSize = 78.0;",
    "const infoInset = 112.0;": "const infoInset = 106.0;",
}

for old, new in replacements.items():
    text = text.replace(old, new, 1)

# 返回按钮稍微上移，避免压到头像
text = text.replace(
    "top: topInset + 10,",
    "top: topInset + 6,",
    1,
)

# 关注按钮下移，避免和姓名/学校标签挤在一行
text = text.replace(
    "top: panelTop + 30,\n            right: sidePadding,\n            child: _ProfileFollowButton(user: user, onChanged: onChanged),",
    "top: panelTop + 62,\n            right: sidePadding,\n            child: _ProfileFollowButton(user: user, onChanged: onChanged),",
    1,
)

# 姓名行给更多空间，不再预留太大右侧
text = text.replace(
    "top: panelTop + 26,\n            left: infoInset,\n            right: 136,",
    "top: panelTop + 22,\n            left: infoInset,\n            right: sidePadding,",
    1,
)

# 简介行和关注按钮错开，右侧预留按钮宽度
text = text.replace(
    "top: panelTop + 62,\n            left: infoInset,\n            right: sidePadding,\n            child: Text(",
    "top: panelTop + 60,\n            left: infoInset,\n            right: 138,\n            child: Text(",
    1,
)

# 标签行下移
text = text.replace(
    "top: panelTop + 92,",
    "top: panelTop + 98,",
    1,
)

# 统计行下移
text = text.replace(
    "top: panelTop + 142,",
    "top: panelTop + 168,",
    1,
)

MAIN.write_text(text)
print("✅ 已放松个人资料页顶部布局：按钮下移、头像缩小、统计下移")
