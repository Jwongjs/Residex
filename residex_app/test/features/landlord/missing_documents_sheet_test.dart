import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/missing_documents_sheet.dart';

/// Every rankable category, so the sheet's content list is as tall as it
/// can possibly get — this is what overflowed a short screen before the
/// row list was made scrollable.
const _allCategories = [
  'lease', 'maintenance', 'loan', 'assessment', 'quit_rent',
  'parcel_rent', 'land_office_tax', 'tax', 'insurance',
];

void main() {
  testWidgets('a long missing-documents list scrolls instead of overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showMissingDocumentsSheet(
                  context, ref,
                  propertyId: 'p1',
                  year: 2025,
                  missing: _allCategories,
                  mode: MissingDocsMode.upload,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Upload documents for 2025'), findsOneWidget);
    expect(find.text('Tenancy agreement'), findsOneWidget);
  });
}
