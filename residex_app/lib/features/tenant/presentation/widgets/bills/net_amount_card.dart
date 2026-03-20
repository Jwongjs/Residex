import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../core/widgets/glass_card.dart';

class NetAmountCard extends StatelessWidget {
  final String entityName;
  final double totalAmount;
  final VoidCallback onSettleAll;
  final int transactionCount;
  final String direction; // 'OUT' for you owe, 'IN' for owed to you

  const NetAmountCard({
    super.key,
    required this.entityName,
    required this.totalAmount,
    required this.onSettleAll,
    required this.transactionCount,
    this.direction = 'OUT',
  });

  @override
  Widget build(BuildContext context) {
    final isOwed = direction == 'OUT';
    final color = isOwed ? Colors.redAccent : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GlassCard(
        borderRadius: BorderRadius.circular( 20),
        padding: const EdgeInsets.all(20),
        opacity: 0.05,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.compress,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Amount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white60,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        entityName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  totalAmount.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.0,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Transaction count
            Text(
              'Consolidates $transactionCount transaction${transactionCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
              ),
            ),

            const SizedBox(height: 16),

            // Settle button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSettleAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isOwed ? 'Settle Net Amount' : 'Remind',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(
      begin: 0.2,
      end: 0.0,
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }
}
