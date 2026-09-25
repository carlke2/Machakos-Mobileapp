import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralised helper for showing consistently-styled toast notifications.
///
/// Usage:
/// ```dart
/// AppSnackBar.show(context, 'Item checked out successfully');
/// AppSnackBar.show(context, 'Something went wrong', isError: true);
/// ```
abstract final class AppSnackBar {
  /// Shows a floating [SnackBar] with semantic status colours.
  ///
  /// * [isError] `true`  → red background  ([AppColors.danger])
  /// * [isError] `false` → green background ([AppColors.success])
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.onPrimary),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
