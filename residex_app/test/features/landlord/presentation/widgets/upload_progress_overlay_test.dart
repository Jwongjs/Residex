import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/upload_progress_overlay.dart';

void main() {
  test('uploadStageDisplay maps known stages to label + percent', () {
    expect(uploadStageDisplay('received'), ('Received your document', 10));
    expect(uploadStageDisplay('indexing'), ('Making it searchable', 75));
    expect(uploadStageDisplay('done'), ('All set', 100));
  });

  test('uploadStageDisplay returns a neutral label and null percent for unknown', () {
    final (label, percent) = uploadStageDisplay('something-new');
    expect(label, 'Processing…');
    expect(percent, isNull);
  });

  testWidgets('renders the label, percentage and patience line', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: UploadProgressOverlay(
          accentColor: Colors.blue,
          label: 'Reading the document',
          progress: 0.3,
        ),
      ),
    ));

    expect(find.text('Reading the document'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(
      find.textContaining('hang tight'),
      findsOneWidget,
    );
  });
}
