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
    test('shows categories, never inline options or citations', () {
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

      // The category checkpoint is gone: no Confirm prompt, no bullets.
      expect(text, isNot(contains('Tap Confirm')));
      expect(text, isNot(contains('• lease')));
      expect(text, contains('Categories: LEASE (clarified)'));
      // Citations are rendered by the citation widget attached to the chat
      // bubble (MessageOptions.bottom), not inlined in the assistant text.
      expect(text, isNot(contains('Sources:')));
    });
  });

  group('buildDocuMindQuickReplies', () {
    test('returns no replies when no action is required', () {
      final answer = DocuMindAnswer(
        answer: 'Done.',
        confidence: 0.9,
        citations: const [],
        propertyName: 'Property',
      );

      expect(buildDocuMindQuickReplies(answer), isEmpty);
    });

    test('lists unit labels and a canonical All units entry', () {
      final answer = DocuMindAnswer(
        answer: 'Which unit do you mean?',
        confidence: 0.6,
        citations: const [],
        propertyName: 'Property',
        userActionRequired: true,
        needsUnitClarification: true,
        unitOptions: [
          UnitOption(unitId: 'unit-A', unitLabel: 'Unit A-12-03'),
          UnitOption(unitId: 'unit-B', unitLabel: 'Unit B-08-11'),
          // Backend "all" pseudo-option must not duplicate the appended one.
          UnitOption(unitId: 'all', unitLabel: 'All units'),
        ],
      );

      expect(buildDocuMindQuickReplies(answer),
          ['Unit A-12-03', 'Unit B-08-11', 'All units']);
    });

    test('every quick reply round-trips through mapDocuMindUserAction', () {
      const categories = ['lease', 'warranty', 'insurance', 'utility', 'receipt'];
      final unitOptions = [
        UnitOption(unitId: 'unit-A', unitLabel: 'Unit A-12-03'),
        UnitOption(unitId: 'all', unitLabel: 'All units'),
      ];
      final unitAnswer = DocuMindAnswer(
        answer: 'Which unit?',
        confidence: 0.6,
        citations: const [],
        propertyName: 'Property',
        userActionRequired: true,
        needsUnitClarification: true,
        unitOptions: unitOptions,
      );

      for (final reply in buildDocuMindQuickReplies(unitAnswer)) {
        final action = mapDocuMindUserAction(
          awaitingUserAction: true,
          messageText: reply,
          categories: categories,
          unitOptions: unitOptions,
        );
        expect(action, isNotNull, reason: 'unit reply "$reply" must map');
        expect(action, startsWith('unit:'));
      }
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

    test('exact unit label wins over a prefix-colliding label', () {
      final collidingOptions = [
        UnitOption(unitId: 'unit-a', unitLabel: 'Unit A'),
        UnitOption(unitId: 'unit-a1', unitLabel: 'Unit A1'),
        UnitOption(unitId: 'all', unitLabel: 'All units'),
      ];
      final action = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'Unit A1',
        categories: categories,
        unitOptions: collidingOptions,
      );
      expect(action, 'unit:unit-a1');
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

      expect(text, contains('Tap a unit below'));
      // Unit options render as quick-reply chips, not inline bullets.
      expect(text, isNot(contains('• Unit A')));
      expect(text, isNot(contains('Confirm')));
    });
  });
}