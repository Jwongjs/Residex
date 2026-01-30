import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Large financial overview card with revenue display
/// 
/// Usage:
/// ```dart
/// HeroFinancialCard(
///   amount: 14250.00,
///   currency: 'RM',
///   changePercentage: 8.4,
///   period: 'this month',
/// )
/// ```
class HeroFinancialCard extends StatelessWidget {
  final double amount;
  final String currency;
  final double changePercentage;
  final String period;

  const HeroFinancialCard({
    super.key,
    required this.amount,
    required this.currency,
    this.changePercentage = 0.0,
    this.period = 'this month',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface.withOpacity(0.9),
              Colors.black,
              Colors.black,
            ],
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Stack(
          children: [
            // Background icon
            Positioned(
              top: 24,
              right: 24,
              child: Icon(
                Icons.attach_money,
                size: 120,
                color: AppColors.primary.withOpacity(0.2),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROJECTED REVENUE',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currency,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textDisabled,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        amount.toStringAsFixed(0),
                        style: AppTextStyles.heading1.copyWith(
                          fontSize: 48,
                          letterSpacing: -2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 12,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+${changePercentage.toStringAsFixed(1)}% ${period.toUpperCase()}',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
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