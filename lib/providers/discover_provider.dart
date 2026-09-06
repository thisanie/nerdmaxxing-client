import 'package:flutter/foundation.dart';

import '../models/discover.dart';
import '../services/discover_service.dart';

class DiscoverProvider extends ChangeNotifier {
  final DiscoverService service;
  DiscoverProvider(this.service);

  DiscoverFeed feed = const DiscoverFeed();
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      feed = await service.getFeed();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
