import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../services/api_client.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_screen.dart';

class PeopleDiscoverScreen extends StatefulWidget {
  const PeopleDiscoverScreen({super.key});

  @override
  State<PeopleDiscoverScreen> createState() => _PeopleDiscoverScreenState();
}

class _PeopleDiscoverScreenState extends State<PeopleDiscoverScreen> {
  final _usernameController = TextEditingController();
  UserProfile? _profile;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _profile = null;
    });
    try {
      final profile = await context.read<ProfileService>().getProfile(username);
      if (!mounted) return;
      setState(() => _profile = profile);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search people by username',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: _isLoading ? null : _search,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.danger),
            )
          else if (_profile != null)
            _ProfileResult(profile: _profile!)
          else
            const Text(
              'Find people and explore what they have completed.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _ProfileResult extends StatelessWidget {
  final UserProfile profile;
  const _ProfileResult({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceAlt,
          backgroundImage: profile.avatarUrl != null
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: profile.avatarUrl == null
              ? const Icon(Icons.person_outline, color: AppColors.textSecondary)
              : null,
        ),
        title: Text(profile.name ?? profile.username ?? 'NerdMaxxer'),
        subtitle: Text('@${profile.username ?? 'profile'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(username: profile.username),
          ),
        ),
      ),
    );
  }
}