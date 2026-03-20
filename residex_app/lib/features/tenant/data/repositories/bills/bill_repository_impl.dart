  import 'package:dartz/dartz.dart';
  import '../../../../../core/errors/failures.dart';
  import '../../../../../core/errors/exceptions.dart';
  import '../../../domain/entities/bills/bill.dart';
  import '../../../domain/repositories/bills/bill_repository.dart';
  import '../../datasources/bills/bill_local_datasource.dart';
  import '../../models/bills/bill_model.dart';

  /// Implementation of BillRepository using local data source
  class BillRepositoryImpl implements BillRepository {
    final BillLocalDataSource localDataSource;

    BillRepositoryImpl({required this.localDataSource});

    @override
    Future<Either<Failure, List<Bill>>> getAllBills() async {
      try {
        final bills = await localDataSource.getAllBills();
        return Right(bills.map((model) => model.toEntity()).toList());
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to get bills: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, Bill?>> getBillById(String id) async {
      try {
        final bill = await localDataSource.getBillById(id);
        return Right(bill?.toEntity());
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to get bill: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, void>> saveBill(Bill bill) async {
      try {
        final billModel = BillModel.fromEntity(bill);
        await localDataSource.saveBill(billModel);
        return const Right(null);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to save bill: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, void>> updatePaymentStatus({
      required String billId,
      required String userId,
      required bool hasPaid,
    }) async {
      try {
        await localDataSource.updatePaymentStatus(
          billId: billId,
          userId: userId,
          hasPaid: hasPaid,
        );
        return const Right(null);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to update payment status: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, void>> deleteBill(String billId) async {
      try {
        await localDataSource.deleteBill(billId);
        return const Right(null);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to delete bill: ${e.toString()}'));
      }
    }
  }
