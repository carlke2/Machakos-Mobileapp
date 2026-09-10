import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Official MCCG splash screen displaying the centered circular badge on Navy.
class BrandSplash extends StatelessWidget {
  const BrandSplash({
    super.key,
    this.showSpinner = true,
  });

  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1B3D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo_splash_circle.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              semanticLabel: 'MCCG Crest',
            ),
            const SizedBox(height: 24),
            const Text(
              'MCCG',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Emergency Operations Center',
              style: TextStyle(
                color: AppColors.brandGold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            if (showSpinner) ...[
              const SizedBox(height: 36),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: AppColors.primaryLight,
                  strokeWidth: 2.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
