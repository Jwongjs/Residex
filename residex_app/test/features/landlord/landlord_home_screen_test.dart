import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/landlord_home_screen.dart';

void main() {
  testWidgets('bottom nav shows five tabs including Documents', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Empty properties: every tab's screen already has to handle a
          // brand-new landlord with nothing yet, so this keeps all five
          // IndexedStack children on their simplest render path. Only the
          // bottom nav bar itself is under test here.
          propertiesStreamProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: LandlordHomeScreen()),
      ),
    );
    // A single frame only — we're not waiting on any screen's data to
    // resolve, just asserting the bottom nav bar's own render.
    await tester.pump();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Documind'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
  });
}
