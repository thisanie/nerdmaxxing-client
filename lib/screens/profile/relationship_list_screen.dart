import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../services/api_client.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'profile_screen.dart';

enum RelationshipType { followers, following }

class RelationshipListScreen extends StatefulWidget {
  final String userId;
  final RelationshipType type;

  const RelationshipListScreen({
    super.key,
    required this.userId,
    required this.type,
  });

  @override
  State<RelationshipListScreen> createState() => _RelationshipListScreenState();
}

class _RelationshipListScreenState extends State<RelationshipListScreen> {
  final _searchController = TextEditingController();
  List<UserSummary> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  String get _title =>
      widget.type == RelationshipType.followers ? 'Followers' : 'Following';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final service = context.read<ProfileService>();
      final users = widget.type == RelationshipType.followers
          ? await service.listFollowers(widget.userId)
          : await service.listFollowing(widget.userId);
      if (!mounted) return;
      setState(() => _users = users);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() => setState(() {});

  List<UserSummary> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((user) {
      return (user.username ?? '').toLowerCase().contains(query) ||
          (user.name ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search $_title'.toLowerCase(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(_errorMessage!)),
              )
            else if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'No $_title'.toLowerCase()
                        : 'No matches found.',
                  ),
                ),
              )
            else
              ...users.map((user) => _UserSummaryTile(user: user)),
          ],
        ),
      ),
    );
  }
}

class _UserSummaryTile extends StatelessWidget {
  final UserSummary user;
  const _UserSummaryTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceAlt,
        backgroundImage: user.avatarUrl == null
            ? null
            : NetworkImage(user.avatarUrl!),
        child: user.avatarUrl == null
            ? const Icon(Icons.person_outline, color: AppColors.textSecondary)
            : null,
      ),
      title: Text(user.name ?? user.username ?? 'NerdMaxxer'),
      subtitle: user.username == null ? null : Text('@${user.username}'),
      onTap: user.username == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(username: user.username),
              ),
            ),
    );
  }
}
