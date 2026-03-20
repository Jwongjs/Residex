import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/glass_card.dart';

class CalendarWidget extends StatelessWidget {
  final VoidCallback onOpenDetail;

  const CalendarWidget({
    super.key,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    // Generate next 14 days starting from today
    final days = List.generate(14, (i) {
      final date = DateTime.now().add(Duration(days: i));
      return _DayData(
        date: date,
        dayName: DateFormat('EEE').format(date).toUpperCase(),
        dayNumber: date.day,
        isToday: i == 0,
        // Mock data: assign tasks to some days
        taskCount: i == 0 ? 1 : i == 2 ? 2 : i == 5 ? 1 : 0,
      );
    });

    return GlassCard(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        colors: [
          AppColors.purple500.withValues(alpha: 0.05),
          AppColors.indigo500.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppColors.purple500.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and redirect arrow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.purple500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.purple500.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.calendar,
                      color: AppColors.purple500,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'UPCOMING TASKS',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: onOpenDetail,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Horizontal scrollable dates
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final day = days[index];
                return _DateCard(
                  day: day,
                  onTap: onOpenDetail,
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),

          const SizedBox(height: 12),

          // Next task preview
          GestureDetector(
            onTap: onOpenDetail,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.purple500,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple500.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kitchen Duty',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            size: 10,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Today, 09:00 PM',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Text(
                    '20 HP',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final _DayData day;
  final VoidCallback onTap;

  const _DateCard({
    required this.day,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = day.isToday;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 80,
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.purple500
              : AppColors.slate800.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday
                ? AppColors.purple500
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: AppColors.purple500.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.dayName,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isToday
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day.dayNumber.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isToday ? Colors.white : AppColors.textSecondary,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            // Task indicators
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: day.taskCount > 0
                    ? List.generate(
                        day.taskCount > 3 ? 3 : day.taskCount,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Colors.white
                                  : AppColors.purple500,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                    : [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayData {
  final DateTime date;
  final String dayName;
  final int dayNumber;
  final bool isToday;
  final int taskCount;

  _DayData({
    required this.date,
    required this.dayName,
    required this.dayNumber,
    required this.isToday,
    required this.taskCount,
  });
}
