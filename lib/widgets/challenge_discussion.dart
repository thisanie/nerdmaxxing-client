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

  const ChallengeDiscussion({
    super.key,
    required this.challengeSlug,
    required this.service,
    required this.canPost,
    this.currentUsername,
  });

  @override
  State<ChallengeDiscussion> createState() => _ChallengeDiscussionState();
}

class _ChallengeDiscussionState extends State<ChallengeDiscussion> {
  final _composer = TextEditingController();
  final _comments = <DiscussionComment>[];
  final _replies = <String, List<DiscussionComment>>{};
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
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
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _post() async {
    final body = _composer.text.trim();
    if (!widget.canPost || body.isEmpty || body.length > 2200 || _posting) return;
    setState(() => _posting = true);
    try {
      final comment = await widget.service.create(widget.challengeSlug, body: body);
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _composer.clear();
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
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 2200,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Write a reply...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('POST')),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty) return;
    try {
      final reply = await widget.service.reply(comment.id, body);
      if (!mounted) return;
      setState(() => (_replies[comment.id] ??= []).add(reply));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
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
    final controller = TextEditingController(text: comment.body);
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(controller: controller, maxLength: 2200, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('SAVE')),
        ],
      ),
    );
    controller.dispose();
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
    final controller = TextEditingController(text: reply.body);
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit reply'),
        content: TextField(controller: controller, maxLength: 2200, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('SAVE')),
        ],
      ),
    );
    controller.dispose();
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
        if (widget.canPost) ...[
          const SizedBox(height: 8),
          _composerView(),
        ],
      ],
    );
  }

  Widget _composerView() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _avatar(widget.currentUsername),
      const SizedBox(width: 10),
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            controller: _composer,
            maxLength: 2200,
            maxLines: 4,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Share a question or idea...',
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Post comment',
        onPressed: _posting ? null : _post,
        color: _composer.text.trim().isEmpty ? AppColors.textDim : AppColors.primary,
        icon: _posting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send_outlined, size: 20),
      ),
    ],
  );

  Widget _commentView(DiscussionComment comment) {
    final replies = _replies[comment.id];
    final displayName = comment.author.name ?? comment.author.username ?? 'NerdMaxxer';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
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
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment.deleted ? 'Comment deleted' : comment.body,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$name  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                    text: reply.deleted ? 'Reply deleted' : reply.body,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
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
            icon: const Icon(Icons.more_horiz, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? label, {String? imageUrl}) {
    final initial = (label == null || label.isEmpty) ? '?' : label.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 19,
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
