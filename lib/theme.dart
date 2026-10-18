import 'package:flutter/material.dart';

/// Matcha palette, taken straight from the AgriSense web app (src/theme.js).
class C {
  static const bg = Color(0xFFEDF1E1);
  static const well = Color(0xFFE3EAD3);
  static const cardTop = Color(0xFFFBFCF4);
  static const cardBottom = Color(0xFFEBF0DC);
  static const matchaLight = Color(0xFF9DBA72);
  static const matchaDark = Color(0xFF6F8F45);
  static const matcha = Color(0xFF7E9C54);
  static const matchaDeep = Color(0xFF4F6B2C);
  static const matchaInk = Color(0xFF34471D);
  static const ink = Color(0xFF2A3320);
  static const mute = Color(0xFF7D8869);
  static const faint = Color(0xFFA7B190);
  static const shadow = Color(0xFF58703A);
  static const temp = Color(0xFFCF8A52);
  static const hum = Color(0xFF6E9EA3);
  static const soil = Color(0xFF5F7F3A);
  static const ok = Color(0xFF6F8F45);
  static const warn = Color(0xFFC98A3C);
  static const bad = Color(0xFFB45742);
}

TextStyle nunito(double size, {FontWeight w = FontWeight.w600, Color color = C.ink, double? height, double? spacing}) =>
    TextStyle(fontFamily: 'Nunito', fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: spacing);
