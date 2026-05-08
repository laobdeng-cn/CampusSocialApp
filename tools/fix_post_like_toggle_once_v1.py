from pathlib import Path
import re

ROUTES = Path("backend/src/routes/index.js")
POST_MODEL = Path("frontend/frontend/lib/models/campus_models.dart")
API = Path("frontend/frontend/lib/services/campus_api_client.dart")
REPO = Path("frontend/frontend/lib/repositories/campus_repository.dart")
MAIN = Path("frontend/frontend/lib/screens/main_shell.dart")
DETAIL = Path("frontend/frontend/lib/screens/detail_pages.dart")

# ========== 1. 后端：修复 /posts/:id/like，只能点赞一次，再点取消 ==========
text = ROUTES.read_text()
bak = ROUTES.with_suffix(".js.bak_like_toggle_once_v1")
if not bak.exists():
    bak.write_text(text)

start = text.find("router.post('/posts/:id/like'")
end = text.find("router.post('/posts/:id/favorite'", start)

if start == -1 or end == -1:
    raise SystemExit("❌ 没找到 /posts/:id/like 或 /posts/:id/favorite，请把 backend/src/routes/index.js 中 like/favorite 区域发我")

new_like_route = r'''router.post('/posts/:id/like', requireAuth, async (request, response, next) => {
  try {
    const post = await findPostOr404(request.params.id, response);
    if (!post) return;

    const existing = await Like.findOne({
      post: post._id,
      user: request.user._id,
    });

    let liked = false;

    if (existing) {
      await existing.deleteOne();
      liked = false;
    } else {
      try {
        await Like.create({
          post: post._id,
          user: request.user._id,
        });
      } catch (error) {
        // 并发重复点击时，唯一索引可能先插入成功。
        // 这种情况按“已点赞”处理，不再重复 +1。
        if (error?.code !== 11000) throw error;
      }
      liked = true;
    }

    const likeCount = await Like.countDocuments({ post: post._id });
    post.likes = likeCount;
    await post.save();
    await post.populate('author');

    response.json({
      liked,
      post: {
        ...serializePost(post),
        likedByMe: liked,
      },
    });
  } catch (error) {
    next(error);
  }
});

'''

text = text[:start] + new_like_route + text[end:]
ROUTES.write_text(text)
print("✅ 后端 /posts/:id/like 已改为点赞/取消点赞 toggle")

# ========== 2. 前端模型：CampusPost 增加 likedByMe ==========
model = POST_MODEL.read_text()
bak = POST_MODEL.with_suffix(".dart.bak_like_toggle_once_v1")
if not bak.exists():
    bak.write_text(model)

if "final bool likedByMe;" not in model:
    model = model.replace(
        "    this.pinnedInGroup = false,\n  });",
        "    this.pinnedInGroup = false,\n    this.likedByMe = false,\n  });",
        1,
    )
    model = model.replace(
        "  final bool pinnedInGroup;\n",
        "  final bool pinnedInGroup;\n  final bool likedByMe;\n",
        1,
    )
    model = model.replace(
        "      pinnedInGroup: json['pinnedInGroup'] == true,\n",
        "      pinnedInGroup: json['pinnedInGroup'] == true,\n      likedByMe: json['likedByMe'] == true || json['liked'] == true,\n",
        1,
    )
    model = model.replace(
        "    bool? pinnedInGroup,\n  }) {",
        "    bool? pinnedInGroup,\n    bool? likedByMe,\n  }) {",
        1,
    )
    model = model.replace(
        "      pinnedInGroup: pinnedInGroup ?? this.pinnedInGroup,\n",
        "      pinnedInGroup: pinnedInGroup ?? this.pinnedInGroup,\n      likedByMe: likedByMe ?? this.likedByMe,\n",
        1,
    )
    print("✅ CampusPost 已增加 likedByMe")
else:
    print("ℹ️ CampusPost 已有 likedByMe，跳过")

POST_MODEL.write_text(model)

# ========== 3. ApiClient：togglePostLike 兼容 liked 字段 ==========
api = API.read_text()
bak = API.with_suffix(".dart.bak_like_toggle_once_v1")
if not bak.exists():
    bak.write_text(api)

old = """  Future<CampusPost> togglePostLike({
    required String token,
    required String postId,
  }) async {
    final json = await _postJson('/api/posts/$postId/like', {}, token: token);
    return _readPostPayload(json);
  }
"""

new = """  Future<CampusPost> togglePostLike({
    required String token,
    required String postId,
  }) async {
    final json = await _postJson('/api/posts/$postId/like', {}, token: token);
    final post = _readPostPayload(json);
    return post.copyWith(likedByMe: json['liked'] == true || post.likedByMe);
  }
"""

if old in api:
    api = api.replace(old, new, 1)
    print("✅ ApiClient.togglePostLike 已兼容 liked")
else:
    print("⚠️ 没匹配到 ApiClient.togglePostLike，可能已经改过")

API.write_text(api)

# ========== 4. Repository：把后端 likedByMe 同步到缓存 ==========
repo = REPO.read_text()
bak = REPO.with_suffix(".dart.bak_like_toggle_once_v1")
if not bak.exists():
    bak.write_text(repo)

# 这里通常已经通过 _replaceCachedPost 更新了，不强行大改，只保留模型字段即可。
REPO.write_text(repo)

# ========== 5. 首页帖子卡片：不能用 likes > 0 判断是否已点赞 ==========
main = MAIN.read_text()
bak = MAIN.with_suffix(".dart.bak_like_toggle_once_v1")
if not bak.exists():
    bak.write_text(main)

main = main.replace(
    "late bool _liked = widget.post.likes > 0;",
    "late bool _liked = widget.post.likedByMe;",
)

main = main.replace(
    "_liked = widget.post.likes > 0;",
    "_liked = widget.post.likedByMe;",
)

# 成功后以后端 likedByMe 为准
main = main.replace(
    "_liked = post.likes > previousPost.likes || post.likes > 0;",
    "_liked = post.likedByMe;",
)

MAIN.write_text(main)
print("✅ 首页 PostFeedCard 点赞状态已改为 likedByMe")

# ========== 6. 帖子详情页：点赞状态用 likedByMe ==========
detail = DETAIL.read_text()
bak = DETAIL.with_suffix(".dart.bak_like_toggle_once_v1")
if not bak.exists():
    bak.write_text(detail)

# 常见初始化/赋值修复
detail = detail.replace(
    "var _postLiked = false;",
    "late bool _postLiked = widget.post.likedByMe;",
)

detail = detail.replace(
    "_postLiked = _post.likes > 0;",
    "_postLiked = _post.likedByMe;",
)

detail = detail.replace(
    "_postLiked = post.likes > wasLikes || post.likes > 0;",
    "_postLiked = post.likedByMe;",
)

# 如果 toggleLike 成功后只 set _post，没有 set _postLiked，则补一层常见写法
detail = detail.replace(
    "if (mounted) setState(() => _post = post);",
    "if (mounted) {\n        setState(() {\n          _post = post;\n          _postLiked = post.likedByMe;\n        });\n      }",
    1,
)

DETAIL.write_text(detail)
print("✅ 帖子详情点赞状态已改为 likedByMe")

print("🎉 点赞一次/取消点赞补丁完成")
