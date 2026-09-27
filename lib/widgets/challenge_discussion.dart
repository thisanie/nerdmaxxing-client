import 'package:flutter/material.dart';

import '../models/discussion_comment.dart';
import '../services/api_client.dart';
import '../services/discussions_service.dart';
import '../theme/app_theme.dart';

class ChallengeDiscussion extends StatefulWidget {
  final String challengeSlug;
  final DiscussionsService service;
  final bool canPost;
  final String? currentUsername;
  final String? initialDiscussionId;
  final String? initialReplyId;

  const ChallengeDiscussion({
    super.key,
    required this.challengeSlug,
    required this.service,
    required this.canPost,
    this.currentUsername,
    this.initialDiscussionId,
    this.initialReplyId,
  });

  @override
  State<ChallengeDiscussion> createState() => _ChallengeDiscussionState();
}

class _ChallengeDiscussionState extends State<ChallengeDiscussion> {
  final _composer = TextEditingController();
  final _composerFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _comments = <DiscussionComment>[];
  final _replies = <String, List<DiscussionComment>>{};
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _posting = false;
  String? _error;
  BuildContext? _targetReplyContext;
  DiscussionComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _composer.addListener(_composerChanged);
    _load();
  }

  @override
  void dispose() {
    _composer.removeListener(_composerChanged);
    _composer.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _composerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || _cursor == null)) return;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await widget.service.list(widget.challengeSlug, cursor: more ? _cursor : null);
      if (!mounted) return;
      setState(() {
        if (more) {
          _comments.addAll(page.items);
        } else {
          _comments
            ..clear()
            ..addAll(page.items);
        }
        _cursor = page.nextCursor;
      });
      await _openInitialReply();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _openInitialReply() async {
    final discussionId = widget.initialDiscussionId;
    final replyId = widget.initialReplyId;
    if (discussionId == null || replyId == null) return;
    final comment = _comments.where((item) => item.id == discussionId).firstOrNull;
    if (comment == null) return;
    await _loadReplies(comment);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _targetReplyContext;
      if (targetContext != null && targetContext.mounted) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: .35,
          duration: const Duration(milliseconds: 350),
        );
      }
    });
  }

  Future<void> _post() async {
    final body = _composer.text.trim();
    if (!widget.canPost || body.isEmpty || body.length > 2200 || _posting) return;
    final parentComment = _replyingTo;
    setState(() => _posting = true);
    try {
      final comment = parentComment == null
          ? await widget.service.create(widget.challengeSlug, body: body)
          : await widget.service.reply(parentComment.id, body);
      if (!mounted) return;
      _composer.clear();
      setState(() {
        if (parentComment == null) {
          _comments.insert(0, comment);
        } else {
          (_replies[parentComment.id] ??= []).add(comment);
        }
        _replyingTo = null;
      });
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _loadReplies(DiscussionComment comment) async {
    if (_replies.containsKey(comment.id)) {
      setState(() => _replies.remove(comment.id));
      return;
    }
    try {
      final page = await widget.service.listReplies(comment.id);
      if (mounted) setState(() => _replies[comment.id] = page.items);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _reply(DiscussionComment comment) async {
    setState(() => _replyingTo = comment);
    if (!_replies.containsKey(comment.id)) {
      await _loadReplies(comment);
    }
    if (!mounted) return;
    _composerFocusNode.requestFocus();
  }

  Future<void> _report(DiscussionComment comment) async {
    try {
      await widget.service.report(comment.id);
      if (mounted) _showError('Report submitted.');
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _edit(DiscussionComment comment) async {
    var draft = comment.body;
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextFormField(
          maxLength: 2200,
          maxLines: 5,
          initialValue: comment.body,
          onChanged: (value) => draft = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, draft.trim()), child: const Text('SAVE')),
        ],
      ),
    );
    if (body == null || body.isEmpty || body == comment.body) return;
    try {
      final updated = await widget.service.update(comment.id, body);
      if (mounted) setState(() => _replaceComment(updated));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _delete(DiscussionComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.service.delete(comment.id);
      if (mounted) setState(() => _replaceComment(comment.copyWith(deleted: true)));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _resolve(DiscussionComment comment) async {
    try {
      await widget.service.resolve(comment.id);
      if (mounted) setState(() => _replaceComment(comment.copyWith(resolved: true)));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _editReply(String discussionId, DiscussionComment reply) async {
    var draft = reply.body;
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit reply'),
        content: TextFormField(
          maxLength: 2200,
          maxLines: 5,
          initialValue: reply.body,
          onChanged: (value) => draft = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, draft.trim()), child: const Text('SAVE')),
        ],
      ),
    );
    if (body == null || body.isEmpty || body == reply.body) return;
    try {
      final updated = await widget.service.updateReply(discussionId, reply.id, body);
      if (mounted) setState(() => _replaceReply(discussionId, updated));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _deleteReply(String discussionId, DiscussionComment reply) async {
    try {
      await widget.service.deleteReply(discussionId, reply.id);
      if (mounted) setState(() => _replaceReply(discussionId, reply.copyWith(deleted: true)));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _reportReply(String discussionId, DiscussionComment reply) async {
    try {
      await widget.service.report(discussionId, replyId: reply.id);
      if (mounted) _showError('Report submitted.');
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  void _replaceComment(DiscussionComment updated) {
    final index = _comments.indexWhere((item) => item.id == updated.id);
    if (index >= 0) _comments[index] = updated;
  }

  void _replaceReply(String discussionId, DiscussionComment updated) {
    final replies = _replies[discussionId];
    if (replies == null) return;
    final index = replies.indexWhere((item) => item.id == updated.id);
    if (index >= 0) replies[index] = updated;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: _messageView(),
          ),
        ),
        if (widget.canPost) ...[
          SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: .94),
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 9, 14, 9),
                child: _composerView(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _messageView() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          _errorView()
        else if (_comments.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No comments yet. Start the conversation.'))
        else ...[
          for (final comment in _comments) _commentView(comment),
          if (_cursor != null)
            Center(
              child: TextButton(
                onPressed: () => _load(more: true),
                child: Text(_loadingMore ? 'LOADING...' : 'LOAD MORE'),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _composerView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_replyingTo != null)
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Replying to ${_replyingTo!.author.name ?? _replyingTo!.author.username ?? 'comment'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Cancel reply',
                onPressed: () => setState(() => _replyingTo = null),
                icon: const Icon(Icons.close, size: 18),
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(widget.currentUsername, radius: 16),
          const SizedBox(width: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .92),
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _composer,
                focusNode: _composerFocusNode,
                maxLength: 2200,
                maxLines: 1,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: _replyingTo == null ? 'Share a question or idea...' : 'Write a reply...',
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 9, 8, 9),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _replyingTo == null ? 'Post comment' : 'Post reply',
            onPressed: _posting ? null : _post,
            color: _composer.text.trim().isEmpty ? AppColors.textDim : AppColors.primary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            icon: _posting
                ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    ],
  );

  Widget _commentView(DiscussionComment comment) {
    final replies = _replies[comment.id];
    final displayName = comment.author.name ?? comment.author.username ?? 'NerdMaxxer';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _avatar(displayName, imageUrl: comment.author.avatarUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (comment.createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _timeLabel(comment.createdAt!),
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12.5),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment.deleted ? 'Comment deleted' : comment.body,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.45),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit': _edit(comment);
                  case 'delete': _delete(comment);
                  case 'resolve': _resolve(comment);
                  case 'report': _report(comment);
                }
              },
              itemBuilder: (_) => [
                if (comment.author.username != null && comment.author.username == widget.currentUsername)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (comment.author.username != null && comment.author.username == widget.currentUsername)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                if (comment.type == 'QUESTION' && !comment.resolved && widget.canPost)
                  const PopupMenuItem(value: 'resolve', child: Text('Mark resolved')),
                const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
              icon: const Icon(Icons.more_horiz, size: 18),
            ),
          ]),
          if (!comment.deleted && widget.canPost)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 5),
              child: Row(children: [
                if (comment.type == 'QUESTION' && !comment.resolved)
                  const Text('QUESTION  ', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _reply(comment),
                  child: const Text('Reply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                if (comment.replyCount > 0 || replies != null)
                  TextButton(onPressed: () => _loadReplies(comment), child: Text(replies == null ? '${comment.replyCount} replies' : 'Hide replies')),
              ]),
            ),
          if (replies != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.primary.withValues(alpha: .45), width: 2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Column(children: [for (final reply in replies) _replyView(comment.id, reply)]),
                ),
              ),
            ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  Widget _replyView(String discussionId, DiscussionComment reply) {
    final name = reply.author.name ?? reply.author.username ?? 'NerdMaxxer';
    final isTarget = reply.id == widget.initialReplyId;
    return Builder(
      builder: (context) {
        if (isTarget) _targetReplyContext = context;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: isTarget
              ? BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(name, imageUrl: reply.author.avatarUrl, radius: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (reply.createdAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _timeLabel(reply.createdAt!),
                              style: const TextStyle(
                                color: AppColors.textDim,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reply.deleted ? 'Reply deleted' : reply.body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editReply(discussionId, reply);
                      case 'delete':
                        _deleteReply(discussionId, reply);
                      case 'report':
                        _reportReply(discussionId, reply);
                    }
                  },
                  itemBuilder: (_) => [
                    if (reply.author.username != null &&
                        reply.author.username == widget.currentUsername)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (reply.author.username != null &&
                        reply.author.username == widget.currentUsername)
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                  ],
                  icon: const Icon(Icons.more_horiz, size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatar(String? label, {String? imageUrl, double radius = 19}) {
    final initial = (label == null || label.isEmpty) ? '?' : label.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceAlt,
      backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
      child: imageUrl == null
          ? Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))
          : null,
    );
  }

  String _timeLabel(DateTime createdAt) {
    final age = DateTime.now().difference(createdAt.toLocal());
    if (age.inMinutes < 1) return 'now';
    if (age.inMinutes < 60) return '${age.inMinutes}m';
    if (age.inHours < 24) return '${age.inHours}h';
    return '${age.inDays}d';
  }

  Widget _errorView() => Row(children: [
    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
    TextButton(onPressed: _load, child: const Text('RETRY')),
  ]);
}
