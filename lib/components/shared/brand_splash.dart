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
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/images/logo_machakos.jpg',
                  fit: BoxFit.contain,
                  semanticLabel: 'MCCG Crest',
                ),
              ),
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
                color: AppColors.accent,
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
                  color: AppColors.accent,
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
