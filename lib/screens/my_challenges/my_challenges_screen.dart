import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/participation.dart';
import '../../providers/participation_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class MyChallengesScreen extends StatefulWidget {
  const MyChallengesScreen({super.key});

  @override
  State<MyChallengesScreen> createState() => _MyChallengesScreenState();
}

class _MyChallengesScreenState extends State<MyChallengesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParticipationProvider>().load();
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Accepted';
      case 'IN_PROGRESS':
        return 'In progress';
      case 'PAUSED':
        return 'Paused';
      case 'SUBMITTED':
        return 'Submitted';
      case 'COMPLETED':
        return 'Completed';
      default:
        return status;
    }
  }

  Future<void> _changeStatus(BuildContext context, Participation p, String status) async {
    try {
      await context.read<ParticipationProvider>().updateStatus(p.id, status);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParticipationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Challenges')),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ParticipationProvider provider) {
    if (provider.isLoading && provider.participations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.participations.isEmpty) {
      return const EmptyState(
        icon: Icons.flag_outlined,
        title: 'Your next interesting thing is waiting.',
        message: 'Discover a challenge and accept it to get started.',
      );
    }
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.participations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final p = provider.participations[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Challenge ${p.challengeId.substring(0, 6)}...',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(_statusLabel(p.status),
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (p.status == 'ACCEPTED')
                    TextButton(
                      onPressed: () => _changeStatus(context, p, 'IN_PROGRESS'),
                      child: const Text('Start'),
                    ),
                  if (p.status == 'IN_PROGRESS')
                    TextButton(
                      onPressed: () => _changeStatus(context, p, 'PAUSED'),
                      child: const Text('Pause'),
                    ),
                  if (p.status == 'PAUSED')
                    TextButton(
                      onPressed: () => _changeStatus(context, p, 'IN_PROGRESS'),
                      child: const Text('Resume'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
