import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateProvider is legacy in Riverpod 3.x
import '../../domain/entities/finance_summary.dart';
import 'documind_provider.dart';
import 'finance_logic.dart';
import 'property_providers.dart';

/// Selected Finance-tab year (defaults to the current year).
final financeYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// Year-selector options, derived from the extracted facts on the
/// landlord's documents plus the current year.
final financeYearsProvider = FutureProvider<List<int>>((ref) async {
  final useCase = ref.watch(listDocumentsUseCaseProvider);
  final docs = await useCase();
  final properties = await ref.watch(propertiesProvider.future);
  final trackFromByProperty = {
    for (final property in properties) property.id: property.trackFromYear,
  };
  return financeYearOptions(
    docs,
    DateTime.now().year,
    trackFromByProperty: trackFromByProperty,
  );
});

/// Finance summary for one calendar year. Compute-on-read: the backend
/// folds extracted facts fresh on every request — no schedule, zero LLM.
final financeSummaryProvider =
    FutureProvider.family<FinanceSummary, int>((ref, year) async {
  final repository = ref.watch(documindRepositoryProvider);
  return repository.getFinanceSummary(year: year);
});
