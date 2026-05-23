import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    // Navigate to AuthenticationWrapper after 2.5 seconds
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthenticationWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Ambient Elements (Subtle Gold/Brass and Forest Green Tonal Shifts)
          Positioned(
            top: -screenHeight * 0.1,
            right: -screenWidth * 0.1,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(
                width: screenWidth * 0.7,
                height: screenWidth * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryAccent.withOpacity(0.06), // Gold/Brass accent
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -screenHeight * 0.1,
            left: -screenWidth * 0.1,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(
                width: screenWidth * 0.7,
                height: screenWidth * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.08), // Forest Green primary
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  
                  // App Logo (Designed in Stitch project)
                  const AppLogo(
                    size: 130,
                    showShadow: true,
                  ),
                  const SizedBox(height: 32),
                  
                  // App Title (EB Garamond)
                  Text(
                    'Flute Practice Coach',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // App Subtitle (Hanken Grotesk)
                  Text(
                    'Your AI-Powered Instrumental Coach',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Spinkit Loading Animation
                  const SpinKitDoubleBounce(
                    color: AppTheme.primaryAccent,
                    size: 40.0,
                  ),
                  
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
