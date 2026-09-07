import 'services/discover_service.dart';
import 'providers/discover_provider.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/challenges_provider.dart';
import 'providers/participation_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/skills_provider.dart';
import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/challenges_service.dart';
import 'services/evidence_service.dart';
import 'services/participation_service.dart';
import 'services/profile_service.dart';
import 'services/skills_service.dart';
import 'services/token_storage.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const NerdMaxxingApp());
}

class NerdMaxxingApp extends StatelessWidget {
  const NerdMaxxingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final authService = AuthService(api: apiClient, tokenStorage: tokenStorage);

    return MultiProvider(
      providers: [
        Provider.value(value: apiClient),
        Provider.value(value: authService),
        Provider(create: (_) => ChallengesService(apiClient)),
        Provider(create: (_) => ParticipationService(apiClient)),
        Provider(create: (_) => ProfileService(apiClient)),
        Provider(create: (_) => EvidenceService(apiClient)),
        Provider(create: (_) => DiscoverService(apiClient)),
        Provider(create: (_) => SkillsService(apiClient)),
        ChangeNotifierProvider(
          create: (context) {
            final auth = AuthProvider(
              authService: authService,
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
          create: (context) =>
              ParticipationProvider(context.read<ParticipationService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => ProfileProvider(context.read<ProfileService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => SkillsProvider(context.read<SkillsService>()),
        ),
      ],
      child: MaterialApp(
        title: 'NERDMAXXING',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const AuthGate(),
      ),
    );
  }
}
