import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/glass_card.dart';

  class ToolkitGrid extends StatelessWidget {
    final VoidCallback onRentalResumeClick;
    final VoidCallback onGhostModeClick;

    const ToolkitGrid({
      super.key,
      required this.onRentalResumeClick,
      required this.onGhostModeClick,
    });

    @override
    Widget build(BuildContext context) {
      return Row(
        children: [
          // Rental ID Resume
          Expanded(
            child: _ToolkitButton(
              icon: LucideIcons.fileText,
              title: 'Rental ID',
              subtitle: 'RESUME',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2563EB), // blue-600/20
                  Color(0xFF1E3A8A), // blue-900/10
                ],
              ),
              borderColor: AppColors.blue600.withValues(alpha: 0.2),
              iconColor: AppColors.blue600,
              subtitleColor: Color(0xFF93C5FD), // blue-300
              onTap: onRentalResumeClick,
            ),
          ),

          const SizedBox(width: 12),

          // Ghost Mode
          Expanded(
            child: _ToolkitButton(
              icon: LucideIcons.scan,
              title: 'Ghost Mode',
              subtitle: 'AR COMPARE',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0891B2), // cyan-600/20
                  Color(0xFF064E3B), // emerald-900/10
                ],
              ),
              borderColor: AppColors.cyan500.withValues(alpha: 0.2),
              iconColor: AppColors.cyan500,
              subtitleColor: Color(0xFF67E8F9), // cyan-300
              showPing: true,
              onTap: onGhostModeClick,
            ),
          ),
        ],
      );
    }
  }

  class _ToolkitButton extends StatelessWidget {
    final IconData icon;
    final String title;
    final String subtitle;
    final Gradient gradient;
    final Color borderColor;
    final Color iconColor;
    final Color subtitleColor;
    final bool showPing;
    final VoidCallback onTap;

    const _ToolkitButton({
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.gradient,
      required this.borderColor,
      required this.iconColor,
      required this.subtitleColor,
      this.showPing = false,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 112,
          decoration: BoxDecoration(
            gradient: gradient.scale(0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Backdrop blur effect
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon with optional ping
                      Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: iconColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: iconColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),

                          // Ping animation
                          if (showPing)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ).animate(onPlay: (controller) => controller.repeat())
                                .fadeIn(duration: 1.seconds)
                                .then()
                                .fadeOut(duration: 1.seconds)
                                .scale(
                                  begin: const Offset(1.0, 1.0),
                                  end: const Offset(1.2, 1.2),
                                  duration: 2.seconds,
                                ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 2),

                      // Subtitle
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: subtitleColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron icon
                Positioned(
                  top: 16,
                  right: 16,
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // Extension to scale gradient opacity
  extension on Gradient {
    Gradient scale(double opacity) {
      if (this is LinearGradient) {
        final linear = this as LinearGradient;
        return LinearGradient(
          begin: linear.begin,
          end: linear.end,
          colors: linear.colors
              .map((c) => c.withValues(alpha: c.a * opacity))
              .toList(),
        );
      }
      return this;
    }
  }
