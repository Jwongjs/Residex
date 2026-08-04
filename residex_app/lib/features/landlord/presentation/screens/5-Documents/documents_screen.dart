import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/document_folders.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart' show monthAbbrev;
import '../../providers/finance_providers.dart';
import '../../providers/property_providers.dart';
import '../../providers/unit_providers.dart';
import '../../../domain/entities/documind_document.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import '../../widgets/common/document_categories.dart';
import '../../widgets/common/expense_lines_review_sheet.dart';
import '../../widgets/common/manual_loan_entry_sheet.dart';
import '../../widgets/common/utilities_liability_confirm_sheet.dart';
import '../../widgets/common/records_grid.dart';
import '../../widgets/common/upload_progress_overlay.dart';
import '../../widgets/common/upload_source_sheet.dart';
import '../2-Documind/documind_upload_summary.dart';
import '../2-Documind/document_viewer_screen.dart';
import '../2-Documind/unit_label_resolver.dart';

/// Documents tab — the property document store: property selector, the
/// three display folders, upload, delete, and the Records-grid header
/// action. Split out of DocuMindScreen in Stage E (spec §9/§10) so Documind
/// can become a pure chat assistant with its own bottom-nav tab.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key, required this.onOpenDocumind});

  /// Jumps to the Documind chat tab — the replacement for the old in-screen
  /// "Ask" affordance now that Documents is a separate tab.
  final VoidCallback onOpenDocumind;

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String? _selectedPropertyId;
  String? _selectedCategory;
  String? _selectedFolderKey;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStageLabel = 'Preparing your upload…';

  // Display folders (stored categories collapse via displayCategoryFor;
  // uploads from the Expenses folder send category 'expenses' so the
  // backend runs line-item extraction).
  final List<String> _categories = [
    'lease',
    'rental_invoice',
    'loan',
    'expenses',
  ];

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesStreamProvider);

    return propertiesAsync.when(
      data: (properties) {
        if (properties.isEmpty) {
          return _buildNoPropertiesState();
        }

        if (_selectedPropertyId == null ||
            !properties.any((p) => p.id == _selectedPropertyId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedPropertyId = properties.first.id;
              });
            }
          });
          return _buildLoadingState();
        }

        return _buildMainUI(properties);
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  void _switchToProperty(String propertyId) {
    setState(() {
      _selectedPropertyId = propertyId;
      _selectedCategory = null;
      _selectedFolderKey = null;
    });
  }

  Future<void> _toggleFoldersEnabled(Property property) async {
    final controller = ref.read(propertyControllerProvider);
    await controller.updateProperty(
      property.copyWith(foldersEnabled: !property.foldersEnabled),
    );
  }

  Future<void> _renameFolder(String folderKey, Property property) async {
    final controller = TextEditingController(
      text: folderDisplayName(folderKey, property.folderNames),
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename folder', style: AppTextStyles.titleMedium),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || !mounted) return;

    final propertyController = ref.read(propertyControllerProvider);
    await propertyController.updateProperty(
      property.copyWith(folderNames: {...property.folderNames, folderKey: newName}),
    );
  }

  void _openDocument(DocuMindDocument doc) {
    if (_selectedPropertyId == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DocumentViewerScreen(
        propertyId: _selectedPropertyId!,
        docId: doc.docId,
        filename: doc.filename,
      ),
    ));
  }

  Future<void> _renameDocument(DocuMindDocument doc) async {
    final controller = TextEditingController(text: doc.filename);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename document', style: AppTextStyles.titleMedium),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save',
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == doc.filename || !mounted) {
      return;
    }
    if (_selectedPropertyId == null) return;
    try {
      final rename = ref.read(renameDocumentActionProvider);
      await rename(
        propertyId: _selectedPropertyId!,
        docId: doc.docId,
        filename: newName,
      );
      if (mounted) _showSnackBar('Document renamed');
    } catch (e) {
      if (mounted) _showSnackBar('Rename failed: ${e.toString()}', isError: true);
    }
  }

  Widget _buildMainUI(List<Property> properties) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryCyan, AppColors.primaryBlue],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.folder_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documents',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Property document store',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTopControlRow(properties),
          if (_selectedCategory != null) _buildBackToCategoriesRow(),
          Expanded(
            child: _selectedCategory == null
                ? _buildCategoryGrid()
                : _buildCategoryDocuments(properties),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControlRow(List<Property> properties) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: 'Switch Property',
              onSelected: _switchToProperty,
              itemBuilder: (context) => properties.map((property) {
                return PopupMenuItem<String>(
                  value: property.id,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getPropertyColor(properties.indexOf(property)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          property.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: property.id == _selectedPropertyId
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (property.id == _selectedPropertyId)
                        Icon(Icons.check, color: AppColors.success, size: 16),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.home_work_outlined, size: 18, color: AppColors.primaryCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getPropertyName(properties, _selectedPropertyId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.expand_more, color: AppColors.primaryCyan),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedPropertyId != null) ...[
            const SizedBox(width: 10),
            Material(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RecordsGridScreen(
                    propertyId: _selectedPropertyId!,
                    propertyName: _getPropertyName(properties, _selectedPropertyId),
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.grid_view_outlined,
                      size: 18, color: AppColors.primaryCyan),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackToCategoriesRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: AppColors.background,
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() {
            _selectedCategory = null;
            _selectedFolderKey = null;
          }),
          icon: Icon(Icons.chevron_left_rounded, color: AppColors.primaryCyan),
          label: Text(
            'Back to Categories',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryCyan,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        ),
      ),
    );
  }

  /// Category grid (NO backend call)
  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategoryCard(category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(String category) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              getCategoryColor(category).withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: getCategoryColor(category).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                getCategoryIcon(category).icon,
                color: getCategoryColor(category),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                getCategoryLabel(category),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                category == 'rental_invoice' ? 'Optional · tap to view' : 'Tap to view',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDocuments(List<Property> properties) {
    if (_selectedPropertyId == null || _selectedCategory == null) {
      return _buildLoadingState();
    }
    Property property;
    try {
      property = properties.firstWhere((p) => p.id == _selectedPropertyId);
    } catch (e) {
      property = properties.first;
    }

    final documentsAsync =
        ref.watch(documindDocumentsProvider(_selectedPropertyId!));

    return documentsAsync.when(
      data: (allDocuments) {
        final categoryDocs = allDocuments
            .where((doc) => displayCategoryFor(doc.category) == _selectedCategory)
            .toList();

        if (categoryDocs.isEmpty) {
          return _buildEmptyCategoryState(_selectedCategory!, property);
        }

        final foldersOn = _selectedCategory == 'expenses' && property.foldersEnabled;

        return Stack(
          children: [
            Column(
              children: [
                _buildCategorySectionHeader(
                  category: _selectedCategory!,
                  documentCount: categoryDocs.length,
                  property: property,
                ),
                Expanded(
                  child: !foldersOn
                      ? _buildDocumentsList(categoryDocs)
                      : _selectedFolderKey == null
                          ? _buildFolderGrid(categoryDocs, property)
                          : _buildFolderDocuments(categoryDocs, property),
                ),
              ],
            ),
            if (_isUploading)
              UploadProgressOverlay(
                accentColor: getCategoryColor(_selectedCategory!),
                label: _uploadStageLabel,
                progress: _uploadProgress,
              ),
          ],
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildDocumentsList(List<DocuMindDocument> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length + 1,
      itemBuilder: (context, index) {
        if (index == docs.length) {
          return _buildAddMoreButton(_selectedCategory!);
        }

        return _buildDocumentTile(docs[index], _selectedCategory!);
      },
    );
  }

  Future<void> _moveDocument(
    DocuMindDocument doc, List<DocuMindDocument> allCategoryDocs, Property property,
  ) async {
    final clusters = clusterIntoFolders(allCategoryDocs, manualMoves: property.folderMoves);
    final currentKey = clusters.entries
        .firstWhere((e) => e.value.any((d) => d.docId == doc.docId))
        .key;
    final targets = {...clusters.keys, untaggedFolderKey}..remove(currentKey);
    final sortedTargets = targets.toList()
      ..sort((a, b) => folderDisplayName(a, property.folderNames)
          .compareTo(folderDisplayName(b, property.folderNames)));

    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Move to folder', style: AppTextStyles.titleMedium),
        children: [
          for (final key in sortedTargets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, key),
              child: Text(folderDisplayName(key, property.folderNames)),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;

    final propertyController = ref.read(propertyControllerProvider);
    await propertyController.updateProperty(
      property.copyWith(folderMoves: {...property.folderMoves, doc.docId: chosen}),
    );
  }

  Widget _buildFolderGrid(List<DocuMindDocument> docs, Property property) {
    final clusters = clusterIntoFolders(docs, manualMoves: property.folderMoves);
    final keys = clusters.keys.toList()
      ..sort((a, b) => folderDisplayName(a, property.folderNames)
          .compareTo(folderDisplayName(b, property.folderNames)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final name = folderDisplayName(key, property.folderNames);
        final count = clusters[key]!.length;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            leading: const Icon(Icons.folder_outlined, color: AppColors.registry),
            title: Text(name, style: AppTextStyles.titleMedium),
            subtitle: Text('$count document${count == 1 ? '' : 's'}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _selectedFolderKey = key),
          ),
        );
      },
    );
  }

  Widget _buildFolderDocuments(List<DocuMindDocument> docs, Property property) {
    final key = _selectedFolderKey!;
    final clusters = clusterIntoFolders(docs, manualMoves: property.folderMoves);
    final folderDocs = [...(clusters[key] ?? const <DocuMindDocument>[])]
      ..sort((a, b) {
        final pa = documentPeriod(a);
        final pb = documentPeriod(b);
        final byYear = pb.year.compareTo(pa.year);
        if (byYear != 0) return byYear;
        return (pb.month ?? 0).compareTo(pa.month ?? 0);
      });

    final items = <Widget>[];
    ({int year, int? month})? lastPeriod;
    for (final doc in folderDocs) {
      final period = documentPeriod(doc);
      if (lastPeriod == null || lastPeriod.year != period.year || lastPeriod.month != period.month) {
        items.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            period.month != null
                ? '${monthAbbrev[period.month! - 1]} ${period.year}'
                : '${period.year}',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
        lastPeriod = period;
      }
      items.add(_buildDocumentTile(
        doc, _selectedCategory!,
        onMove: () => _moveDocument(doc, docs, property),
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _selectedFolderKey = null),
                    icon: Icon(Icons.chevron_left_rounded, color: AppColors.primaryCyan),
                    label: Text(
                      folderDisplayName(key, property.folderNames),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryCyan,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _renameFolder(key, property),
                icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                tooltip: 'Rename folder',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCategoryState(String category, Property property) {
    final categoryColor = getCategoryColor(category);
    final categoryIcon = getCategoryIcon(category);

    return Stack(
      children: [
        Column(
          children: [
            _buildCategorySectionHeader(category: category, property: property),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: categoryColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          categoryIcon.icon,
                          size: 64,
                          color: categoryColor.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No ${getCategoryLabel(category)} Yet',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload your first document to get started',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (category == 'rental_invoice') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(color: AppColors.info, width: 3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: AppColors.info),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Optional — the lease already covers your rent. '
                                    'Keep invoices, receipts, e-invoices and bank '
                                    'transfer slips here for when reality differs '
                                    'from the lease, or for audit proof.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => _uploadDocument(category),
                        icon: Icon(Icons.upload_file, color: Colors.white),
                        label: Text(
                          'Upload ${getCategoryLabel(category)}',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: categoryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                      if (category == 'loan') ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _openManualLoanEntry(),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Enter figures manually'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isUploading)
          UploadProgressOverlay(
            accentColor: categoryColor,
            label: _uploadStageLabel,
            progress: _uploadProgress,
          ),
      ],
    );
  }

  Widget _buildCategorySectionHeader({
    required String category,
    required Property property,
    int? documentCount,
  }) {
    final categoryColor = getCategoryColor(category);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 300;

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: categoryColor.withOpacity(0.3),
                  ),
                ),
                child: getCategoryIcon(category),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getCategoryLabel(category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      documentCount == null
                          ? 'No uploaded documents yet'
                          : '${documentCount} document${documentCount == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (category == 'expenses') ...[
                IconButton(
                  onPressed: () => _toggleFoldersEnabled(property),
                  icon: Icon(
                    property.foldersEnabled ? Icons.folder_special_outlined : Icons.folder_outlined,
                    size: 18,
                    color: AppColors.primaryCyan,
                  ),
                  tooltip: 'Organise into folders',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 4),
              ],
              if (isCompact)
                IconButton(
                  onPressed: widget.onOpenDocumind,
                  icon: Icon(Icons.chat_bubble_outline,
                      size: 18, color: AppColors.primaryCyan),
                  tooltip: 'Ask DocuMind',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                )
              else
                TextButton.icon(
                  onPressed: widget.onOpenDocumind,
                  icon: Icon(Icons.chat_bubble_outline,
                      size: 16, color: AppColors.primaryCyan),
                  label: Text(
                    'Ask',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocumentTile(DocuMindDocument doc, String category, {VoidCallback? onMove}) {
    final displayUnitLabel = resolveUnitLabel(
      unitId: doc.unitId,
      storedLabel: doc.unitLabel,
      liveUnits: _liveUnits(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDocument(doc),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: getCategoryColor(category).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: getCategoryColor(category).withOpacity(0.3),
              ),
            ),
            child: Icon(
              Icons.description_outlined,
              color: getCategoryColor(category),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.filename,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Category is conveyed by the folder itself and the
                    // leading colour swatch; a category chip here just repeats
                    // it. The granular sub-type tags below (doc.tags) carry the
                    // information that actually varies per document.
                    if (doc.needsFactsReview)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 12,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'NEEDS REVIEW',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (displayUnitLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.meeting_room_outlined,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              displayUnitLabel.toUpperCase(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(doc.uploadedAt),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${doc.chunksIndexed} chunks',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (doc.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in doc.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            tagLabel(t.tag),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onMove != null)
            IconButton(
              onPressed: onMove,
              icon: Icon(Icons.drive_file_move_outline, color: AppColors.textMuted, size: 20),
              tooltip: 'Move to folder',
            ),
          IconButton(
            onPressed: () => _renameDocument(doc),
            icon: Icon(Icons.drive_file_rename_outline, color: AppColors.textMuted, size: 20),
            tooltip: 'Rename document',
          ),
          IconButton(
            onPressed: () => _deleteDocument(doc),
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.error.withOpacity(0.8),
              size: 20,
            ),
            tooltip: 'Delete document',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.error.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddMoreButton(String category) {
    final categoryColor = getCategoryColor(category);
    final categoryIcon = getCategoryIcon(category);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        onPressed: () => _uploadDocument(category),
        icon: Icon(
          categoryIcon.icon,
          color: categoryColor,
        ),
        label: Text(
          'Add More ${getCategoryLabel(category)}',
          style: TextStyle(
            color: categoryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(
            color: categoryColor.withOpacity(0.5),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: categoryColor.withOpacity(0.1),
        ),
      ),
    );
  }

  /// Ask which unit an upload belongs to. Returns a choice wrapping the
  /// selected unit (null unit = whole property), or null if the user
  /// dismissed the dialog. Properties without units skip the dialog and
  /// upload property-wide.
  Future<_UploadUnitChoice?> _pickUploadUnit({required String category}) async {
    List<Unit> units;
    try {
      units =
          await ref.read(unitsForPropertyProvider(_selectedPropertyId!).future);
    } catch (_) {
      units = const <Unit>[];
    }
    if (units.isEmpty) return const _UploadUnitChoice(null);

    final isLease = category == 'lease';
    final orderedOptions =
        uploadUnitDialogOptions(category: category, units: units);

    if (!mounted) return null;
    return showDialog<_UploadUnitChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Assign to a unit?', style: AppTextStyles.titleMedium),
        children: [
          for (final unit in orderedOptions)
            if (unit == null)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(ctx, const _UploadUnitChoice(null)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.home_work_outlined,
                        size: 18, color: AppColors.primaryCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Whole property',
                              style: AppTextStyles.bodyMedium),
                          if (isLease)
                            Text(
                              'Tenancy agreements usually belong to a specific unit',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, _UploadUnitChoice(unit)),
                child: Row(
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        size: 18, color: AppColors.primaryCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        unit.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// The persistent path to manual loan figures. The finance-tab nudge clears
  /// once figures exist, so without this there is no way back in to correct a
  /// typo.
  Future<void> _openManualLoanEntry() async {
    final propertyId = _selectedPropertyId;
    if (propertyId == null) return;
    final property = await ref.read(propertyByIdProvider(propertyId).future);
    final year = ref.read(financeYearProvider);
    final summary = await ref.read(financeSummaryProvider(year).future);
    final matches =
        summary.properties.where((p) => p.propertyId == propertyId).toList();
    final block = matches.isEmpty ? null : matches.first;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ManualLoanEntrySheet(
        propertyId: propertyId,
        year: year,
        cadence: property?.loanInputCadence,
        structureType: property?.structureType,
        units: (block?.units ?? const [])
            .where((u) => u.unitId != null)
            .toList(),
      ),
    );
  }

  Future<void> _uploadDocument(String category) async {
    if (_selectedPropertyId == null) {
      _showSnackBar('Please select a property first', isError: true);
      return;
    }

    final picked = await showUploadSourceSheet(context);
    if (picked == null) return;

    if (!isAllowedUploadFilename(picked.name)) {
      _showSnackBar('Only PDF, JPG or PNG files are supported.', isError: true);
      return;
    }

    final unitChoice = await _pickUploadUnit(category: category);
    if (unitChoice == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStageLabel = 'Preparing your upload…';
    });

    try {
      final uploadAction = ref.read(uploadDocumentActionProvider);

      final uploaded = await uploadAction(
        propertyId: _selectedPropertyId!,
        category: category,
        file: File(picked.path),
        unitId: unitChoice.unit?.id,
        unitLabel: unitChoice.unit?.label,
        onProgress: (stage) {
          final (label, percent) = uploadStageDisplay(stage);
          if (!mounted) return;
          setState(() {
            _uploadStageLabel = label;
            if (percent != null) _uploadProgress = percent / 100;
          });
        },
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
        _showSnackBar(
          uploadFactSummary(category, uploaded.extractedFacts) ??
              'Document uploaded successfully!',
        );
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
        if (mounted) {
          await maybeShowUtilitiesLiabilityConfirm(
            context, ref,
            propertyId: _selectedPropertyId!,
            category: category,
            extractedFacts: uploaded.extractedFacts,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
        _showSnackBar('Upload failed: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _deleteDocument(DocuMindDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text('Delete Document', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this document?',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: getCategoryColor(doc.category),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc.filename,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone. The document and all its indexed chunks will be permanently deleted.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style:
                  AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Delete',
              style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryCyan),
                  const SizedBox(height: 16),
                  Text('Deleting document...', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ),
        );

        final deleteAction = ref.read(deleteDocumentActionProvider);
        await deleteAction(
          propertyId: _selectedPropertyId!,
          docId: doc.docId,
        );

        if (mounted) Navigator.pop(context);

        if (mounted) {
          _showSnackBar('Document deleted successfully!');
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);

        if (mounted) {
          _showSnackBar(
            'Delete failed: ${e.toString()}',
            isError: true,
          );
        }
      }
    }
  }

  /// Live units for the selected property (empty while loading/unavailable —
  /// resolveUnitLabel then falls back to the stored label).
  List<Unit> _liveUnits() {
    if (_selectedPropertyId == null) return const <Unit>[];
    return ref.watch(unitsForPropertyStreamProvider(_selectedPropertyId!)).value ??
        const <Unit>[];
  }

  String _getPropertyName(List<Property> properties, String? propertyId) {
    if (propertyId == null || properties.isEmpty) return 'No Property';
    try {
      return properties.firstWhere((p) => p.id == propertyId).name;
    } catch (e) {
      return properties.first.name;
    }
  }

  Color _getPropertyColor(int index) {
    final colors = [
      AppColors.registry,
      AppColors.catWarranty,
      AppColors.catInsurance,
      AppColors.catUtility,
      AppColors.catReceipt,
    ];
    return colors[index % colors.length];
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primaryCyan),
      ),
    );
  }

  Widget _buildNoPropertiesState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Documents'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No Properties Found', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add a property first to upload documents',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 64),
            const SizedBox(height: 16),
            Text('Error', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Result of the upload unit-picker dialog. Wrapping the unit lets the
/// caller distinguish "user chose whole property" (unit == null) from
/// "user dismissed the dialog" (the dialog returns null itself).
class _UploadUnitChoice {
  final Unit? unit;

  const _UploadUnitChoice(this.unit);
}
