import 'services/discover_service.dart';
import 'providers/discover_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;

import 'providers/app_state_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/challenges_provider.dart';
import 'providers/notification_badge_provider.dart';
import 'providers/skills_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/challenges_service.dart';
import 'services/evidence_service.dart';
import 'services/groups_service.dart';
import 'services/invitations_service.dart';
import 'services/notifications_service.dart';
import 'services/participation_service.dart';
import 'services/profile_service.dart';
import 'services/push_notification_service.dart';
import 'services/skills_service.dart';
import 'services/token_storage.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const NerdMaxxingApp());
}

class NerdMaxxingApp extends StatelessWidget {
  const NerdMaxxingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final authService = AuthService(api: apiClient, tokenStorage: tokenStorage);
    final pushNotificationService = PushNotificationService(
      api: apiClient,
      tokenStorage: tokenStorage,
    );
    final notificationsService = NotificationsService(apiClient);
    final notificationBadge = NotificationBadgeController(notificationsService);
    final notificationNavigation = NotificationNavigationController();
    pushNotificationService.onNotificationReceived = notificationBadge.increment;
    pushNotificationService.onNotificationTap =
      notificationNavigation.requestNotifications;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pushNotificationService.initialize();
    });

    return ProviderScope(
      overrides: [
        participationServiceProvider.overrideWithValue(
          ParticipationService(apiClient),
        ),
        profileServiceProvider.overrideWithValue(ProfileService(apiClient)),
      ],
      child: MultiProvider(
        providers: [
        Provider.value(value: apiClient),
        Provider.value(value: authService),
        Provider.value(value: pushNotificationService),
        Provider(create: (_) => ChallengesService(apiClient)),
        Provider(create: (_) => ParticipationService(apiClient)),
        Provider(create: (_) => ProfileService(apiClient)),
        Provider(create: (_) => EvidenceService(apiClient)),
        Provider(create: (_) => GroupsService(apiClient)),
        Provider(create: (_) => InvitationsService(apiClient)),
        Provider.value(value: notificationsService),
        ChangeNotifierProvider.value(value: notificationBadge),
        ChangeNotifierProvider.value(value: notificationNavigation),
        Provider(create: (_) => DiscoverService(apiClient)),
        Provider(create: (_) => SkillsService(apiClient)),
        ChangeNotifierProvider(
          create: (context) {
            final auth = AuthProvider(
              authService: authService,
              pushNotificationService: pushNotificationService,
              tokenStorage: tokenStorage,
            );
            apiClient.onSessionExpired = auth.forceSignOut;
            return auth;
          },
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ChallengesProvider(context.read<ChallengesService>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              DiscoverProvider(context.read<DiscoverService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => SkillsProvider(context.read<SkillsService>()),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: Builder(
          builder: (context) {
            final themeProvider = context.watch<ThemeProvider>();
            return MaterialApp(
              title: 'NERDMAXXING',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProvider.themeMode,
              home: const AuthGate(),
            );
          },
        ),
      ),
    );
  }
}
