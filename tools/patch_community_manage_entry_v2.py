from pathlib import Path

MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")

text = MAIN.read_text()

backup = MAIN.with_name(MAIN.name + ".bak_community_manage_entry_v2")
backup.write_text(text)
print(f"✅ 已备份: {backup}")

old = """          IconButton(
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const PublishPostScreen()),
              );
              if (created == true) {
                await _refresh();
              }
            },
            icon: const Icon(Icons.edit_square),
          ),"""

new = """          IconButton(
            tooltip: '我管理的社群',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const MyManagedGroupsScreen()),
              );
              if (changed == true) {
                await _refresh();
              }
            },
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),"""

if old not in text:
    raise SystemExit("❌ 没找到社区页右上角发布按钮代码，文件可能已经改过。")

text = text.replace(old, new, 1)
MAIN.write_text(text)
print("✅ 社区页右上角按钮已改为：我管理的社群入口")
