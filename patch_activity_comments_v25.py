from pathlib import Path
import re

root = Path(".")
backend_comment = root / "backend/src/models/Comment.js"
backend_routes = root / "backend/src/routes/index.js"
models = root / "frontend/frontend/lib/models/campus_models.dart"
api = root / "frontend/frontend/lib/services/campus_api_client.dart"
repo = root / "frontend/frontend/lib/repositories/campus_repository.dart"
screen = root / "frontend/frontend/lib/screens/activity_feature_pages.dart"

for p in [backend_comment, backend_routes, models, api, repo, screen]:
    if not p.exists():
        raise SystemExit(f"❌ 找不到文件：{p}")
    bak = p.with_suffix(p.suffix + ".bak_activity_comments_v25")
    bak.write_text(p.read_text(), encoding="utf-8")
    print(f"✅ 已备份：{bak}")

# 1. 后端 Comment 模型：支持 post 评论 + activity 评论
backend_comment.write_text("""const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema(
  {
    kind: {
      type: String,
      enum: ['post', 'activity'],
      default: 'post',
      index: true,
    },
    post: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Post',
      index: true,
    },
    activity: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Activity',
      index: true,
    },
    author: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    text: { type: String, required: true, trim: true },
    likes: { type: Number, default: 0 },
  },
  { timestamps: true }
);

commentSchema.pre('validate', function validateCommentTarget(next) {
  if (!this.post && !this.activity) {
    next(new Error('评论必须关联帖子或活动'));
    return;
  }
  if (this.post && this.activity) {
    next(new Error('评论不能同时关联帖子和活动'));
    return;
  }
  this.kind = this.activity ? 'activity' : 'post';
  next();
});

commentSchema.index({ post: 1, createdAt: -1 });
commentSchema.index({ activity: 1, createdAt: -1 });

module.exports = mongoose.model('Comment', commentSchema);
""", encoding="utf-8")
print("✅ 已重写 Comment.js：支持活动评论")

# 2. 后端 serializeComment 增加 activity
text = backend_routes.read_text(encoding="utf-8")
if "activity: serializeActivity(plain.activity)" not in text:
    text = text.replace(
        "    post: serializePost(plain.post),\n",
        "    post: serializePost(plain.post),\n    activity: serializeActivity(plain.activity),\n",
    )
    print("✅ serializeComment 已增加 activity")

# 删除活动时级联删除活动评论
if "Comment.deleteMany({ activity: activity._id })" not in text:
    text = text.replace(
        "      CheckIn.deleteMany({ activity: activity._id }),\n",
        "      CheckIn.deleteMany({ activity: activity._id }),\n      Comment.deleteMany({ activity: activity._id }),\n",
    )
    print("✅ 删除活动时已增加删除活动评论")

activity_comment_routes = r"""
router.get('/activities/:id/comments', requireAuth, async (request, response, next) => {
  try {
    const activity = await findActivityOr404(request.params.id, response);
    if (!activity) return;

    const comments = await Comment.find({
      activity: activity._id,
      kind: 'activity',
    })
      .populate('author')
      .sort({ createdAt: -1 })
      .lean();

    response.json({
      comments: comments.map(serializeComment),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/activities/:id/comments', requireAuth, async (request, response, next) => {
  try {
    const activity = await findActivityOr404(request.params.id, response);
    if (!activity) return;

    if (activity.allowComments === false) {
      response.status(400).json({ message: '该活动已关闭评论' });
      return;
    }

    const text = String(request.body.text || '').trim();
    if (!text) {
      response.status(400).json({ message: '评论内容不能为空' });
      return;
    }

    if (text.length > 300) {
      response.status(400).json({ message: '评论内容不能超过 300 字' });
      return;
    }

    const comment = await Comment.create({
      kind: 'activity',
      activity: activity._id,
      author: request.user._id,
      text,
    });

    await comment.populate('author');

    const ownerId = String(activity.createdBy?._id || activity.createdBy || '');
    const currentUserId = String(request.user._id);

    if (ownerId && ownerId !== currentUserId) {
      await Notification.create({
        recipient: ownerId,
        actor: request.user._id,
        activity: activity._id,
        category: 'interaction',
        title: '活动有新评论',
        firstLine: `${request.user.name || '有同学'} 评论了「${activity.title}」`,
        secondLine: text.slice(0, 48),
        action: 'activity_commented',
        unread: true,
      });
    }

    response.status(201).json({
      comment: serializeComment(comment),
      activity: serializeActivity(activity),
    });
  } catch (error) {
    next(error);
  }
});

router.delete('/activities/:id/comments/:commentId', requireAuth, async (request, response, next) => {
  try {
    const activity = await findActivityOr404(request.params.id, response);
    if (!activity) return;

    const comment = await Comment.findOne({
      _id: request.params.commentId,
      activity: activity._id,
      kind: 'activity',
    }).populate('author');

    if (!comment) {
      response.status(404).json({ message: '评论不存在' });
      return;
    }

    const isAuthor = String(comment.author?._id || comment.author || '') === String(request.user._id);
    const isActivityOwner = String(activity.createdBy?._id || activity.createdBy || '') === String(request.user._id);

    if (!isAuthor && !isActivityOwner) {
      response.status(403).json({ message: '无权删除该评论' });
      return;
    }

    await comment.deleteOne();
    response.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

"""

if "router.get('/activities/:id/comments'" not in text:
    anchor = "router.post('/activities/:id/favorite'"
    if anchor not in text:
        raise SystemExit("❌ 未找到活动 favorite 接口锚点，后端评论路由未插入")
    text = text.replace(anchor, activity_comment_routes + "\n" + anchor)
    print("✅ 已插入活动评论 GET/POST/DELETE 接口")

backend_routes.write_text(text, encoding="utf-8")

# 3. 前端 CampusActivity 增加 allowComments
text = models.read_text(encoding="utf-8")

if "final bool allowComments;" not in text:
    text = text.replace(
        "    this.checkInEndAt = '',\n    this.isFavorited = false,\n",
        "    this.checkInEndAt = '',\n    this.allowComments = true,\n    this.isFavorited = false,\n",
    )
    text = text.replace(
        "  final String checkInEndAt;\n  final bool isFavorited;\n",
        "  final String checkInEndAt;\n  final bool allowComments;\n  final bool isFavorited;\n",
    )
    text = text.replace(
        "      checkInEndAt: _readString(json, 'checkInEndAt'),\n      isFavorited:\n",
        "      checkInEndAt: _readString(json, 'checkInEndAt'),\n      allowComments: json['allowComments'] != false,\n      isFavorited:\n",
    )
    text = text.replace(
        "    String? checkInEndAt,\n    bool? isFavorited,\n",
        "    String? checkInEndAt,\n    bool? allowComments,\n    bool? isFavorited,\n",
    )
    text = text.replace(
        "      checkInEndAt: checkInEndAt ?? this.checkInEndAt,\n      isFavorited: isFavorited ?? this.isFavorited,\n",
        "      checkInEndAt: checkInEndAt ?? this.checkInEndAt,\n      allowComments: allowComments ?? this.allowComments,\n      isFavorited: isFavorited ?? this.isFavorited,\n",
    )
    print("✅ CampusActivity 已增加 allowComments")

models.write_text(text, encoding="utf-8")

# 4. ApiClient 增加活动评论接口
text = api.read_text(encoding="utf-8")
api_methods = r"""
  Future<List<CampusComment>> fetchActivityComments({
    required String token,
    required String activityId,
  }) async {
    final json = await _getJson(
      '/api/activities/$activityId/comments',
      token: token,
    );
    final value = json['comments'];
    if (value is! List) return const <CampusComment>[];

    return value
        .whereType<Map>()
        .map((item) => CampusComment.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<CampusComment> createActivityComment({
    required String token,
    required String activityId,
    required String text,
  }) async {
    final json = await _postJson(
      '/api/activities/$activityId/comments',
      {'text': text},
      token: token,
    );

    final value = json['comment'];
    if (value is Map<String, dynamic>) {
      return CampusComment.fromJson(value);
    }
    if (value is Map) {
      return CampusComment.fromJson(value.cast<String, dynamic>());
    }

    throw const CampusApiException('评论发布失败');
  }

  Future<void> deleteActivityComment({
    required String token,
    required String activityId,
    required String commentId,
  }) async {
    await _deleteJson(
      '/api/activities/$activityId/comments/$commentId',
      token: token,
    );
  }

"""

if "fetchActivityComments({" not in text:
    anchor = "  Future<CampusCheckInRecord> checkInActivity("
    if anchor not in text:
        anchor = "  Future<List<CampusActivityEnrollment>> fetchActivityEnrollments("
    if anchor not in text:
        raise SystemExit("❌ 未找到 ApiClient 插入锚点")
    text = text.replace(anchor, api_methods + anchor)
    print("✅ ApiClient 已增加活动评论接口")

api.write_text(text, encoding="utf-8")

# 5. Repository 增加活动评论方法
text = repo.read_text(encoding="utf-8")
repo_methods = r"""
  Future<List<CampusComment>> fetchActivityComments(
    CampusActivity activity,
  ) async {
    final id = _requireActivityId(activity);
    return _apiClient.fetchActivityComments(
      token: _requireToken(),
      activityId: id,
    );
  }

  Future<CampusComment> createActivityComment(
    CampusActivity activity,
    String text,
  ) async {
    final id = _requireActivityId(activity);
    return _apiClient.createActivityComment(
      token: _requireToken(),
      activityId: id,
      text: text,
    );
  }

  Future<void> deleteActivityComment(
    CampusActivity activity,
    CampusComment comment,
  ) async {
    final id = _requireActivityId(activity);
    await _apiClient.deleteActivityComment(
      token: _requireToken(),
      activityId: id,
      commentId: comment.id,
    );
  }

"""

if "fetchActivityComments(\n    CampusActivity activity" not in text:
    anchor = "  Future<List<CampusActivityEnrollment>> fetchActivityEnrollments("
    if anchor not in text:
        raise SystemExit("❌ 未找到 Repository 插入锚点")
    text = text.replace(anchor, repo_methods + anchor)
    print("✅ Repository 已增加活动评论方法")

repo.write_text(text, encoding="utf-8")

# 6. 活动详情页插入评论组件
text = screen.read_text(encoding="utf-8")

comment_widget = r"""
class _ActivityCommentSection extends StatefulWidget {
  const _ActivityCommentSection({required this.activity});

  final CampusActivity activity;

  @override
  State<_ActivityCommentSection> createState() => _ActivityCommentSectionState();
}

class _ActivityCommentSectionState extends State<_ActivityCommentSection> {
  late Future<List<CampusComment>> _future;
  final _controller = TextEditingController();
  var _isSending = false;

  @override
  void initState() {
    super.initState();
    _future = CampusRepository.instance.fetchActivityComments(widget.activity);
  }

  @override
  void didUpdateWidget(covariant _ActivityCommentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != widget.activity.id) {
      _future = CampusRepository.instance.fetchActivityComments(widget.activity);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = CampusRepository.instance.fetchActivityComments(widget.activity);
    setState(() => _future = future);
    await future;
  }

  Future<void> _submit() async {
    if (_isSending) return;

    if (!widget.activity.allowComments) {
      _showFeatureMessage(context, '该活动已关闭评论');
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showFeatureMessage(context, '请输入评论内容');
      return;
    }

    if (text.length > 300) {
      _showFeatureMessage(context, '评论内容不能超过 300 字');
      return;
    }

    setState(() => _isSending = true);
    try {
      await CampusRepository.instance.createActivityComment(widget.activity, text);
      _controller.clear();
      await _reload();
      if (mounted) _showFeatureMessage(context, '评论已发布');
    } catch (error) {
      if (mounted) _showFeatureMessage(context, _featureError(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _delete(CampusComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除评论'),
          content: const Text('确定删除这条评论吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await CampusRepository.instance.deleteActivityComment(widget.activity, comment);
      await _reload();
      if (mounted) _showFeatureMessage(context, '评论已删除');
    } catch (error) {
      if (mounted) _showFeatureMessage(context, _featureError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CampusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('评论互动', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新评论',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.activity.allowComments) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: InputDecoration(
                      hintText: '说点什么，和同学互动一下',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF4F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _isSending ? null : _submit,
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('发送'),
                  ),
                ),
              ],
            ),
          ] else
            const Text(
              '该活动已关闭评论互动',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 14),
          FutureBuilder<List<CampusComment>>(
            future: _future,
            builder: (context, snapshot) {
              final comments = snapshot.data ?? const <CampusComment>[];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  comments.isEmpty;

              if (isLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError && comments.isEmpty) {
                return Text(
                  _featureError(snapshot.error!),
                  style: const TextStyle(color: AppColors.muted),
                );
              }

              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '暂无评论，成为第一个互动的同学吧。',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final comment in comments) ...[
                    _ActivityCommentTile(
                      comment: comment,
                      onDelete: () => _delete(comment),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityCommentTile extends StatelessWidget {
  const _ActivityCommentTile({
    required this.comment,
    required this.onDelete,
  });

  final CampusComment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampusAvatar(user: comment.author, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _friendlyFeatureTime(comment.createdAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_horiz_rounded, size: 18),
                      onSelected: (value) {
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('删除评论'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

"""

if "class _ActivityCommentSection" not in text:
    anchor = "class _ActivityItem {"
    if anchor not in text:
        raise SystemExit("❌ 未找到 _ActivityItem 锚点，评论组件未插入")
    text = text.replace(anchor, comment_widget + "\n" + anchor)
    print("✅ 已插入活动评论组件")

insert_anchor = """            const SizedBox(height: 14),
            CampusCard(
              child: Row(
                children: [
                  AvatarStack(users: _activity.guests, size: 34),"""

if "_ActivityCommentSection(activity: _activity)" not in text:
    if insert_anchor not in text:
        print("⚠️ 未自动找到详情页关注卡片锚点，请手动把 _ActivityCommentSection(activity: _activity) 插入活动介绍卡片后面")
    else:
        text = text.replace(
            insert_anchor,
            """            const SizedBox(height: 14),
            _ActivityCommentSection(activity: _activity),
            const SizedBox(height: 14),
            CampusCard(
              child: Row(
                children: [
                  AvatarStack(users: _activity.guests, size: 34),""",
            )
        print("✅ 活动详情页已插入评论互动模块")

screen.write_text(text, encoding="utf-8")

print("✅ v25 活动评论/互动 + 消息通知联动 patch 完成")
