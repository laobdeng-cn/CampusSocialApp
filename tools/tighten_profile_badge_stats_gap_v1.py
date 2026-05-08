from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_tighten_profile_badge_stats_gap_v1")
if not bak.exists():
    bak.write_text(text)

replacements = {
    # 缩短整个顶部区域高度，让下面的功能卡片更贴近
    "const headerHeight = 352.0;": "const headerHeight = 326.0;",

    # 认证标签行略微上移一点
    "top: panelTop + 98,": "top: panelTop + 92,",

    # 统计数字行明显上移，减少“待认证”与 0/粉丝/获赞/活动之间的大空白
    "top: panelTop + 168,": "top: panelTop + 132,",
}

changed = 0
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new, 1)
        changed += 1
    else:
        print(f"⚠️ 没找到：{old}")

MAIN.write_text(text)
print(f"✅ 已压缩个人资料页认证标签与统计区间距，共修改 {changed} 处")
