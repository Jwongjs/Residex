  import 'package:dartz/dartz.dart';
  import '../../../../../core/errors/failures.dart';
  import '../../entities/bills/bill.dart';

  /// Abstract interface for bill data operations
  /// Implementation will be in the data layer
  abstract class BillRepository {
    /// Get all completed bills
    Future<Either<Failure, List<Bill>>> getAllBills();

    /// Get a single bill by ID
    Future<Either<Failure, Bill?>> getBillById(String id);

    /// Save a completed bill
    Future<Either<Failure, void>> saveBill(Bill bill);

    /// Update payment status for a user
    Future<Either<Failure, void>> updatePaymentStatus({
      required String billId,
      required String userId,
      required bool hasPaid,
    });

    /// Delete a bill
    Future<Either<Failure, void>> deleteBill(String billId);
  }
