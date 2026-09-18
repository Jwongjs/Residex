import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart';

void main() {
  group('buildDocuMindAssistantText', () {
    test('appends the searched categories, never inline citations', () {
      final answer = DocuMindAnswer(
        answer: 'I can help with that.',
        confidence: 0.9,
        citations: [
          Citation(
            docId: 'doc-1',
            filename: 'lease.pdf',
            category: 'lease',
            page: 2,
            snippet: 'Pets are allowed.',
            score: 0.95,
          ),
        ],
        propertyName: 'Maple Residency',
        searchedCategories: ['lease'],
        categoryFilterMode: 'auto',
        actionReason: 'Predicted from question context',
      );

      final text = buildDocuMindAssistantText(
        answer: answer,
        categoryLabelResolver: (category) => category.toUpperCase(),
      );

      expect(text, startsWith('I can help with that.'));
      expect(text, contains('Categories: LEASE (auto-detected)'));
      // Citations are rendered by the citation widget attached to the chat
      // bubble (MessageOptions.bottom), not inlined in the assistant text.
      expect(text, isNot(contains('Sources:')));
    });
  });

  group('buildUnitScopeQuickReplies', () {
    Unit unit(String id, String label) => Unit(
          id: id,
          propertyId: 'prop-1',
          label: label,
          monthlyRent: 1000,
          isOccupied: true,
          createdAt: DateTime(2026, 1, 1),
        );

    test('lists each unit label followed by Whole property', () {
      final replies = buildUnitScopeQuickReplies([unit('u1', 'Unit A'), unit('u2', 'Unit B')]);

      expect(replies, ['Unit A', 'Unit B', 'Whole property']);
    });

    test('offers just Whole property when there are no units', () {
      final replies = buildUnitScopeQuickReplies(const []);

      expect(replies, ['Whole property']);
    });
  });

  group('resolveUnitScopeSelection', () {
    Unit unit(String id, String label) => Unit(
          id: id,
          propertyId: 'prop-1',
          label: label,
          monthlyRent: 1000,
          isOccupied: true,
          createdAt: DateTime(2026, 1, 1),
        );

    final units = [unit('u1', 'Unit A'), unit('u2', 'Unit B')];

    test('Whole property resolves to no unit filter', () {
      expect(resolveUnitScopeSelection('Whole property', units), isNull);
    });

    test('a unit label resolves to that unit\'s id', () {
      expect(resolveUnitScopeSelection('Unit B', units), 'u2');
    });

    test('an unrecognised label resolves to no unit filter', () {
      expect(resolveUnitScopeSelection('nonsense', units), isNull);
    });
  });
}