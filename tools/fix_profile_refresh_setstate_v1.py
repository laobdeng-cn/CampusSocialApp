from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_profile_refresh_setstate_v1")
if not bak.exists():
    bak.write_text(text)

old = "setState(() => _future = next);"
new = """setState(() {
      _future = next;
    });"""

count = text.count(old)
text = text.replace(old, new)

MAIN.write_text(text)
print(f"✅ 已修复 setState 返回 Future 问题，共替换 {count} 处")
