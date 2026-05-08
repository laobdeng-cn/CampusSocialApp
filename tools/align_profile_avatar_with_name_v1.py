from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_align_profile_avatar_with_name_v1")
if not bak.exists():
    bak.write_text(text)

replacements = {
    # 头像原来太靠上，这里下移到资料白色面板内，和姓名行视觉对齐
    "const avatarTop = 96.0;": "const avatarTop = 128.0;",
    # 头像稍微缩小，减少突兀感
    "const avatarSize = 78.0;": "const avatarSize = 68.0;",
    # 姓名左侧位置微调，和缩小后的头像保持合适间距
    "const infoInset = 106.0;": "const infoInset = 104.0;",
}

changed = 0
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new, 1)
        changed += 1
    else:
        print(f"⚠️ 没找到：{old}")

MAIN.write_text(text)
print(f"✅ 已调整头像与姓名对齐，共修改 {changed} 处")
