import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:residex_app/features/landlord/data/models/unit_model.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_screen.dart';

/// Whether the landlord is asked to scope a Documind chat to a specific unit
/// before asking any question, on a multi-unit property. See
/// documind_screen_checkpoint_action_test.dart for the backend-driven,
/// reactive unit checkpoint (fires mid-conversation when a question's wording
/// ambiguously names more than one unit) — this file covers the separate,
/// proactive, frontend-only picker shown before the first question.
/// DashChat renders a message bubble's body via RichText (through its
/// markdown pipeline) rather than a plain Text widget, so find.text() never
/// matches bubble content in this Flutter version — only the raw Text
/// widgets this screen builds itself (quick-reply chips, controls) do. This
/// matches on the RichText's plain-text content instead.
Finder findBubbleText(String text) => find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    );

void main() {
  Property testProperty() => Property(
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

  Unit unit(String id, String label) => Unit(
        id: id,
        propertyId: 'prop-1',
        label: label,
        monthlyRent: 1200,
        isOccupied: true,
        createdAt: DateTime(2026, 1, 1),
      );

  DocuMindAnswer plainAnswer({String sessionId = 'session-1', int turn = 1}) =>
      DocuMindAnswer(
        answer: 'Here is your answer.',
        confidence: 0.9,
        citations: const [],
        propertyName: 'Maple Residency',
        sessionId: sessionId,
        conversationTurn: turn,
      );

  testWidgets('single-unit property never shows a unit-scope picker', (tester) async {
    final capturedUnitIds = <String?>[];

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
    }) async {
      capturedUnitIds.add(unitId);
      return plainAnswer();
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty()])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => Stream.value([unit('u1', 'Unit A')]),
          ),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Which unit is this about?'), findsNothing);

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(user: ChatUser(id: 'test-user'), createdAt: DateTime.now(), text: 'hello'),
    );
    await tester.pumpAndSettle();

    expect(capturedUnitIds, [null]);
  });

  testWidgets('multi-unit property blocks the first question until a scope is picked',
      (tester) async {
    var callCount = 0;

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
    }) async {
      callCount += 1;
      return plainAnswer();
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty()])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => Stream.value([unit('u1', 'Unit A'), unit('u2', 'Unit B')]),
          ),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(findBubbleText('Which unit is this about?'), findsOneWidget);
    expect(find.text('Unit A'), findsOneWidget);
    expect(find.text('Unit B'), findsOneWidget);
    expect(find.text('Whole property'), findsOneWidget);

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'when does the lease end?',
      ),
    );
    await tester.pumpAndSettle();

    expect(callCount, 0);
  });

  testWidgets('picking a specific unit scopes every subsequent question', (tester) async {
    final capturedUnitIds = <String?>[];

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
    }) async {
      capturedUnitIds.add(unitId);
      return plainAnswer(turn: capturedUnitIds.length);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty()])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => Stream.value([unit('u1', 'Unit A'), unit('u2', 'Unit B')]),
          ),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unit B'));
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

    expect(capturedUnitIds, ['u2']);
  });

  testWidgets('picking Whole property leaves questions unscoped', (tester) async {
    final capturedUnitIds = <String?>[];

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
    }) async {
      capturedUnitIds.add(unitId);
      return plainAnswer(turn: capturedUnitIds.length);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty()])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => Stream.value([unit('u1', 'Unit A'), unit('u2', 'Unit B')]),
          ),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Whole property'));
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

    expect(capturedUnitIds, [null]);
  });

  testWidgets('the change-unit control re-scopes later questions without clearing the transcript',
      (tester) async {
    final capturedUnitIds = <String?>[];

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
    }) async {
      capturedUnitIds.add(unitId);
      return plainAnswer(turn: capturedUnitIds.length);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty()])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => Stream.value([unit('u1', 'Unit A'), unit('u2', 'Unit B')]),
          ),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unit A'));
    await tester.pumpAndSettle();

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'what is the rent?',
      ),
    );
    await tester.pumpAndSettle();

    expect(findBubbleText('what is the rent?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('documind_change_unit_control')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit B').last);
    await tester.pumpAndSettle();

    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'and this unit?',
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedUnitIds, ['u1', 'u2']);
    // Earlier transcript stays intact across the scope change.
    expect(findBubbleText('what is the rent?'), findsOneWidget);
    expect(findBubbleText('and this unit?'), findsOneWidget);
  });

  testWidgets(
      'the change-unit control survives a live units list reified as List<UnitModel>',
      (tester) async {
    // Regression test for a real crash: unitsForPropertyStreamProvider's
    // production implementation returns UnitModel instances (UnitModel
    // extends Unit) without mapping down to the plain entity, so the list
    // handed to the screen is reified as List<UnitModel> even though it's
    // statically typed List<Unit> everywhere it's read. Unit(...) fixtures in
    // the other tests above never reproduce this, because they build a
    // genuine List<Unit> — this one deliberately uses UnitModel to match what
    // the real repository hands the screen.
    UnitModel unitModel(String id, String label) => UnitModel(
          id: id,
          propertyId: 'prop-1',
          label: label,
          monthlyRent: 1200,
          isOccupied: true,
          createdAt: DateTime(2026, 1, 1),
        );

    // Declared as List<UnitModel> explicitly: a list *literal* placed
    // directly where a Stream<List<Unit>> is expected gets contextually
    // typed down to List<Unit> by Dart's inference, which would silently
    // erase the exact bug this test exists to catch. Building the list
    // against its own declared type first, then widening the already-built
    // object, keeps it reified as List<UnitModel> — matching what the real
    // repository hands the screen.
    final List<UnitModel> unitModels = [unitModel('u1', 'Unit A'), unitModel('u2', 'Unit B')];

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
    }) async =>
        plainAnswer();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty()])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => Stream.value(unitModels),
          ),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Picking a unit rebuilds the "change unit" control, which is where the
    // crash occurred — reaching this line without a thrown TypeError is the
    // assertion.
    await tester.tap(find.text('Unit A'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('documind_change_unit_control')), findsOneWidget);
    expect(find.text('Unit A'), findsOneWidget);
  });
}
