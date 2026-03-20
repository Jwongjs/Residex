  import '../../entities/bills/receipt_item.dart';
  import '../../entities/bills/bill_enums.dart';

  /// Use case for calculating how bills are split among users
  /// Based on item assignments and tax distribution
  class CalculateBillSplits {
    /// Calculate shares for each user
    ///
    /// Parameters:
    /// - items: All receipt items (including tax/discount)
    /// - assignments: Map of itemId -> Map of userId -> quantity assigned
    ///
    /// Returns: Map of userId -> total amount owed
    Map<String, double> call({
      required List<ReceiptItem> items,
      required Map<String, Map<String, int>> assignments,
    }) {
      final shares = <String, double>{};

      // Step 1: Calculate base item shares
      for (final item in items.where((i) => i.type == ReceiptItemType.item)) {
        final itemAssignments = assignments[item.id] ?? {};

        // Calculate total quantity assigned for this item
        final totalAssignedQty = itemAssignments.values.fold<int>(0, (sum, qty) => sum +
  qty);

        if (totalAssignedQty == 0) continue; // Skip unassigned items

        // Calculate price per unit
        final pricePerUnit = item.totalPrice / totalAssignedQty;

        // Distribute to users based on their assigned quantity
        for (final entry in itemAssignments.entries) {
          final userId = entry.key;
          final quantity = entry.value;
          shares[userId] = (shares[userId] ?? 0) + (pricePerUnit * quantity);
        }
      }

      // Step 2: Distribute taxes proportionally
      final totalBeforeTax = shares.values.fold<double>(0, (sum, amount) => sum + amount);

      if (totalBeforeTax > 0) {
        final taxItems = items.where((i) => i.type == ReceiptItemType.tax);
        final totalTax = taxItems.fold<double>(0, (sum, tax) => sum + tax.totalPrice);

        // Distribute tax proportionally to each user's share
        for (final userId in shares.keys) {
          final proportion = shares[userId]! / totalBeforeTax;
          shares[userId] = shares[userId]! + (totalTax * proportion);
        }
      }

      // Step 3: Apply discounts proportionally (if any)
      final discountItems = items.where((i) => i.type == ReceiptItemType.discount);
      final totalDiscount = discountItems.fold<double>(0, (sum, disc) => sum +
  disc.totalPrice);

      if (totalDiscount > 0 && totalBeforeTax > 0) {
        for (final userId in shares.keys) {
          final proportion = shares[userId]! / (totalBeforeTax +
  shares.values.fold<double>(0, (sum, amount) => sum + amount));
          shares[userId] = shares[userId]! - (totalDiscount * proportion);
        }
      }

      return shares;
    }
  }
