  import 'package:dartz/dartz.dart';
  import '../../../../../core/errors/failures.dart';
  import '../../entities/bills/bill.dart';
  import '../../repositories/bills/bill_repository.dart';

  /// Use case for saving a completed bill to storage
  class SaveCompletedBill {
    final BillRepository repository;

    SaveCompletedBill(this.repository);

    /// Save the bill
    Future<Either<Failure, void>> call(Bill bill) async {
      // Could add validation here
      if (bill.participantIds.isEmpty) {
        return const Left(ValidationFailure('Bill must have at least one participant'));
      }

      if (bill.totalAmount <= 0) {
        return const Left(ValidationFailure('Bill total must be greater than zero'));
      }

      return await repository.saveBill(bill);
    }
  }
