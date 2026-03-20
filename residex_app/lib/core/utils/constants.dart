import 'package:flutter/material.dart';
class AnimationConstants {
  // Durations
  static const Duration splash = Duration(milliseconds: 1500);
  static const Duration splitAnimation = Duration(milliseconds: 1800);
  static const Duration normalTransition = Duration(milliseconds: 500);
  static const Duration slowTransition = Duration(milliseconds: 700);

  // Curves matching React cubic-bezier values
  static const Curve spring = Cubic(0.35, 1.2, 0.35, 1.0);
  static const Curve ios = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Curve smooth = Cubic(0.2, 0.8, 0.2, 1.0);

  // Delays
  static const Duration staggerDelay = Duration(milliseconds: 50);
  static const Duration itemDelay = Duration(milliseconds: 75);
}