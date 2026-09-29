import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../auth/phone_login_screen.dart';
import '../auth/profile_setup_screen.dart';
import '../main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // Small splash delay for visual smoothness
    await Future.delayed(const Duration(milliseconds: 1200));

    final token = await _apiService.storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      _navigateToPhoneLogin();
      return;
    }

    try {
      final res = await _apiService.getProfile();
      if (mounted) {
        if (res['success'] == true && res['user'] != null) {
          final user = res['user'];
          final profileComplete = (user['profile_complete'] ?? 0) == 1;

          if (profileComplete) {
            // Token valid & Profile complete -> Auto login straight to Home
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
              (route) => false,
            );
          } else {
            // Profile incomplete -> Setup profile screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
              (route) => false,
            );
          }
        } else {
          // Token invalid or expired -> Clear token & go to Phone Login
          await _apiService.storage.delete(key: 'auth_token');
          _navigateToPhoneLogin();
        }
      }
    } catch (_) {
      // Offline / Network error fallback
      // If token exists in storage, allow offline access to Home
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    }
  }

  void _navigateToPhoneLogin() {
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3), width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SB CricScore',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Live Scoring & Tournament Platform',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: AppTheme.primaryGold, strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}
