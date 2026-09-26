import 'package:flutter/material.dart';

/// App color palette for Notesboard
/// Follows modern, calm, visual productivity aesthetics (light canvas, clean neutrals, subtle accents).
class AppColors {
  AppColors._();

  // Primary & Accent
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryMuted = Color(0xFFEFF6FF);

  // Canvas
  static const Color canvasBackground = Color(0xFFF8FAFC); // Very light slate
  static const Color canvasDot = Color(0xFFCBD5E1); // Slate 300
  static const Color canvasLine = Color(0xFFE2E8F0); // Slate 200

  // Surfaces & Cards
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderHover = Color(0xFFCBD5E1); // Slate 300
  static const Color borderSelected = Color(0xFF2563EB);

  // Text
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textInverse = Colors.white;

  // Notes and Card Accents
  static const Color noteDefault = Colors.white;
  static const Color noteYellow = Color(0xFFFEF9C3); // Soft yellow
  static const Color noteBlue = Color(0xFFE0F2FE); // Soft sky
  static const Color noteGreen = Color(0xFFDCFCE7); // Soft emerald
  static const Color notePurple = Color(0xFFF3E8FF); // Soft violet
  static const Color noteRose = Color(0xFFFFE4E6); // Soft rose

  // Connections
  static const Color connectionLine = Color(0xFF64748B); // Slate 500
  static const Color connectionSelected = Color(0xFF2563EB);
  static const Color connectionHighlight = Color(0xFF0EA5E9);

  // Group
  static const Color groupFill = Color(0x0C0F172A); // 5% slate overlay
  static const Color groupBorder = Color(0xFFCBD5E1); // Slate 300 dashed/subtle

  // Status & Utility
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // Shadows
  static const Color shadowColor = Color(0x0A0F172A);
  static const Color shadowColorHeavy = Color(0x1A0F172A);
}
