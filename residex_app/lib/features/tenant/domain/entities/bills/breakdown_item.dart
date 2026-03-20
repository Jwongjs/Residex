import 'package:equatable/equatable.dart';
import 'bill.dart';
import '../../../../shared/domain/entities/users/app_user.dart';

/// Represents a single breakdown item in the You Owe/Owed tree view
 class BreakdownItem extends Equatable {
    final Bill bill;
    final double amount;
    final String direction; // 'IN' or 'OUT'
    final String? personId; // If breakdown is by person
    final String? groupId; // If breakdown is by group
    final bool isPending; // Bill status for badge display

    const BreakdownItem({
      required this.bill,
      required this.amount,
      required this.direction,
      this.personId,
      this.groupId,
      required this.isPending,
    });

    @override
    List<Object?> get props => [bill.id, amount, direction, personId, groupId, isPending];
  }

/// Helper to group breakdown items by person or group
class BreakdownGroup extends Equatable {
  final String entityId; // Person or group ID
  final String entityName;
  final String? entityEmoji; // For groups
  final int? entityColor; // For groups
  final List<BreakdownItem> items;
  final double totalAmount;
  final AppUser? user;

  const BreakdownGroup({
    required this.entityId,
    required this.entityName,
    this.entityEmoji,
    this.entityColor,
    required this.items,
    required this.totalAmount,
    this.user
  });

  bool get isGroup => entityEmoji != null;

  @override
  List<Object?> get props => [entityId, items, totalAmount];
}
