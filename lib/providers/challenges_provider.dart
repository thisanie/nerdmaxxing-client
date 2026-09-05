import 'package:flutter/foundation.dart';

import '../models/challenge.dart';
import '../services/challenges_service.dart';

class ChallengesProvider extends ChangeNotifier {
  final ChallengesService service;
  ChallengesProvider(this.service);

  List<Challenge> challenges = [];
  bool isLoading = false;
  bool hasMore = true;
  String? errorMessage;

  static const _pageSize = 20;

  Future<void> loadInitial() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      challenges = await service.list(limit: _pageSize, offset: 0);
      hasMore = challenges.length == _pageSize;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    notifyListeners();
    try {
      final next = await service.list(limit: _pageSize, offset: challenges.length);
      challenges = [...challenges, ...next];
      hasMore = next.length == _pageSize;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
