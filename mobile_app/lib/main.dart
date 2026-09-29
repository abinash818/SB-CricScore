import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/fcm_service.dart';
import 'core/theme.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FcmService().initialize();
  runApp(
    const ProviderScope(
      child: SBCricScoreApp(),
    ),
  );
}

class SBCricScoreApp extends StatelessWidget {
  const SBCricScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SB CricScore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
