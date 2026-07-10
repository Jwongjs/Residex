import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart';

void main() {
  group('mapDocuMindUserAction', () {
    const categories = ['lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'];

    test('returns null when not awaiting action', () {
      final action = mapDocuMindUserAction(
        awaitingUserAction: false,
        messageText: 'confirm',
        categories: categories,
      );

      expect(action, isNull);
    });

    test('maps confirm and cancel actions', () {
      final confirmAction = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'confirm please',
        categories: categories,
      );
      final cancelAction = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'cancel it',
        categories: categories,
      );

      expect(confirmAction, 'confirm');
      expect(cancelAction, 'cancel');
    });

    test('maps category mention to override action', () {
      final action = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'use warranty category',
        categories: categories,
      );

      expect(action, 'override:warranty');
    });
  });

  group('buildDocuMindAssistantText', () {
    test('includes options, categories, and citations', () {
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
        categoryFilterMode: 'clarification_selected',
        userActionRequired: true,
        clarificationOptions: ['lease', 'warranty'],
        actionReason: 'Predicted from question context',
      );

      final text = buildDocuMindAssistantText(
        answer: answer,
        categoryLabelResolver: (category) => category.toUpperCase(),
      );

      expect(text, contains('Reply with `confirm` or `cancel`'));
      expect(text, contains('• lease'));
      expect(text, contains('Categories: LEASE (clarified)'));
      // Citations are rendered by the citation widget attached to the chat
      // bubble (MessageOptions.bottom), not inlined in the assistant text.
      expect(text, isNot(contains('Sources:')));
    });

    test('falls back to predicted categories when clarification options empty', () {
      final answer = DocuMindAnswer(
        answer: 'Please confirm.',
        confidence: 0.8,
        citations: const [],
        propertyName: 'Property',
        userActionRequired: true,
        clarificationOptions: const [],
        predictedCategories: const ['insurance'],
      );

      final text = buildDocuMindAssistantText(
        answer: answer,
        categoryLabelResolver: (category) => category,
      );

      expect(text, contains('• insurance'));
    });
  });

  group('mapDocuMindUserAction unit clarification', () {
    const categories = ['lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'];
    final unitOptions = [
      UnitOption(unitId: 'unit-A', unitLabel: 'Unit A'),
      UnitOption(unitId: 'unit-B', unitLabel: 'Unit B'),
      UnitOption(unitId: 'all', unitLabel: 'All units'),
    ];

    test('maps typed unit label to unit action preserving id casing', () {
      final action = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'unit a',
        categories: categories,
        unitOptions: unitOptions,
      );

      expect(action, 'unit:unit-A');
    });

    test('maps all units reply to unit:all sentinel', () {
      final action = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'all units',
        categories: categories,
        unitOptions: unitOptions,
      );

      expect(action, 'unit:all');
    });

    test('does not map category overrides while a unit checkpoint is pending', () {
      final action = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'lease',
        categories: categories,
        unitOptions: unitOptions,
      );

      expect(action, isNull);
    });
  });

  group('buildDocuMindAssistantText unit clarification', () {
    test('renders unit options for a unit clarification checkpoint', () {
      final answer = DocuMindAnswer(
        answer:
            'That question matches documents from Unit A and Unit B. Which unit do you mean?',
        confidence: 0.6,
        citations: const [],
        propertyName: 'Maple Residency',
        userActionRequired: true,
        needsUnitClarification: true,
        unitOptions: [
          UnitOption(unitId: 'unit-A', unitLabel: 'Unit A'),
          UnitOption(unitId: 'unit-B', unitLabel: 'Unit B'),
          UnitOption(unitId: 'all', unitLabel: 'All units'),
        ],
      );

      final text = buildDocuMindAssistantText(
        answer: answer,
        categoryLabelResolver: (category) => category,
      );

      expect(text, contains('Reply with a unit'));
      expect(text, contains('• Unit A'));
      expect(text, contains('• All units'));
      expect(text, isNot(contains('`confirm`')));
    });
  });
}