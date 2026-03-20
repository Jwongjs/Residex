import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/screens/3-REX/sub/documind_chat_logic.dart';

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
      expect(text, contains('🏷️ Categories: LEASE (clarified)'));
      expect(text, contains('📚 Sources:'));
      expect(text, contains('lease.pdf'));
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
}