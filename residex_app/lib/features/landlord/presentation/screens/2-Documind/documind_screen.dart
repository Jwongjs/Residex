import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/documind_provider.dart';
import '../../providers/property_providers.dart';
import '../../providers/unit_providers.dart';
import '../../../domain/entities/documind_document.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import 'documind_chat_logic.dart';
import 'document_viewer_screen.dart';

/// DocuMind Screen - Property Document Management + Q&A
class DocuMindScreen extends ConsumerStatefulWidget {
  const DocuMindScreen({super.key});

  @override
  ConsumerState<DocuMindScreen> createState() => _DocuMindScreenState();
}

class _DocuMindScreenState extends ConsumerState<DocuMindScreen> {
  String? _selectedPropertyId;
  String? _selectedCategory;
  bool _showChatInterface = true;
  bool _isUploading = false; // Track upload state
  double _uploadProgress = 0.0; // Track progress

  // Chat state
  final List<ChatMessage> _messages = [];
  late final ChatUser _currentUser;
  late final ChatUser _aiUser;
  bool _isThinking = false;
  String _lastQuestion = '';
  String? _docuMindSessionId;
  int _docuMindConversationTurn = 1;
  bool _awaitingUserAction = false;
  List<UnitOption> _pendingUnitOptions = const [];

  // Document categories (backend-supported)
  final List<String> _categories = [
    'lease',
    'warranty',
    'insurance',
    'utility',
    'receipt'
  ];

  @override
  void initState() {
    super.initState();

    _currentUser = ChatUser(id: 'user_1', firstName: 'Landlord');
    _aiUser =
        ChatUser(id: 'docuMind_ai', firstName: 'DocuMind', lastName: 'AI');
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesStreamProvider);

    return propertiesAsync.when(
      data: (properties) {
        if (properties.isEmpty) {
          return _buildNoPropertiesState();
        }

        if (_selectedPropertyId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedPropertyId = properties.first.id;
            });
          });
          return _buildLoadingState();
        }

        return _buildMainUI(properties);
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
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
              child:
                  Icon(Icons.document_scanner, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DocuMind',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Document Intelligence',
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
          if (!_showChatInterface && _selectedCategory != null)
            _buildBackToCategoriesRow(),
          Expanded(
            child: _showChatInterface
                ? _buildChatInterface()
                : (_selectedCategory == null
                    ? _buildCategoryGrid()
                    : _buildCategoryDocuments()),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<String>(
                  tooltip: 'Switch Property',
                  onSelected: (propertyId) {
                    // Unit filter is property-specific; clear it on switch.
                    ref
                        .read(selectedDocumindUnitProvider.notifier)
                        .select(null);
                    setState(() {
                      _selectedPropertyId = propertyId;
                      _selectedCategory = null;
                      _showChatInterface = true;
                      _messages.clear();
                      _docuMindSessionId = null;
                      _docuMindConversationTurn = 1;
                      _awaitingUserAction = false;
                      _messages.add(
                        ChatMessage(
                          user: _aiUser,
                          createdAt: DateTime.now(),
                          text:
                              'Switched to ${_getPropertyName(properties, propertyId)}. How can I help?',
                        ),
                      );
                    });
                  },
                  itemBuilder: (context) => properties.map((property) {
                    return PopupMenuItem<String>(
                      value: property.id,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getPropertyColor(
                                  properties.indexOf(property)),
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
                            Icon(Icons.check,
                                color: AppColors.success, size: 16),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.home_work_outlined,
                            size: 18, color: AppColors.primaryCyan),
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
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeToggleButton(
                      icon: Icons.chat_outlined,
                      label: 'Chat',
                      selected: _showChatInterface,
                      onTap: () {
                        setState(() {
                          _showChatInterface = true;
                        });
                      },
                    ),
                    _buildModeToggleButton(
                      icon: Icons.folder_outlined,
                      label: 'Docs',
                      selected: !_showChatInterface,
                      onTap: () {
                        setState(() {
                          _showChatInterface = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildUnitFilterRow(),
        ],
      ),
    );
  }

  /// Unit filter below the property picker: scopes the Docs list and chat
  /// retrieval to one unit's documents plus property-wide documents.
  /// Hidden when the property has no units.
  Widget _buildUnitFilterRow() {
    if (_selectedPropertyId == null) return const SizedBox.shrink();

    final unitsAsync =
        ref.watch(unitsForPropertyStreamProvider(_selectedPropertyId!));
    final units = unitsAsync.value ?? const <Unit>[];
    if (units.isEmpty) return const SizedBox.shrink();

    final selectedUnit = ref.watch(selectedDocumindUnitProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PopupMenuButton<String>(
        tooltip: 'Filter by Unit',
        onSelected: (unitId) {
          final unit =
              unitId.isEmpty ? null : units.firstWhere((u) => u.id == unitId);
          ref.read(selectedDocumindUnitProvider.notifier).select(unit);
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: '',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'All units',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: selectedUnit == null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (selectedUnit == null)
                  Icon(Icons.check, color: AppColors.success, size: 16),
              ],
            ),
          ),
          ...units.map(
            (unit) => PopupMenuItem<String>(
              value: unit.id,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      unit.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: unit.id == selectedUnit?.id
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (unit.id == selectedUnit?.id)
                    Icon(Icons.check, color: AppColors.success, size: 16),
                ],
              ),
            ),
          ),
        ],
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.meeting_room_outlined,
                  size: 16, color: AppColors.primaryCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedUnit == null
                      ? 'All units'
                      : '${selectedUnit.label} + property-wide docs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more, size: 18, color: AppColors.primaryCyan),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggleButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [AppColors.primaryCyan, AppColors.primaryBlue],
                )
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.primaryCyan,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
          onPressed: () {
            setState(() {
              _selectedCategory = null;
            });
          },
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
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              _getCategoryColor(category).withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getCategoryColor(category).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getCategoryIcon(category).icon,
                color: _getCategoryColor(category),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _getCategoryLabel(category),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to view',
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

  Widget _buildCategoryDocuments() {
    if (_selectedPropertyId == null || _selectedCategory == null) {
      return _buildLoadingState();
    }

    final documentsAsync =
        ref.watch(documindDocumentsProvider(_selectedPropertyId!));

    return documentsAsync.when(
      data: (allDocuments) {
        final categoryDocs = allDocuments
            .where((doc) => doc.category == _selectedCategory)
            .toList();

        if (categoryDocs.isEmpty) {
          return _buildEmptyCategoryState(_selectedCategory!);
        }

        return Stack(
          children: [
            Column(
              children: [
                _buildCategorySectionHeader(
                  category: _selectedCategory!,
                  documentCount: categoryDocs.length,
                ),
                Expanded(child: _buildDocumentsList(categoryDocs)),
              ],
            ),
            if (_isUploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: _getCategoryColor(_selectedCategory!),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Uploading document...',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Processing ${(_uploadProgress * 100).toInt()}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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

  Widget _buildEmptyCategoryState(String category) {
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);

    return Stack(
      children: [
        Column(
          children: [
            _buildCategorySectionHeader(category: category),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        'No ${_getCategoryLabel(category)} Yet',
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
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => _uploadDocument(category),
                        icon: Icon(Icons.upload_file, color: Colors.white),
                        label: Text(
                          'Upload ${_getCategoryLabel(category)}',
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isUploading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: categoryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading document...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing ${(_uploadProgress * 100).toInt()}%',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySectionHeader({
    required String category,
    int? documentCount,
  }) {
    final categoryColor = _getCategoryColor(category);

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
                child: _getCategoryIcon(category),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCategoryLabel(category),
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
              if (isCompact)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showChatInterface = true;
                    });
                  },
                  icon: Icon(Icons.chat_bubble_outline,
                      size: 18, color: AppColors.primaryCyan),
                  tooltip: 'Ask DocuMind',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                )
              else
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showChatInterface = true;
                    });
                  },
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

  Widget _buildDocumentTile(DocuMindDocument doc, String category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Document icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getCategoryColor(category).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getCategoryColor(category).withOpacity(0.3),
              ),
            ),
            child: Icon(
              Icons.description_outlined,
              color: _getCategoryColor(category),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Document info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filename
                Text(
                  doc.filename,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Category badge + metadata
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getCategoryColor(category).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(category).icon,
                            size: 12,
                            color: _getCategoryColor(category),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _getCategoryColor(category),
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Unit badge (only for unit-scoped documents)
                    if (doc.unitLabel != null)
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
                              doc.unitLabel!.toUpperCase(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Upload time
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

                    // Chunks count
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
              ],
            ),
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
    );
  }

  Widget _buildAddMoreButton(String category) {
    // Get category-specific colors
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        onPressed: () => _uploadDocument(category),
        icon: Icon(
          categoryIcon.icon,
          color: categoryColor, // Dynamic color
        ),
        label: Text(
          'Add More ${_getCategoryLabel(category)}',
          style: TextStyle(
            color: categoryColor, // Dynamic color
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(
            color: categoryColor.withOpacity(0.5), // Dynamic border
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: categoryColor.withOpacity(0.1), // Dynamic background
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
      // Unit lookup failing shouldn't block an upload; treat as no units.
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
                              'Leases usually belong to a specific unit',
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

  Future<void> _uploadDocument(String category) async {
    if (_selectedPropertyId == null) {
      _showSnackBar('Please select a property first', isError: true);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      // Use any-file picker for better cloud provider compatibility (e.g., Google Drive),
      // then enforce extension checks locally.
      type: FileType.any,
    );

    if (result != null) {
      final selectedFile = result.files.single;
      final selectedName = selectedFile.name.toLowerCase();
      final isAllowed =
          selectedName.endsWith('.pdf') || selectedName.endsWith('.docx');

      if (!isAllowed) {
        _showSnackBar('Only PDF and DOCX files are supported.', isError: true);
        return;
      }

      if (selectedFile.path == null) {
        _showSnackBar('Unable to access selected file path.', isError: true);
        return;
      }

      // Ask which unit this document belongs to (skipped when the property
      // has no units). Null result = user cancelled the dialog.
      final unitChoice = await _pickUploadUnit(category: category);
      if (unitChoice == null) return;

      // Show loading state
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      try {
        final uploadAction = ref.read(uploadDocumentActionProvider);

        // Simulate progress (if needed)
        setState(() => _uploadProgress = 0.3);

        await uploadAction(
          propertyId: _selectedPropertyId!,
          category: category,
          file: File(selectedFile.path!),
          unitId: unitChoice.unit?.id,
          unitLabel: unitChoice.unit?.label,
        );

        // Complete progress
        setState(() => _uploadProgress = 1.0);

        // Wait a moment to show completion, then hide
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
          });
          _showSnackBar('Document uploaded successfully!');
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
                    color: _getCategoryColor(doc.category),
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
        // Show loading indicator
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

        // Call delete action from provider
        final deleteAction = ref.read(deleteDocumentActionProvider);
        await deleteAction(
          propertyId: _selectedPropertyId!,
          docId: doc.docId,
        );

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show success message
        if (mounted) {
          _showSnackBar('Document deleted successfully!');
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show error message
        if (mounted) {
          _showSnackBar(
            'Delete failed: ${e.toString()}',
            isError: true,
          );
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // SOURCE RELEVANCE METER (attached under the AI bubble it belongs to)
  // ══════════════════════════════════════════════════════
  Widget _buildRelevanceMeter(List<Citation> citations) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined,
                  size: 13, color: AppColors.registry),
              const SizedBox(width: 6),
              Text('SOURCE RELEVANCE',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.registry)),
            ],
          ),
          const SizedBox(height: 8),
          ...citations.take(3).map((c) => _buildCitationLine(c)),
        ],
      ),
    );
  }

  Widget _buildCitationLine(Citation citation) {
    return InkWell(
      onTap: () {
        if (_selectedPropertyId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              propertyId: _selectedPropertyId!,
              docId: citation.docId,
              filename: citation.filename,
              page: citation.page,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Flexible(
              child: Text(
                '${citation.filename} · p.${citation.page ?? '—'}',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (citation.unitLabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  citation.unitLabel!.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CHAT INTERFACE
  // ══════════════════════════════════════════════════════
  Widget _buildChatInterface() {
    final showEmptyPrompt = _messages.isEmpty && !_isThinking;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: _isThinking
                  ? _buildThinkingState()
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        border:
                            Border(top: BorderSide(color: AppColors.hairline)),
                      ),
                      child: DashChat(
                        currentUser: _currentUser,
                        onSend: _onSendMessage,
                        messages: _messages,
                        messageOptions: MessageOptions(
                          showTime: false,
                          containerColor: AppColors.surfaceLight,
                          currentUserContainerColor:
                              AppColors.registry.withValues(alpha: 0.15),
                          currentUserTextColor: AppColors.textPrimary,
                          textColor: AppColors.textPrimary,
                          borderRadius: 16,
                          messagePadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          markdownStyleSheet: MarkdownStyleSheet(
                            p: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textPrimary),
                            strong: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            listBullet: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textPrimary),
                            h1: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.textPrimary),
                            h2: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.textPrimary),
                            h3: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.textPrimary),
                          ),
                          bottom: (message, previousMessage, nextMessage) {
                            final citations =
                                message.customProperties?['citations']
                                    as List<Citation>?;
                            if (citations == null || citations.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return _buildRelevanceMeter(citations);
                          },
                        ),
                        inputOptions: InputOptions(
                          cursorStyle: CursorStyle(color: AppColors.registry),
                          inputMaxLines: 4,
                          inputDecoration: InputDecoration(
                            hintText: 'Ask about your documents…',
                            hintStyle: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.card,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: AppColors.hairline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: AppColors.hairline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                  color: AppColors.registry, width: 2),
                            ),
                          ),
                          sendButtonBuilder: (send) => GestureDetector(
                            onTap: send,
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.registry,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.send_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        if (showEmptyPrompt) _buildEmptyState(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Icon(
                  Icons.chat_outlined,
                  size: 36,
                  color: AppColors.registry,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ask Me Anything',
                style: AppTextStyles.titleLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Type a question about your documents to get started.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSendMessage(ChatMessage message) async {
    if (_selectedPropertyId == null) return;

    setState(() {
      _messages.insert(0, message);
      _isThinking = true;
    });

    try {
      final askAction = ref.read(askDocuMindQuestionActionProvider);
      final userAction = mapDocuMindUserAction(
        awaitingUserAction: _awaitingUserAction,
        messageText: message.text,
        categories: _categories,
        unitOptions: _pendingUnitOptions,
      );
      if (userAction != null &&
          userAction.startsWith('unit:') &&
          userAction != 'unit:all') {
        _syncUnitFilterFromAction(userAction.substring('unit:'.length));
      }
      final answer = await askAction(
        propertyId: _selectedPropertyId!,
        question: message.text,
        categories: null,
        sessionId: _docuMindSessionId,
        conversationTurn: _docuMindConversationTurn,
        userAction: userAction,
      );
      _consumeAnswer(answer, message.text);
    } catch (e) {
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            user: _aiUser,
            createdAt: DateTime.now(),
            text: 'Error: ${e.toString()}',
          ),
        );
        _isThinking = false;
      });
    }
  }

  /// Keep the header unit filter in sync with a unit chosen in chat, so the
  /// Docs tab and follow-up questions stay scoped to the same unit.
  void _syncUnitFilterFromAction(String unitId) {
    if (_selectedPropertyId == null) return;
    final units =
        ref.read(unitsForPropertyStreamProvider(_selectedPropertyId!)).value ??
            const <Unit>[];
    for (final unit in units) {
      if (unit.id == unitId) {
        ref.read(selectedDocumindUnitProvider.notifier).select(unit);
        break;
      }
    }
  }

  void _consumeAnswer(DocuMindAnswer answer, String sourceQuestion) {
    _lastQuestion = sourceQuestion;
    _docuMindSessionId = answer.sessionId ?? _docuMindSessionId;
    _docuMindConversationTurn = answer.conversationTurn + 1;
    _awaitingUserAction = answer.userActionRequired;
    _pendingUnitOptions =
        answer.userActionRequired ? answer.unitOptions : const [];

    final responseText = buildDocuMindAssistantText(
      answer: answer,
      categoryLabelResolver: _getCategoryLabel,
    );

    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          user: _aiUser,
          createdAt: DateTime.now(),
          text: responseText,
          isMarkdown: true,
          customProperties: answer.citations.isNotEmpty
              ? {'citations': answer.citations}
              : null,
        ),
      );
      _isThinking = false;
    });
  }

  // Helper methods
  String _getCategoryLabel(String category) {
    final labels = {
      'lease': 'Tenancy Agreements',
      'warranty': 'Warranties',
      'insurance': 'Insurance Policies',
      'utility': 'Utility Bills',
      'receipt': 'Receipts & Invoices',
      'other': 'Other Documents',
    };
    return labels[category] ?? category.toUpperCase();
  }

  Icon _getCategoryIcon(String category) {
    final iconMap = {
      'lease': Icons.description_outlined,
      'warranty': Icons.verified_user_outlined,
      'insurance': Icons.security_outlined,
      'utility': Icons.bolt_outlined,
      'receipt': Icons.receipt_long_outlined,
      'other': Icons.folder_outlined,
    };

    return Icon(iconMap[category] ?? Icons.folder_outlined);
  }

  Color _getCategoryColor(String category) {
    final colorMap = {
      'lease': AppColors.catLease,
      'warranty': AppColors.catWarranty,
      'insurance': AppColors.catInsurance,
      'utility': AppColors.catUtility,
      'receipt': AppColors.catReceipt,
      'other': AppColors.catOther,
    };
    return colorMap[category] ?? AppColors.catOther;
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
        title: Text('DocuMind'),
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

  Widget _buildThinkingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primaryCyan),
          const SizedBox(height: 16),
          Text(
            'DocuMind is thinking...',
            style: AppTextStyles.bodyMedium,
          ),
        ],
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

/// Option order for the upload unit-picker dialog. A null entry is the
/// "Whole property" option. Leases lead with units (a lease almost always
/// belongs to one unit) and demote "Whole property" to last; every other
/// category keeps "Whole property" first.
List<Unit?> uploadUnitDialogOptions({
  required String category,
  required List<Unit> units,
}) {
  if (category == 'lease') {
    return [...units, null];
  }
  return [null, ...units];
}
