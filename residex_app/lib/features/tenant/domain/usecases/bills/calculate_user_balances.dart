  import '../../entities/bills/bill.dart';

  /// Use case for calculating user balances across all bills
  class CalculateUserBalances {
    /// Calculate balances for a specific user
    ///
    /// Returns a map with:
    /// - 'youOwe': total amount user owes (unpaid bills)
    /// - 'owedToYou': total amount owed to user (others haven't paid)
    Map<String, double> call({
      required String userId,
      required List<Bill> bills,
    }) {
      double youOwe = 0.0;
      double owedToYou = 0.0;

      for (final bill in bills) {
        // Calculate what current user owes
        final userShare = bill.getShareForUser(userId);
        final userHasPaid = bill.hasUserPaid(userId);

        if (!userHasPaid && userShare > 0) {
          youOwe += userShare;
        }

        // Calculate what others owe (relevant if user organized the bill)
        for (final participantId in bill.participantIds) {
          if (participantId == userId) continue; // Skip self

          final participantShare = bill.getShareForUser(participantId);
          final participantHasPaid = bill.hasUserPaid(participantId);

          if (!participantHasPaid && participantShare > 0) {
            // Others owe money on this bill
            // This is simplified - in reality you'd check if current user paid for them
            owedToYou += participantShare;
          }
        }
      }

      return {
        'youOwe': youOwe,
        'owedToYou': owedToYou,
      };
    }
  }
