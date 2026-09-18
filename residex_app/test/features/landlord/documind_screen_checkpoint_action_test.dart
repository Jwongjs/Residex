import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
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
      String? unitId,
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
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith((ref, propertyId) => Stream.value(const [])),
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
      String? unitId,
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
          clarificationOptions: const ['lease', 'upkeep'],
          predictedCategories: const ['lease'],
          sessionId: 'session-2',
          conversationTurn: 1,
          actionReason: 'Detected lease-like intent',
        );
      }

      return DocuMindAnswer(
        answer: 'Understood. Switching to upkeep category.',
        confidence: 0.9,
        citations: const [],
        propertyName: 'Maple Residency',
        categoryFilterMode: 'clarification_selected',
        searchedCategories: const ['upkeep'],
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
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith((ref, propertyId) => Stream.value(const [])),
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
        text: 'upkeep',
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedUserActions.length, 2);
    expect(capturedUserActions[0], isNull);
    expect(capturedUserActions[1], 'override:upkeep');
  });

  testWidgets('DocuMind sends cancel as userAction after checkpoint prompt', (tester) async {
    final capturedUserActions = <String?>[];
    var callCount = 0;

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
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
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith((ref, propertyId) => Stream.value(const [])),
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

  testWidgets('DocuMind renders unit badge on citations', (tester) async {
    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
      String? userAction,
    }) async {
      return DocuMindAnswer(
        answer: 'The lease ends 31 December 2026.',
        confidence: 0.9,
        citations: [
          Citation(
            docId: 'doc-1',
            filename: 'leaseA.pdf',
            category: 'lease',
            page: 3,
            snippet: 'Tenancy ends 31 December 2026.',
            score: 0.95,
            unitId: 'unit-a',
            unitLabel: 'Unit A',
          ),
        ],
        propertyName: 'Maple Residency',
        sessionId: 'session-badge',
        conversationTurn: 1,
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
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith((ref, propertyId) => Stream.value(const [])),
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
        text: 'when does the lease end?',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UNIT A'), findsOneWidget);
  });

  testWidgets('DocuMind sends unit action after unit checkpoint', (tester) async {
    final capturedUserActions = <String?>[];
    var callCount = 0;

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
      String? userAction,
    }) async {
      capturedUserActions.add(userAction);
      callCount += 1;

      if (callCount == 1) {
        return DocuMindAnswer(
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
          sessionId: 'session-unit-1',
          conversationTurn: 1,
        );
      }

      return DocuMindAnswer(
        answer: 'Unit A lease ends 31 December 2026.',
        confidence: 0.9,
        citations: const [],
        propertyName: 'Maple Residency',
        userActionRequired: false,
        sessionId: 'session-unit-1',
        conversationTurn: 2,
      );
    }

    final unitA = Unit(
      id: 'unit-A',
      propertyId: 'prop-1',
      label: 'Unit A',
      monthlyRent: 1200,
      isOccupied: true,
      createdAt: DateTime(2026, 1, 1),
    );
    final unitB = Unit(
      id: 'unit-B',
      propertyId: 'prop-1',
      label: 'Unit B',
      monthlyRent: 1300,
      isOccupied: false,
      createdAt: DateTime(2026, 1, 2),
    );

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
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => Stream.value([unitA, unitB]),
          ),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Two units, so the unit-scope picker gates the first question.
    await tester.tap(find.text('Whole property'));
    await tester.pumpAndSettle();

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'when does the lease expire?',
      ),
    );
    await tester.pumpAndSettle();

    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'Unit A',
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedUserActions.length, 2);
    expect(capturedUserActions[0], isNull);
    expect(capturedUserActions[1], 'unit:unit-A');
  });
}