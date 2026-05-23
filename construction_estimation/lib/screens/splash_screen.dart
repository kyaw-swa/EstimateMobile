import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart';

/// Brand splash shown at cold-start. Displays the app name + version for
/// ~1.5s then pushReplacement → [HomeScreen] so the splash never appears in
/// the back stack.
///
/// Version is hardcoded — keep in sync with `pubspec.yaml#version` when
/// bumping a release.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String version = '1.0.0';
  static const Duration showFor = Duration(milliseconds: 1500);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.showFor, _goHome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.calculate_outlined,
                      color: scheme.onPrimary,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'EzEstimate',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Construction Estimation',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Developed by',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onPrimary.withValues(alpha: 0.7),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Phoe Ku',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v${SplashScreen.version}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onPrimary.withValues(alpha: 0.6),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
