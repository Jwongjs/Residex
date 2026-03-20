import 'package:flutter/material.dart';
  import 'dart:ui';
  import '../../../../../core/theme/app_colors.dart';
  import '../../../../../core/widgets/glass_card.dart';

  class SummaryCards extends StatelessWidget {
    final int youOweCount;
    final int pendingTasksCount;
    final VoidCallback? onYouOweTap;
    final VoidCallback? onPendingTasksTap;

    const SummaryCards({
      super.key,
      required this.youOweCount,
      required this.pendingTasksCount,
      this.onYouOweTap,
      this.onPendingTasksTap,
    });

    @override
    Widget build(BuildContext context) {
      return Row(
        children: [
          // ========================================
          // YOU OWE CARD (OUTSTANDING BILLS)
          // Red themed card showing unpaid bills
          // ========================================
          Expanded(
            child: GestureDetector(
              onTap: onYouOweTap,
              child: Container(
                height: 112,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFDC2626).withValues(alpha: 0.2), // red-600/20
                      const Color(0xFF7F1D1D).withValues(alpha: 0.1), // red-900/10
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.red500.withValues(alpha: 0.2),
                    width: 1,
                  ),
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
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Red receipt icon
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.red500,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.red500.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),

                            const Spacer(),

                            // Title
                            Text(
                              'You Owe',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),

                            const SizedBox(height: 2),

                            // Subtitle "OUTSTANDING"
                            Text(
                              'OUTSTANDING',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFCA5A5), // red-300
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
                          Icons.chevron_right,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ========================================
          // PENDING TASKS CARD (CHORES)
          // Purple themed card showing incomplete chores
          // ========================================
          Expanded(
            child: GestureDetector(
              onTap: onPendingTasksTap,
              child: Container(
                height: 112,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF9333EA).withValues(alpha: 0.2), // purple-600/20
                      const Color(0xFF581C87).withValues(alpha: 0.1), // purple-900/10
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.purple500.withValues(alpha: 0.2),
                    width: 1,
                  ),
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
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Purple checkmark icon
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.purple500,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.purple500.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),

                            const Spacer(),

                            // Title
                            Text(
                              'Pending Tasks',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),

                            const SizedBox(height: 2),

                            // Subtitle "CHORES"
                            Text(
                              'CHORES',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD8B4FE), // purple-300
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
                          Icons.chevron_right,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
