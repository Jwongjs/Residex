  import 'package:dartz/dartz.dart';
  import '../../../../../core/errors/failures.dart';
  import '../../repositories/bills/bill_repository.dart';

  /// Use case for updating payment status for a user on a bill
  class UpdatePaymentStatus {
    final BillRepository repository;

    UpdatePaymentStatus(this.repository);

    /// Update payment status
    Future<Either<Failure, void>> call({
      required String billId,
      required String userId,
      required bool hasPaid,
    }) async {
      return await repository.updatePaymentStatus(
        billId: billId,
        userId: userId,
        hasPaid: hasPaid,
      );
    }
  }
