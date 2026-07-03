import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_screen.dart';

void main() {
  testWidgets('DocuMind sends confirm as userAction after checkpoint prompt', (tester) async {
    final capturedUserActions = <String?>[];
    var callCount = 0;

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? sessionId,
      int conversationTurn = 1,
      String? userAction,
    }) async {
      capturedUserActions.add(userAction);
      callCount += 1;

      if (callCount == 1) {
        return DocuMindAnswer(
          answer: 'I can search your warranty docs. Please confirm.',
          confidence: 0.8,
          citations: const [],
          propertyName: 'Maple Residency',
          categoryFilterMode: 'clarification',
          userActionRequired: true,
          clarificationOptions: const ['warranty', 'lease'],
          predictedCategories: const ['warranty'],
          sessionId: 'session-1',
          conversationTurn: 1,
          actionReason: 'Detected coverage intent',
        );
      }

      return DocuMindAnswer(
        answer: 'Confirmed. Searching warranty documents now.',
        confidence: 0.9,
        citations: const [],
        propertyName: 'Maple Residency',
        categoryFilterMode: 'clarification_selected',
        searchedCategories: const ['warranty'],
        userActionRequired: false,
        sessionId: 'session-1',
        conversationTurn: 2,
      );
    }

    final testProperty = Property(
      id: 'prop-1',
      landlordId: 'landlord-1',
      name: 'Maple Residency',
      address: const PropertyAddress(
        street: '123 Main St',
        city: 'Kuala Lumpur',
        state: 'WP Kuala Lumpur',
        zipCode: '50000',
        country: 'Malaysia',
      ),
      type: PropertyType.apartment,
      purchasePrice: 500000,
      currentValue: 550000,
      totalUnits: 10,
      occupiedUnits: 9,
      monthlyRent: 2000,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'What does my warranty cover?',
      ),
    );
    await tester.pumpAndSettle();

    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'confirm',
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedUserActions.length, 2);
    expect(capturedUserActions[0], isNull);
    expect(capturedUserActions[1], 'confirm');
  });

  testWidgets('DocuMind sends override category action after checkpoint prompt', (tester) async {
    final capturedUserActions = <String?>[];
    var callCount = 0;

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? sessionId,
      int conversationTurn = 1,
      String? userAction,
    }) async {
      capturedUserActions.add(userAction);
      callCount += 1;

      if (callCount == 1) {
        return DocuMindAnswer(
          answer: 'I can search your lease docs. Please confirm or choose another category.',
          confidence: 0.8,
          citations: const [],
          propertyName: 'Maple Residency',
          categoryFilterMode: 'clarification',
          userActionRequired: true,
          clarificationOptions: const ['lease', 'warranty'],
          predictedCategories: const ['lease'],
          sessionId: 'session-2',
          conversationTurn: 1,
          actionReason: 'Detected lease-like intent',
        );
      }

      return DocuMindAnswer(
        answer: 'Understood. Switching to warranty category.',
        confidence: 0.9,
        citations: const [],
        propertyName: 'Maple Residency',
        categoryFilterMode: 'clarification_selected',
        searchedCategories: const ['warranty'],
        userActionRequired: false,
        sessionId: 'session-2',
        conversationTurn: 2,
      );
    }

    final testProperty = Property(
      id: 'prop-1',
      landlordId: 'landlord-1',
      name: 'Maple Residency',
      address: const PropertyAddress(
        street: '123 Main St',
        city: 'Kuala Lumpur',
        state: 'WP Kuala Lumpur',
        zipCode: '50000',
        country: 'Malaysia',
      ),
      type: PropertyType.apartment,
      purchasePrice: 500000,
      currentValue: 550000,
      totalUnits: 10,
      occupiedUnits: 9,
      monthlyRent: 2000,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'Can I claim this?',
      ),
    );
    await tester.pumpAndSettle();

    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'warranty',
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedUserActions.length, 2);
    expect(capturedUserActions[0], isNull);
    expect(capturedUserActions[1], 'override:warranty');
  });

  testWidgets('DocuMind sends cancel as userAction after checkpoint prompt', (tester) async {
    final capturedUserActions = <String?>[];
    var callCount = 0;

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? sessionId,
      int conversationTurn = 1,
      String? userAction,
    }) async {
      capturedUserActions.add(userAction);
      callCount += 1;

      if (callCount == 1) {
        return DocuMindAnswer(
          answer: 'I can search your utility docs. Please confirm or cancel.',
          confidence: 0.8,
          citations: const [],
          propertyName: 'Maple Residency',
          categoryFilterMode: 'clarification',
          userActionRequired: true,
          clarificationOptions: const ['utility', 'lease'],
          predictedCategories: const ['utility'],
          sessionId: 'session-3',
          conversationTurn: 1,
          actionReason: 'Detected billing intent',
        );
      }

      return DocuMindAnswer(
        answer: 'Understood. I cancelled that action.',
        confidence: 0.9,
        citations: const [],
        propertyName: 'Maple Residency',
        categoryFilterMode: 'cancel',
        userActionRequired: false,
        sessionId: 'session-3',
        conversationTurn: 2,
      );
    }

    final testProperty = Property(
      id: 'prop-1',
      landlordId: 'landlord-1',
      name: 'Maple Residency',
      address: const PropertyAddress(
        street: '123 Main St',
        city: 'Kuala Lumpur',
        state: 'WP Kuala Lumpur',
        zipCode: '50000',
        country: 'Malaysia',
      ),
      type: PropertyType.apartment,
      purchasePrice: 500000,
      currentValue: 550000,
      totalUnits: 10,
      occupiedUnits: 9,
      monthlyRent: 2000,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'Can I dispute this utility bill?',
      ),
    );
    await tester.pumpAndSettle();

    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'cancel',
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedUserActions.length, 2);
    expect(capturedUserActions[0], isNull);
    expect(capturedUserActions[1], 'cancel');
  });
}