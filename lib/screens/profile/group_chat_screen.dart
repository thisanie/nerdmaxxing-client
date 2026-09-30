import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../models/group_message.dart';
import '../../services/api_client.dart';
import '../../services/groups_service.dart';
import '../../services/token_storage.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<GroupMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadMessages();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await TokenStorage().userId;
    if (mounted) setState(() => _currentUserId = userId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await context.read<GroupsService>().listMessages(widget.group.id);
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToEnd();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await context.read<GroupsService>().createMessage(
        widget.group.id,
        body: body,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _messages = [..._messages, message];
        _error = null;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showGroupDetails() {
    final membersFuture = context.read<GroupsService>().listMembers(widget.group.id);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final group = widget.group;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: theme.textTheme.headlineSmall),
                if (group.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(group.description!),
                ],
                const SizedBox(height: 20),
                _GroupDetailRow(
                  icon: Icons.people_outline,
                  label: 'Members',
                  value:
                      '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                ),
                _GroupDetailRow(
                  icon: group.visibility == 'PRIVATE'
                      ? Icons.lock_outline
                      : Icons.public,
                  label: 'Visibility',
                  value: group.visibility == 'PRIVATE' ? 'Private' : 'Public',
                ),
                _GroupDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Created',
                  value: group.createdAt == null
                      ? 'Unknown'
                      : _formatDate(group.createdAt!),
                ),
                const SizedBox(height: 6),
                Text('Members', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilder<List<GroupMember>>(
                  future: membersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Could not load group members: ${snapshot.error}');
                    }
                    final members = snapshot.data ?? const <GroupMember>[];
                    if (members.isEmpty) return const Text('No members found.');
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(member.displayName[0].toUpperCase()),
                            ),
                            title: Text(member.displayName),
                            subtitle: member.username == null
                                ? null
                                : Text('@${member.username}'),
                            trailing: member.status == null
                                ? null
                                : Text(member.status!),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading ? null : _loadMessages,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Group details',
            onPressed: _showGroupDetails,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [TextButton(onPressed: _loadMessages, child: const Text('Retry'))],
            ),
          Expanded(child: _buildMessages()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return const Center(child: Text('No messages yet. Start the conversation.'));
    }
    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _MessageBubble(
            message: message,
            isMine: _currentUserId != null &&
                message.author.id == _currentUserId,
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLength: 4000,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  counterText: '',
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              tooltip: 'Send message',
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour == 0 ? 12 : local.hour > 12 ? local.hour - 12 : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _GroupDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GroupDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bubbleColor = isMine
        ? colors.primary
        : colors.surfaceContainerHighest;
    final textColor = isMine ? colors.onPrimary : colors.onSurface;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: IntrinsicWidth(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      message.author.displayName,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  message.body,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
                if (message.createdAt != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        _timeLabel(message.createdAt!),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _timeLabel(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour == 0 ? 12 : local.hour > 12 ? local.hour - 12 : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}