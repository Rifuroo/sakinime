import 'package:flutter/material.dart';

/// Centralized color constants matching React Native app design
/// All screens and widgets should use these colors for consistency
class AppColors {
  // Main Colors
  static const Color background = Color(0xFF0A0A0F);
  static const Color cardBg = Color(0xFF18181B);
  static const Color primary = Color(0xFFF59E0B); // Amber accent
  
  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF71717A);
  static const Color textSub = Color(0xFFA1A1AA);
  
  // Borders & Overlays
  static const Color border = Color.fromRGBO(255, 255, 255, 0.05);
  static const Color overlay = Color.fromRGBO(0, 0, 0, 0.6);
  
  // Gradients
  static const List<Color> cardGradient = [
    Colors.transparent,
    Color.fromRGBO(0, 0, 0, 0.6),
    Color.fromRGBO(0, 0, 0, 0.95),
  ];
  
  // Additional UI Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}
