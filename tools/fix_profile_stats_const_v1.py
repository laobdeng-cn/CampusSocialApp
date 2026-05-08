from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
text = MAIN.read_text()

bak = MAIN.with_suffix(".dart.bak_fix_profile_stats_const_v1")
if not bak.exists():
    bak.write_text(text)

markers = [
    "${profileStats.following}",
    "${profileStats.followers}",
    "${profileStats.likes}",
    "${profileStats.activities}",
]

changed = False

for marker in markers:
    index = text.find(marker)
    if index == -1:
        continue

    # 找到包含这个变量的最近一个 const Positioned
    start = text.rfind("const Positioned(", 0, index)
    if start != -1:
        text = text[:start] + text[start:].replace("const Positioned(", "Positioned(", 1)
        changed = True

    # 找到附近 children: const [，改成 children: [
    window_start = max(0, index - 1200)
    window_end = min(len(text), index + 1200)
    window = text[window_start:window_end]
    if "children: const [" in window:
        window = window.replace("children: const [", "children: [")
        text = text[:window_start] + window + text[window_end:]
        changed = True

MAIN.write_text(text)

if changed:
    print("✅ 已移除个人资料统计区的 const")
else:
    print("⚠️ 没找到需要修复的 const，请把 6590-6635 行发我")
