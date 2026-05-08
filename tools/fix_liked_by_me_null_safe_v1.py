from pathlib import Path

MODEL = Path("frontend/frontend/lib/models/campus_models.dart")
text = MODEL.read_text()

bak = MODEL.with_suffix(".dart.bak_liked_by_me_null_safe_v1")
if not bak.exists():
    bak.write_text(text)

# 1. 构造参数：this.likedByMe = false -> bool? likedByMe,
text = text.replace(
    "    this.likedByMe = false,\n  });",
    "    bool? likedByMe,\n  }) : _likedByMe = likedByMe;\n",
    1,
)

# 2. 字段：final bool likedByMe; -> nullable backing field + getter
text = text.replace(
    "  final bool likedByMe;\n",
    "  final bool? _likedByMe;\n  bool get likedByMe => _likedByMe == true;\n",
    1,
)

# 3. fromJson 里保留 likedByMe 传参，不需要改
# 4. copyWith 里如果已有 likedByMe 参数，返回处仍然传 likedByMe: likedByMe ?? this.likedByMe 即可

MODEL.write_text(text)
print("✅ CampusPost.likedByMe 已改成 null-safe getter")
