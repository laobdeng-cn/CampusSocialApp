from pathlib import Path
import re

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_align_profile_follow_button_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 关注按钮从简介行附近上移到姓名/学校标签同一视觉高度
text = re.sub(
    r"top:\s*panelTop\s*\+\s*\d+,\n\s*right:\s*sidePadding,\n\s*child:\s*_ProfileFollowButton\(user:\s*user,\s*onChanged:\s*onChanged\),",
    "top: panelTop + 24,\n            right: sidePadding,\n            child: _ProfileFollowButton(user: user, onChanged: onChanged),",
    text,
    count=1,
)

# 2. 姓名 + 性别 + 学校标签这一行右侧预留关注按钮宽度，防止挤压/重叠
text = text.replace(
    "top: panelTop + 22,\n            left: infoInset,\n            right: sidePadding,",
    "top: panelTop + 22,\n            left: infoInset,\n            right: 150,",
    1,
)

# 3. 简介行右侧也预留一点，避免和按钮视觉冲突
text = text.replace(
    "top: panelTop + 60,\n            left: infoInset,\n            right: 138,",
    "top: panelTop + 58,\n            left: infoInset,\n            right: 150,",
    1,
)

MAIN.write_text(text)
print("✅ 已将关注按钮上移，并与未认证学校标签行对齐")
