import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/participation.dart';
import '../models/progress_log.dart';
import '../models/user_stats.dart';
import '../services/participation_service.dart';
import '../services/profile_service.dart';

final participationServiceProvider = Provider<ParticipationService>(
  (ref) => throw UnimplementedError('ParticipationService is not configured.'),
);

final profileServiceProvider = Provider<ProfileService>(
  (ref) => throw UnimplementedError('ProfileService is not configured.'),
);

final participationControllerProvider = AsyncNotifierProvider<
  ParticipationController,
  List<Participation>
>(ParticipationController.new);

final progressLogsProvider = FutureProvider.autoDispose
    .family<List<ProgressLog>, String>((ref, participantId) async {
      final service = ref.watch(participationServiceProvider);
      return service.listProgress(participantId, limit: 100);
    });

final myStatsProvider = FutureProvider.autoDispose<UserStats>((ref) {
  return ref.watch(profileServiceProvider).getMyStats();
});

final myCompletedChallengesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(profileServiceProvider).listMyCompletedChallenges();
});

final myCreatedChallengesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(profileServiceProvider).listMyCreatedChallenges();
});

class ParticipationController extends AsyncNotifier<List<Participation>> {
  ParticipationService get _service => ref.read(participationServiceProvider);

  @override
  Future<List<Participation>> build() => _service.listMine();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.listMine);
  }

  Future<Participation> accept(String slug) async {
    final participation = await _service.accept(slug);
    _replace(participation);
    return participation;
  }

  Future<Participation> updateStatus(
    String participantId,
    String status,
  ) async {
    final participation = await _service.updateStatus(participantId, status);
    _replace(participation);
    return participation;
  }

  Future<ProgressLog> logProgress(
    String participantId, {
    required double hoursSpent,
    String? note,
  }) async {
    final log = await _service.logProgress(
      participantId,
      hoursSpent: hoursSpent,
      note: note,
    );
    ref.invalidate(progressLogsProvider(participantId));
    ref.invalidate(myStatsProvider);
    ref.invalidate(myCompletedChallengesProvider);
    ref.invalidate(myCreatedChallengesProvider);
    ref.invalidate(participationControllerProvider);
    return log;
  }

  void add(Participation participation) => _replace(participation);

  Participation? forChallenge(String challengeId) {
    final items = state.valueOrNull ?? const <Participation>[];
    for (final participation in items) {
      if (participation.challengeId == challengeId) return participation;
    }
    return null;
  }

  void _replace(Participation participation) {
    final current = state.valueOrNull ?? const <Participation>[];
    state = AsyncData([
      participation,
      ...current.where((item) => item.id != participation.id),
    ]);
    ref.invalidate(myStatsProvider);
  }
}