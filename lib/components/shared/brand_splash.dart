import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// In-app splash screen matching Malteser-NMS BrandSplash component.
/// Displays the primary brand background (#005A32), centered logo, and an onPrimary spinner.
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
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
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
                ),
              ),
            ),
            if (showSpinner) ...[
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColors.onPrimary,
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
