import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/challenges_provider.dart';
import '../../widgets/challenge_card.dart';
import '../../widgets/empty_state.dart';
import '../challenge/challenge_detail_screen.dart';
import '../challenge/create_challenge_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChallengesProvider>().loadInitial();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        context.read<ChallengesProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create a challenge',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateChallengeScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ChallengesProvider provider) {
    if (provider.isLoading && provider.challenges.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null && provider.challenges.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off,
        title: 'Couldn\'t load challenges',
        message: provider.errorMessage!,
        actionLabel: 'Try again',
        onAction: () => provider.loadInitial(),
      );
    }
    if (provider.challenges.isEmpty) {
      return const EmptyState(
        icon: Icons.explore_outlined,
        title: 'Nothing here yet.',
        message: 'More interesting things are coming.',
      );
    }
    return RefreshIndicator(
      onRefresh: provider.loadInitial,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: provider.challenges.length + (provider.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index >= provider.challenges.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final challenge = provider.challenges[index];
          return ChallengeCard(
            challenge: challenge,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChallengeDetailScreen(slug: challenge.slug)),
            ),
          );
        },
      ),
    );
  }
}
