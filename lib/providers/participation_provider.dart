import 'package:flutter/foundation.dart';

import '../models/participation.dart';
import '../services/participation_service.dart';

class ParticipationProvider extends ChangeNotifier {
  final ParticipationService service;
  ParticipationProvider(this.service);

  List<Participation> participations = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      participations = await service.listMine();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Participation? forChallenge(String challengeId) {
    for (final p in participations) {
      if (p.challengeId == challengeId) return p;
    }
    return null;
  }

  Future<Participation> accept(String slug) async {
    final participation = await service.accept(slug);
    participations = [participation, ...participations];
    notifyListeners();
    return participation;
  }

  Future<Participation> updateStatus(String participantId, String status) async {
    final updated = await service.updateStatus(participantId, status);
    participations = participations.map((p) => p.id == participantId ? updated : p).toList();
    notifyListeners();
    return updated;
  }
}
