from pathlib import Path
import re

ROOT = Path.home() / "Desktop" / "CampusSocialApp"
MAIN = ROOT / "frontend/frontend/lib/screens/main_shell.dart"

text = MAIN.read_text()

backup = MAIN.with_name("main_shell.dart.bak_community_manage_entry_v1")
backup.write_text(text)
print(f"✅ 已备份：{backup}")

# 1. 确保 main_shell.dart 能访问 detail_pages.dart 里的 MyManagedGroupsScreen
if "import 'detail_pages.dart';" not in text and 'import "detail_pages.dart";' not in text:
    marker = "import 'activity_feature_pages.dart';"
    if marker in text:
        text = text.replace(marker, marker + "\nimport 'detail_pages.dart';", 1)
        print("✅ 已补充 import detail_pages.dart")
    else:
        print("⚠️ 未找到 activity_feature_pages import，请手动确认 detail_pages.dart 是否已导入")
else:
    print("✅ detail_pages.dart 已导入")

# 2. 将社区页右上角编辑/创建按钮跳转到 MyManagedGroupsScreen
# 兼容几种常见写法：Icons.edit_square_rounded / Icons.edit_rounded / Icons.add_box_rounded 等
patterns = [
    r"""IconButton\(\s*onPressed:\s*\(\)\s*\{[^{}]*Navigator\.push\([^;]+PublishPostScreen\([^;]+;\s*\},\s*icon:\s*const Icon\(Icons\.edit_square_rounded\),\s*\)""",
    r"""IconButton\(\s*onPressed:\s*\(\)\s*\{[^{}]*Navigator\.push\([^;]+PublishPostScreen\([^;]+;\s*\},\s*icon:\s*const Icon\(Icons\.edit_rounded\),\s*\)""",
    r"""IconButton\(\s*onPressed:\s*\(\)\s*\{[^{}]*Navigator\.push\([^;]+PublishPostScreen\([^;]+;\s*\},\s*icon:\s*const Icon\(Icons\.add_box_rounded\),\s*\)""",
]

replacement = """IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyManagedGroupsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: '我管理的社群',
          )"""

changed = False
for pattern in patterns:
    next_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count:
        text = next_text
        changed = True
        print("✅ 已将社区页右上角按钮改为：我管理的社群")
        break

# 3. 如果上面没匹配到，尝试更宽松地定位“社区”页面 appBar actions 里的编辑按钮
if not changed:
    candidates = list(re.finditer(r"IconButton\([\s\S]{0,500}?Icons\.(edit_square_rounded|edit_rounded|add_box_rounded|border_color_rounded)[\s\S]{0,200}?\)", text))
    if candidates:
        m = candidates[0]
        text = text[:m.start()] + replacement + text[m.end():]
        changed = True
        print("✅ 已用宽松匹配替换第一个编辑类 IconButton 为：我管理的社群")
    else:
        print("⚠️ 没找到社区页右上角编辑按钮，请运行下面 grep，把结果发我：")
        print("grep -n \"edit_square_rounded\\|edit_rounded\\|add_box_rounded\\|PublishPostScreen\\|社区\" frontend/frontend/lib/screens/main_shell.dart | head -120")

if changed:
    MAIN.write_text(text)
    print("✅ patch community manage entry v1 done")
else:
    MAIN.write_text(text)
    print("⚠️ 文件未完成按钮替换，但 import/备份已处理")
