// The loan-method question is the whole point of this workstream: it is the
// one place the choice is made, so every downstream surface can stop asking.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/add_property_dialog.dart';

Future<void> _pump(WidgetTester tester) async {
  // The dialog's form is a tall SingleChildScrollView; the default 800x600
  // test surface clips it before the mortgage/loan-method controls, so
  // widen it the same way other dialog/screen tests in this suite do.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: AddPropertyDialog()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The dialog's form lives in a SingleChildScrollView with a fixed
/// `maxHeight: 700` regardless of the outer test surface size, so targets
/// further down the form (mortgage/loan-method controls) need to be
/// scrolled into view before they can be hit-tested.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  testWidgets('the loan method cards are hidden until mortgage is Yes',
      (tester) async {
    await _pump(tester);
    expect(find.text('How will loan figures arrive?'), findsNothing);

    await _tap(tester, find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('How will loan figures arrive?'), findsOneWidget);
    expect(find.text('Upload statements'), findsOneWidget);
    expect(find.text('Enter figures myself'), findsOneWidget);
  });

  testWidgets('answering No hides the cards again', (tester) async {
    await _pump(tester);
    await _tap(tester, find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Upload statements'), findsOneWidget);

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Upload statements'), findsNothing);
  });

  testWidgets('neither card is selected until one is tapped', (tester) async {
    await _pump(tester);
    await _tap(tester, find.text('Yes'));
    await tester.pumpAndSettle();

    // Anchor: the cards themselves must actually be there, otherwise the
    // findsNothing checks below would pass just as well if the selector
    // rendered nothing at all.
    expect(find.text('Upload statements'), findsOneWidget);

    // Unanswered means null, which behaves as 'upload' downstream — this is
    // what keeps every existing property behaving as it does today.
    expect(
      find.byKey(const Key('loan-method-upload-selected')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('loan-method-manual-selected')),
      findsNothing,
    );
  });

  testWidgets('tapping a card selects it and deselects the other',
      (tester) async {
    await _pump(tester);
    await _tap(tester, find.text('Yes'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Enter figures myself'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loan-method-manual-selected')), findsOneWidget);
    expect(find.byKey(const Key('loan-method-upload-selected')), findsNothing);

    await _tap(tester, find.text('Upload statements'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loan-method-upload-selected')), findsOneWidget);
    expect(find.byKey(const Key('loan-method-manual-selected')), findsNothing);
  });
}
