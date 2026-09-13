import 'package:flutter/foundation.dart';

import '../services/notifications_service.dart';

class NotificationBadgeController extends ChangeNotifier {
  final NotificationsService service;

  int unreadCount = 0;

  NotificationBadgeController(this.service);

  Future<void> refresh() async {
    try {
      final notifications = await service.list(unreadOnly: true, limit: 100);
      unreadCount = notifications.where((notification) => !notification.isRead).length;
      notifyListeners();
    } catch (_) {
      // The badge is non-critical and should not affect the rest of the app.
    }
  }

  void increment() {
    unreadCount++;
    notifyListeners();
  }

  void markRead() {
    if (unreadCount == 0) return;
    unreadCount--;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    unreadCount = 0;
    notifyListeners();
    try {
      final notifications = await service.list(unreadOnly: true, limit: 100);
      final unread = notifications.where((notification) => !notification.isRead);
      await Future.wait(unread.map((notification) => service.markRead(notification.id)));
    } catch (_) {
      // The screen can still display notifications if marking them fails.
    }
  }
}