import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_screen.dart';

void main() {
  testWidgets('DocuMind renders unit badge on citations', (tester) async {
    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? unitId,
      String? sessionId,
      int conversationTurn = 1,
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

}