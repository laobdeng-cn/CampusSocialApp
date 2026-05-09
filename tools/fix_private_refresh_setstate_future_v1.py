from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_private_refresh_setstate_future_v1")
if not bak.exists():
    bak.write_text(text)

old = "setState(() => _future = next);"
new = """setState(() {
        _future = next;
      });"""

count = text.count(old)
if count == 0:
    raise SystemExit("⚠️ 没找到 setState(() => _future = next);，请发 main_shell.dart 1928-1945 行")

text = text.replace(old, new)

MAIN.write_text(text)
print(f"✅ 已修复 {count} 处 setState 返回 Future 的问题")
