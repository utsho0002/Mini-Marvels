import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project_1/user_authentication/role_screen.dart';

class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Timer? _splashTimer;

  static const Color purple = Color(0xFF6C2CF4);
  static const Color yellow = Color(0xFFFFC914);
  static const Color softBlue = Color(0xFFE9F7FF);
  static const Color softLavender = Color(0xFFF3EDFF);

  // Public-domain web image used for the splash mascot.
  static const String mascotImageUrl =
      'https://freesvg.org/img/kablam-Super-Hero-Flame.png';

  @override
  void initState() {
    super.initState();

    // Gives the logo area a soft floating motion.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Opens the role screen after the splash delay.
    _splashTimer = Timer(const Duration(seconds: 5), _goToRoleScreen);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // Moves from the splash screen to role selection.
  void _goToRoleScreen() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const RoleScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FF),
      body: Center(
        child: Container(
          width: screenSize.width,
          height: screenSize.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                softLavender,
                softBlue,
              ],
            ),
          ),
          child: Stack(
            children: [
              const _SplashBackgroundDots(),
              Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final double floatValue =
                        math.sin(_animationController.value * math.pi) * 7;

                    return Transform.translate(
                      offset: Offset(0, -floatValue),
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMascotImage(),
                      const SizedBox(height: 10),
                      _buildLogoText(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Shows the web mascot image with a small fallback if loading fails.
  Widget _buildMascotImage() {
    return Container(
      width: 210,
      height: 205,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        shape: BoxShape.circle,
      ),
      child: Image.network(
        mascotImageUrl,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const Center(
            child: CircularProgressIndicator(
              color: purple,
              strokeWidth: 2.5,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.auto_awesome_rounded,
              color: purple,
              size: 90,
            ),
          );
        },
      ),
    );
  }

  // Builds the English-only Mini Marvels logo text.
  Widget _buildLogoText() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'The ',
                style: TextStyle(
                  color: purple,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: 'Mini',
                style: TextStyle(
                  color: purple,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                ),
              ),
              TextSpan(
                text: ' ',
                style: TextStyle(fontSize: 6),
              ),
              TextSpan(
                text: 'Marvels',
                style: TextStyle(
                  color: yellow,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.auto_awesome_rounded,
              color: purple,
              size: 13,
            ),
            SizedBox(width: 7),
            Text(
              'Mini Marvels',
              style: TextStyle(
                color: purple,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(width: 7),
            Icon(
              Icons.auto_awesome_rounded,
              color: purple,
              size: 13,
            ),
          ],
        ),
      ],
    );
  }
}

// Decorative circles and stars behind the splash logo.
class _SplashBackgroundDots extends StatelessWidget {
  const _SplashBackgroundDots();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        _CircleDot(top: 25, left: 112, size: 15, color: Color(0xFF8FD8FF)),
        _CircleDot(top: 135, right: 62, size: 19, color: Color(0xFFFFC400)),
        _CircleDot(top: 264, left: 50, size: 22, color: Color(0xFFD9EAFE)),
        _CircleDot(top: 337, left: 88, size: 10, color: Color(0xFF8B5CF6)),
        _StarDot(top: 54, right: 36, size: 28, color: Color(0xFFFFD679)),
        _StarDot(top: 115, left: 56, size: 22, color: Color(0xFFC4A5FF)),
        _StarDot(top: 365, left: 118, size: 27, color: Color(0xFFFFD679)),
        _StarDot(bottom: 33, right: 65, size: 17, color: Color(0xFFC4A5FF)),
      ],
    );
  }
}

// Small circular background decoration.
class _CircleDot extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  const _CircleDot({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// Small star decoration used around the splash logo.
class _StarDot extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  const _StarDot({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.72),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.star_rounded,
            color: Colors.white,
            size: 19,
          ),
        ),
      ),
    );
  }
}
