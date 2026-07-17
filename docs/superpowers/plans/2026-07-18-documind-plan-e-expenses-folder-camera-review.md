# Plan E — Expenses Folder, Camera/Image Upload, Line Review (Flutter)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the DocuMind folder UI to three buckets (Tenancy agreements, Rent invoices, Expenses), add camera / photo-library / file upload sources, show a post-upload review sheet for extracted expense lines (with edit + save via the new PATCH endpoint), and surface insurance expiry dates found inside combined expense statements.

**Architecture:** Presentation-only collapse — documents keep their granular backend category; a pure `displayCategoryFor()` maps stored categories to the three folders. Uploads from the Expenses folder send `category='expenses'` (line-item extraction, Plan D); the guided checklist and Finance-tab "missing document" buttons keep sending granular categories (best extraction precision, engine legacy path). All new logic that computes anything is a pure top-level function with unit tests; widgets stay thin.

**Tech Stack:** Flutter 3.x, Riverpod 3 (`flutter_riverpod` + `legacy.dart` for StateProvider), `http` package datasource, `file_picker` ^8.1.6 and `image_picker` ^1.0.7 (both already in `residex_app/pubspec.yaml` — no new dependencies).

## Global Constraints

- **Depends on Plan D** (`2026-07-18-documind-plan-d-expenses-pipeline-image-ingestion.md`): backend must accept `category='expenses'`, JPG/PNG uploads, and `PATCH /api/rex/documind/documents/{doc_id}/facts` before end-to-end testing.
- No emoji anywhere in the UI — Material icon glyphs only (app convention, stated in `documind_upload_summary.dart:3`).
- The app formats, never computes (`finance_logic.dart:3`) — totals shown in the review sheet are presentation sums of already-extracted numbers, no financial math.
- Clean architecture layering: entity ← model ← datasource ← repository ← providers ← screens.
- Flutter tests: `cd residex_app && flutter test test/features/landlord/<file>` (the repo-wide `widget_test.dart` boilerplate failure is pre-existing and expected).
- Category ids sent to the backend are exact strings: `lease`, `rental_invoice`, `expenses`, plus granular `insurance|loan|tax|upkeep|maintenance` from guided/checklist contexts.

---

### Task 1: Image extensions + upload source sheet (camera / photos / files)

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/widgets/common/upload_source_sheet.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart:1084-1107` (`_uploadDocument`) and `:1884-1887` (`isAllowedUploadFilename`)
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:18-34` (`uploadDocumentForCategory`)
- Test: `residex_app/test/features/landlord/documind_upload_rules_test.dart` (append)

**Interfaces:**
- Consumes: nothing new.
- Produces: `class PickedUpload { final String path; final String name; }` and `Future<PickedUpload?> showUploadSourceSheet(BuildContext context)`; `isAllowedUploadFilename` accepts `.pdf/.jpg/.jpeg/.png`. Task 4 reuses the same call sites.

- [ ] **Step 1: Write the failing test** (append to `documind_upload_rules_test.dart`)

```dart
  test('image filenames are allowed for upload', () {
    expect(isAllowedUploadFilename('receipt.JPG'), isTrue);
    expect(isAllowedUploadFilename('scan.jpeg'), isTrue);
    expect(isAllowedUploadFilename('bill.png'), isTrue);
    expect(isAllowedUploadFilename('doc.docx'), isFalse);
    expect(isAllowedUploadFilename('lease.pdf'), isTrue);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/documind_upload_rules_test.dart`
Expected: FAIL — `receipt.JPG` currently returns false.

- [ ] **Step 3: Widen the allowlist** — replace `documind_screen.dart:1884-1887` with:

```dart
/// The backend ingests PDFs plus JPG/PNG photos (Gemini transcription), so
/// the picker accepts exactly those extensions (DOCX is future work).
const Set<String> allowedUploadExtensions = {'.pdf', '.jpg', '.jpeg', '.png'};

bool isAllowedUploadFilename(String filename) {
  final lower = filename.toLowerCase();
  return allowedUploadExtensions.any(lower.endsWith);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/documind_upload_rules_test.dart`
Expected: PASS.

- [ ] **Step 5: Create the source sheet** — new file `upload_source_sheet.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';

/// A picked upload, regardless of source (camera, photo library or files).
class PickedUpload {
  final String path;
  final String name;
  const PickedUpload({required this.path, required this.name});
}

/// Bottom sheet offering the three upload sources. Returns null when the
/// user dismisses the sheet or cancels the underlying picker.
Future<PickedUpload?> showUploadSourceSheet(BuildContext context) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(sheetContext, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose photo'),
            onTap: () => Navigator.pop(sheetContext, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Choose file'),
            onTap: () => Navigator.pop(sheetContext, 'file'),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  if (source == 'file') {
    // Any-file picker for cloud-provider compatibility (e.g. Google Drive);
    // extension enforcement stays with the caller via isAllowedUploadFilename.
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final picked = result?.files.single;
    if (picked == null || picked.path == null) return null;
    return PickedUpload(path: picked.path!, name: picked.name);
  }

  final image = await ImagePicker().pickImage(
    source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 85,
  );
  if (image == null) return null;
  return PickedUpload(path: image.path, name: image.name);
}
```

(`image_picker` uses the Android camera intent — no manifest permission changes needed for the `documind_light` AVD.)

- [ ] **Step 6: Wire into `uploadDocumentForCategory`** — in `finance_screen.dart`, add `import '../../widgets/common/upload_source_sheet.dart';`, delete the now-unused `import 'package:file_picker/file_picker.dart';`, and replace lines 24-34 (`final result = await FilePicker...` through the early `return; }`) with:

```dart
  final picked = await showUploadSourceSheet(context);
  if (picked == null) return;
  if (!isAllowedUploadFilename(picked.name)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only PDF, JPG or PNG files are supported.')),
      );
    }
    return;
  }
```

and change the subsequent `file: File(picked.path!)` reference to `file: File(picked.path)` (the sheet guarantees a path).

- [ ] **Step 7: Wire into `_uploadDocument`** — in `documind_screen.dart`, add `import '../../widgets/common/upload_source_sheet.dart';` and replace lines 1090-1107 (the `FilePicker.platform.pickFiles` call, the `result != null` guard, the filename check, and the `selectedFile.path == null` guard) with:

```dart
    final picked = await showUploadSourceSheet(context);
    if (picked == null) return;

    if (!isAllowedUploadFilename(picked.name)) {
      _showSnackBar('Only PDF, JPG or PNG files are supported.', isError: true);
      return;
    }
```

Then, in the remainder of `_uploadDocument`, replace every `selectedFile.name` with `picked.name` and every `selectedFile.path!` with `picked.path`, un-indenting the body that lived inside the old `if (result != null) {` block. Remove the `package:file_picker/file_picker.dart` import from `documind_screen.dart` if nothing else in the file uses it.

- [ ] **Step 8: Analyze + test**

Run: `cd residex_app && dart analyze lib/features/landlord && flutter test test/features/landlord/documind_upload_rules_test.dart`
Expected: `No issues found!` and PASS.

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/upload_source_sheet.dart residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/documind_upload_rules_test.dart
git commit -m "feat: camera/photo/file upload sources with image extensions"
```

---

### Task 2: Three display folders (Tenancy / Rent invoices / Expenses)

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart:46-55` (`_categories`), `:481` (folder filter), `:1723-1764` (label/icon/color maps), area near `:1886` (new pure function)
- Modify: `residex_app/lib/features/landlord/domain/usecases/upload_document.dart:25` (`validCategories`)
- Test: `residex_app/test/features/landlord/documind_upload_rules_test.dart` (append)

**Interfaces:**
- Consumes: backend acceptance of `category='expenses'` (Plan D Task 3).
- Produces: top-level `String displayCategoryFor(String category)` in `documind_screen.dart` — Task 5 and any future grouping reuse it.

- [ ] **Step 1: Write the failing test** (append to `documind_upload_rules_test.dart`)

```dart
  test('stored categories collapse into three display folders', () {
    expect(displayCategoryFor('lease'), 'lease');
    expect(displayCategoryFor('rental_invoice'), 'rental_invoice');
    expect(displayCategoryFor('receipt'), 'rental_invoice'); // legacy alias
    for (final stored in [
      'insurance', 'loan', 'tax', 'upkeep', 'maintenance',
      'utility', 'warranty', 'expenses',
    ]) {
      expect(displayCategoryFor(stored), 'expenses', reason: stored);
    }
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/documind_upload_rules_test.dart`
Expected: FAIL — `displayCategoryFor` undefined.

- [ ] **Step 3: Implement**

3a. In `documind_screen.dart`, directly below `isAllowedUploadFilename`, add:

```dart
/// Folder the DocuMind UI files a stored category under. Documents keep
/// their granular backend category (no migration); only the presentation
/// collapses money-out paperwork into one Expenses folder.
String displayCategoryFor(String category) {
  switch (category) {
    case 'lease':
      return 'lease';
    case 'rental_invoice':
    case 'receipt':
      return 'rental_invoice';
    default:
      return 'expenses';
  }
}
```

3b. Replace `_categories` (lines 46-55) with:

```dart
  // Display folders (stored categories collapse via displayCategoryFor;
  // uploads from the Expenses folder send category 'expenses' so the
  // backend runs line-item extraction).
  final List<String> _categories = [
    'lease',
    'rental_invoice',
    'expenses',
  ];
```

3c. Change the folder filter at line 481 from
`.where((doc) => doc.category == _selectedCategory)` to
`.where((doc) => displayCategoryFor(doc.category) == _selectedCategory)`.

3d. In `_getCategoryLabel` (line 1723) add `'expenses': 'Expenses',` to the map; in `_getCategoryIcon` (line 1737) add `'expenses': Icons.account_balance_wallet_outlined,`; in `_getCategoryColor` (line 1752) add `'expenses': AppColors.catMaintenance,`.

3e. In `upload_document.dart:25`, extend the list:

```dart
    final validCategories = ['lease', 'insurance', 'loan', 'tax', 'upkeep', 'maintenance', 'rental_invoice', 'expenses'];
```

- [ ] **Step 4: Run tests + analyzer**

Run: `cd residex_app && flutter test test/features/landlord/documind_upload_rules_test.dart && dart analyze lib/features/landlord`
Expected: PASS, `No issues found!`. If `_selectedCategory` is initialised to a removed name anywhere, set it to `'lease'`.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart residex_app/lib/features/landlord/domain/usecases/upload_document.dart residex_app/test/features/landlord/documind_upload_rules_test.dart
git commit -m "feat: collapse Documind folders to tenancy, invoices and expenses"
```

---

### Task 3: Upload summary + Finance year options understand expense_lines

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_upload_summary.dart` (new `expenses` case)
- Modify: `residex_app/lib/features/landlord/presentation/providers/finance_logic.dart:35-62` (`financeYearOptions`)
- Test: `residex_app/test/features/landlord/documind_upload_summary_test.dart` (append)

**Interfaces:**
- Consumes: `extracted_facts.expense_lines` shape from Plan D (`{subtype, amount, description?, date?, period_year?}`).
- Produces: `uploadFactSummary('expenses', facts)` → `'N expenses recorded — RM X.XX total'`; `financeYearOptions` includes years mentioned in expense lines.

- [ ] **Step 1: Write the failing tests** (append to `documind_upload_summary_test.dart`)

```dart
  test('expenses facts produce count + total line', () {
    expect(
      uploadFactSummary('expenses', {
        'expense_lines': [
          {'subtype': 'maintenance', 'amount': 4200.0},
          {'subtype': 'sinking_fund', 'amount': 840.0},
        ],
      }),
      '2 expenses recorded — RM 5040.00 total',
    );
  });

  test('expenses facts without lines fall back to generic message', () {
    expect(uploadFactSummary('expenses', {'expense_lines': []}), isNull);
    expect(uploadFactSummary('expenses', {'other': 1}), isNull);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/documind_upload_summary_test.dart`
Expected: FAIL — the `expenses` case falls through and returns null, so the first test fails.

- [ ] **Step 3: Implement**

3a. In `documind_upload_summary.dart`, add a case to the `switch (category)` alongside the existing ones:

```dart
    case 'expenses':
      final lines = facts['expense_lines'];
      if (lines is List && lines.isNotEmpty) {
        var total = 0.0;
        for (final line in lines) {
          final amount = line is Map ? line['amount'] : null;
          if (amount is num) total += amount;
        }
        final noun = lines.length == 1 ? 'expense' : 'expenses';
        return '${lines.length} $noun recorded — RM ${total.toStringAsFixed(2)} total';
      }
      return null;
```

3b. In `finance_logic.dart`, inside the `for (final doc in docs)` loop of `financeYearOptions` (after the `period_year` block at lines 54-57), add:

```dart
    final lines = facts['expense_lines'];
    if (lines is List) {
      for (final line in lines) {
        if (line is Map) {
          addFromDateString(line['date']);
          final lineYear = line['period_year'];
          if (lineYear is int && lineYear > 1990 && lineYear < 2200) {
            years.add(lineYear);
          }
        }
      }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/documind_upload_summary_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_upload_summary.dart residex_app/lib/features/landlord/presentation/providers/finance_logic.dart residex_app/test/features/landlord/documind_upload_summary_test.dart
git commit -m "feat: upload summary and year options read expense lines"
```

---

### Task 4: PATCH wiring + expense-lines review sheet

**Files:**
- Modify: `residex_app/lib/core/constants/api_constants.dart:17` (append path helper)
- Modify: `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart` (append method)
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart` (append action provider)
- Create: `residex_app/lib/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:42-47` and `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (`_uploadDocument` success path) — show the sheet after `expenses` uploads

**Interfaces:**
- Consumes: `PATCH /api/rex/documind/documents/{doc_id}/facts` (Plan D Task 6); `expenseSubtypeLabels` keys must equal Plan D's `EXPENSE_SUBTYPE_CATEGORY` keys.
- Produces: `showExpenseLinesReviewSheet(context, docId: ..., initialLines: ...)`; `updateExpenseLinesActionProvider`.

- [ ] **Step 1: API constant** — in `api_constants.dart`, after `documindFinanceSummary` (line 17), add:

```dart
  static String documindUpdateFacts(String docId) => '/api/rex/documind/documents/$docId/facts';
```

- [ ] **Step 2: Datasource method** — append to `DocuMindRemoteDataSource` (ensure `dart:convert` is imported; it already is for the ask/list calls):

```dart
  /// Replace a document's reviewed expense lines.
  Future<void> updateExpenseLines({
    required String landlordId,
    required String docId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.documindUpdateFacts(docId)}');
    final response = await httpClient.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'landlord_id': landlordId, 'expense_lines': lines}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update expense lines: ${response.body}');
    }
  }
```

- [ ] **Step 3: Action provider** — append to `documind_provider.dart`:

```dart
/// Save user-reviewed expense lines for an uploaded Expenses document.
final updateExpenseLinesActionProvider = Provider<Future<void> Function({
  required String docId,
  required List<Map<String, dynamic>> lines,
})>((ref) {
  return ({
    required String docId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.updateExpenseLines(
      landlordId: landlordId,
      docId: docId,
      lines: lines,
    );
    // Facts changed: documents, figures and year options are folds over them.
    ref.invalidate(documindDocumentsProvider);
    ref.invalidate(financeSummaryProvider);
    ref.invalidate(financeYearsProvider);
  };
});
```

- [ ] **Step 4: Review sheet widget** — create `expense_lines_review_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart' show formatRM;

/// Display labels for the expense-line subtypes. Keys mirror the backend's
/// EXPENSE_SUBTYPE_CATEGORY whitelist exactly.
const Map<String, String> expenseSubtypeLabels = {
  'loan_interest': 'Loan interest',
  'assessment_tax': 'Assessment tax',
  'quit_rent': 'Quit rent',
  'parcel_rent': 'Parcel rent',
  'maintenance': 'Maintenance / service charge',
  'sinking_fund': 'Sinking fund',
  'insurance_premium': 'Insurance premium',
  'upkeep': 'Upkeep / repairs',
};

/// Post-upload confirmation for extracted expense lines: the human checkpoint
/// that keeps the deterministic engine trustworthy. "Looks right" keeps the
/// extraction as-is; edits are saved through the facts PATCH endpoint.
Future<void> showExpenseLinesReviewSheet(
  BuildContext context, {
  required String docId,
  required List<Map<String, dynamic>> initialLines,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ExpenseLinesReviewSheet(
      docId: docId,
      initialLines: initialLines,
    ),
  );
}

class ExpenseLinesReviewSheet extends ConsumerStatefulWidget {
  final String docId;
  final List<Map<String, dynamic>> initialLines;

  const ExpenseLinesReviewSheet({
    super.key,
    required this.docId,
    required this.initialLines,
  });

  @override
  ConsumerState<ExpenseLinesReviewSheet> createState() =>
      _ExpenseLinesReviewSheetState();
}

class _ExpenseLinesReviewSheetState
    extends ConsumerState<ExpenseLinesReviewSheet> {
  late List<Map<String, dynamic>> _lines;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lines = [
      for (final line in widget.initialLines) Map<String, dynamic>.from(line),
    ];
  }

  double get _total {
    var sum = 0.0;
    for (final line in _lines) {
      final amount = line['amount'];
      if (amount is num) sum += amount;
    }
    return sum;
  }

  Future<void> _editLine(int index) async {
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ExpenseLineEditDialog(line: _lines[index]),
    );
    if (edited != null) {
      setState(() {
        _lines[index] = edited;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(updateExpenseLinesActionProvider)(
        docId: widget.docId,
        lines: _lines,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense lines updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saving failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review extracted expenses',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text(
            '${_lines.length} line(s), ${formatRM(_total)} total. '
            'Tap a line to correct it.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _lines.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.hairline),
              itemBuilder: (context, index) {
                final line = _lines[index];
                final subtype = line['subtype'] as String? ?? '';
                final amount = line['amount'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expenseSubtypeLabels[subtype] ?? subtype,
                      style: AppTextStyles.bodyLarge),
                  subtitle: (line['description'] is String)
                      ? Text(line['description'] as String,
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(amount is num ? formatRM(amount.toDouble()) : '—',
                          style: AppTextStyles.bodyLarge),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_outlined, size: 18),
                    ],
                  ),
                  onTap: _saving ? null : () => _editLine(index),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Looks right'),
              ),
              const SizedBox(width: 8),
              if (_dirty)
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseLineEditDialog extends StatefulWidget {
  final Map<String, dynamic> line;

  const _ExpenseLineEditDialog({required this.line});

  @override
  State<_ExpenseLineEditDialog> createState() => _ExpenseLineEditDialogState();
}

class _ExpenseLineEditDialogState extends State<_ExpenseLineEditDialog> {
  late String _subtype;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _year;

  @override
  void initState() {
    super.initState();
    _subtype = widget.line['subtype'] as String? ?? 'maintenance';
    _description = TextEditingController(
        text: widget.line['description'] as String? ?? '');
    final amount = widget.line['amount'];
    _amount = TextEditingController(
        text: amount is num ? amount.toStringAsFixed(2) : '');
    final year = widget.line['period_year'];
    _year = TextEditingController(text: year is int ? '$year' : '');
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit expense line'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _subtype,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final entry in expenseSubtypeLabels.entries)
                  DropdownMenuItem(
                      value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) =>
                  setState(() => _subtype = value ?? _subtype),
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (RM)'),
            ),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(_amount.text.trim());
            if (amount == null) return; // amount is the one required field
            final updated = Map<String, dynamic>.from(widget.line);
            updated['subtype'] = _subtype;
            updated['amount'] = amount;
            final description = _description.text.trim();
            if (description.isEmpty) {
              updated.remove('description');
            } else {
              updated['description'] = description;
            }
            final year = int.tryParse(_year.text.trim());
            if (year == null) {
              updated.remove('period_year');
            } else {
              updated['period_year'] = year;
            }
            Navigator.pop(context, updated);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Show the sheet after Expenses uploads**

5a. In `finance_screen.dart`, add `import '../../widgets/common/expense_lines_review_sheet.dart';` and extend the success branch of `uploadDocumentForCategory` (currently lines 42-47) to:

```dart
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uploadFactSummary(category, uploaded.extractedFacts) ??
            'Document uploaded.'),
      ));
      final lines = uploaded.extractedFacts?['expense_lines'];
      if (category == 'expenses' && lines is List && lines.isNotEmpty) {
        await showExpenseLinesReviewSheet(
          context,
          docId: uploaded.docId,
          initialLines: [
            for (final line in lines)
              if (line is Map) Map<String, dynamic>.from(line),
          ],
        );
      }
    }
```

5b. In `documind_screen.dart` `_uploadDocument`, the awaited upload result is already held in a local variable before the success snackbar (rename it to `uploaded` if it has another name). After the success snackbar, add the identical guarded block from 5a — same import, same `category == 'expenses'` guard, same `showExpenseLinesReviewSheet` call — using that variable.

- [ ] **Step 6: Analyze**

Run: `cd residex_app && dart analyze lib/features/landlord lib/core`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/core/constants/api_constants.dart residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart residex_app/lib/features/landlord/presentation/providers/documind_provider.dart residex_app/lib/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart
git commit -m "feat: post-upload expense line review sheet with PATCH save"
```

---

### Task 5: Expiry tile reads policy_end from expense statements

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/providers/upcoming_expiries.dart:12-37`
- Test: `residex_app/test/features/landlord/upcoming_expiries_test.dart` (append; create with the content below if the file does not exist)

**Interfaces:**
- Consumes: `extracted_facts.policy_end` written by Plan D's expenses extraction; `DocuMindDocument` entity (unchanged).
- Produces: `ExpiryEntry` rows with `kind == 'Policy expires'` for `expenses` docs carrying a `policy_end`.

- [ ] **Step 1: Write the failing tests** — `upcoming_expiries_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/providers/upcoming_expiries.dart';

DocuMindDocument _doc({
  required String docId,
  required String category,
  Map<String, dynamic>? facts,
  DateTime? uploadedAt,
}) =>
    DocuMindDocument(
      docId: docId,
      landlordId: 'l1',
      propertyId: 'p1',
      category: category,
      filename: '$docId.pdf',
      chunksIndexed: 1,
      uploadedAt: uploadedAt ?? DateTime(2026, 1, 1),
      extractedFacts: facts,
    );

void main() {
  test('expenses documents with a policy_end feed the expiry tile', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'exp1', category: 'expenses', facts: {
        'expense_lines': [
          {'subtype': 'insurance_premium', 'amount': 1800.0},
        ],
        'policy_end': '2026-08-15',
      }),
    ], DateTime(2026, 7, 18));
    expect(entries, hasLength(1));
    expect(entries.single.kind, 'Policy expires');
    expect(entries.single.date, DateTime(2026, 8, 15));
  });

  test('expenses documents without policy_end are ignored', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'exp2', category: 'expenses', facts: {
        'expense_lines': [
          {'subtype': 'maintenance', 'amount': 100.0},
        ],
      }),
    ], DateTime(2026, 7, 18));
    expect(entries, isEmpty);
  });
}
```

If the file already exists, append only the two `test(...)` blocks into its `main()` and add the `_doc` helper (skip anything already defined).

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/upcoming_expiries_test.dart`
Expected: FAIL — first test finds 0 entries (`expenses` not in `_dateKeyByCategory`).

- [ ] **Step 3: Implement** — in `upcoming_expiries.dart` replace lines 29-37 (both const maps) with:

```dart
const Map<String, String> _dateKeyByCategory = {
  'lease': 'lease_end',
  'insurance': 'policy_end',
  // Combined expense statements carry the insurance policy period when the
  // extractor found a premium line; docs without policy_end fold to nothing.
  'expenses': 'policy_end',
};

const Map<String, String> _kindByCategory = {
  'lease': 'Tenancy ends',
  'insurance': 'Policy expires',
  'expenses': 'Policy expires',
};
```

and update the `ExpiryEntry.category` comment (line 12) to `// lease | insurance | expenses`. The fold loop itself needs no change: an `expenses` doc without `policy_end` fails the `raw is! String` check at line 63 and is skipped.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/upcoming_expiries_test.dart`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/providers/upcoming_expiries.dart residex_app/test/features/landlord/upcoming_expiries_test.dart
git commit -m "feat: expiry tile reads policy_end from combined expense statements"
```

---

### Task 6: Full verification sweep

**Files:** none created — verification only.

- [ ] **Step 1: Full analyzer + test suites**

Run: `cd residex_app && dart analyze && flutter test test/features/landlord`
Expected: analyzer clean; all `test/features/landlord` tests pass (the repo-root `widget_test.dart` boilerplate failure is pre-existing — ignore it).

Run: `cd backend && python -m pytest tests -q`
Expected: PASS (Plan D suites still green after UI work).

- [ ] **Step 2: End-to-end smoke on the emulator** (backend running per `run_all.ps1`, `documind_light` AVD, Landlord Dev login):

1. DocuMind tab shows exactly three folders: Tenancy Agreements, Rental Invoices, Expenses; previously uploaded loan/tax/maintenance/insurance demo docs all appear inside Expenses.
2. Upload a photo (Take photo → snap any printed page) into Expenses — ingestion succeeds, the document lists with its image filename, and chat can quote its text.
3. Upload `demo_documents/1_damai_residence/damai_maintenance_2025.pdf` into Expenses — the review sheet appears with a maintenance line; edit the amount, Save changes, then confirm the Finance tab's maintenance row reflects the edited figure for 2025.
4. Ask chat "how much service charge did I pay in 2025?" — the answer cites the expenses document.
5. Dashboard expiry tile still shows the Damai policy / tenancy entries (regression), and an Expenses upload containing an insurance premium with a future `policy_end` adds a "Policy expires" row.

- [ ] **Step 3: Commit any smoke-test fixes; otherwise nothing to commit.**
