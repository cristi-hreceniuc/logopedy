// lib/core/utils/snackbar_utils.dart
import 'package:flutter/material.dart';

class SnackBarUtils {
  static void showMessage(
    BuildContext context, 
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? textColor,
  }) {
    // Remove any existing SnackBars first
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // Show the new SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    showMessage(
      context,
      message,
      backgroundColor: Colors.red.shade600,
      textColor: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    showMessage(
      context,
      message,
      backgroundColor: Colors.green.shade600,
      textColor: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  static void showInfo(BuildContext context, String message) {
    showMessage(
      context,
      message,
      backgroundColor: Colors.blue.shade600,
      textColor: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}
