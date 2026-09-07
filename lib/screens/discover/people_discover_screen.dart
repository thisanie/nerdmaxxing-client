import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/user_profile.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenge_card.dart';
import '../challenge/challenge_detail_screen.dart';
import '../profile/profile_screen.dart';

class PeopleDiscoverScreen extends StatefulWidget {
  const PeopleDiscoverScreen({super.key});

  @override
  State<PeopleDiscoverScreen> createState() => _PeopleDiscoverScreenState();
}

class _PeopleDiscoverScreenState extends State<PeopleDiscoverScreen> {
  final _usernameController = TextEditingController();
  UserProfile? _profile;
  List<Challenge> _challenges = [];
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
      _challenges = [];
    });
    UserProfile? profile;
    List<Challenge> challenges = [];
    String? profileError;
    String? challengeError;

    await Future.wait([
      () async {
        try {
          profile = await context.read<ProfileService>().getProfile(username);
        } on ApiException catch (e) {
          profileError = e.message;
        }
      }(),
      () async {
        try {
          final results = await context.read<ChallengesService>().list(
            limit: 100,
          );
          final query = username.toLowerCase();
          challenges = results.where((challenge) {
            final searchable = [
              challenge.title,
              challenge.shortDescription,
              challenge.fullDescription,
            ].join(' ').toLowerCase();
            return searchable.contains(query);
          }).toList();
        } on ApiException catch (e) {
          challengeError = e.message;
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _challenges = challenges;
      _errorMessage = profile == null && challenges.isEmpty
          ? challengeError ?? profileError ?? 'No matching results found.'
          : null;
      _isLoading = false;
    });
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
              hintText: 'Search people or challenges',
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
          else if (_profile == null && _challenges.isEmpty)
            const Text(
              'Search for people by username or find a challenge by title.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            if (_profile != null) ...[
              Text('People', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              _ProfileResult(profile: _profile!),
              const SizedBox(height: 24),
            ],
            if (_challenges.isNotEmpty) ...[
              Text('Challenges', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              ..._challenges.map(
                (challenge) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ChallengeCard(
                    challenge: challenge,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChallengeDetailScreen(slug: challenge.slug),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
