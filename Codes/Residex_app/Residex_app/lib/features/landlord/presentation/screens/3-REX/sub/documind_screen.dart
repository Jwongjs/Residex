import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'dart:io';
import '../../../../../../core/theme/app_theme.dart';
import '../../../providers/documind_provider.dart';
import '../../../providers/property_providers.dart';
import '../../../../domain/entities/documind_document.dart';
import '../../../../domain/entities/property.dart';

/// DocuMind Screen - Property Document Management + Q&A
class DocuMindScreen extends ConsumerStatefulWidget {
  const DocuMindScreen({super.key});

  @override
  ConsumerState<DocuMindScreen> createState() => _DocuMindScreenState();
}

class _DocuMindScreenState extends ConsumerState<DocuMindScreen> {
  
  String? _selectedPropertyId;
  String? _selectedCategory;
  bool _showChatInterface = false;
  bool _isUploading = false; // Track upload state
  double _uploadProgress = 0.0; // Track progress
  
  // Chat state
  final List<ChatMessage> _messages = [];
  late final ChatUser _currentUser;
  late final ChatUser _aiUser;
  bool _isThinking = false;

  // Document categories (6 total)
  final List<String> _categories = [
    'lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'
  ];

  // Quick questions for chat
  final List<String> _quickQuestions = [
    '📋 What are the lease terms?',
    '📅 When does the lease expire?',
    '💰 What is the monthly rent?',
    '🛡️ What does the warranty cover?',
    '📋 What is the deposit amount?',
  ];

  @override
  void initState() {
    super.initState();
    
    _currentUser = ChatUser(id: 'user_1', firstName: 'Landlord');
    _aiUser = ChatUser(id: 'docuMind_ai', firstName: 'DocuMind', lastName: 'AI');
    
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
              child: Icon(Icons.document_scanner, color: Colors.white, size: 20),
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
                    _getPropertyName(properties, _selectedPropertyId),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Back button if in category view
          if (_selectedCategory != null)
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.primaryCyan),
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                });
              },
              tooltip: 'Back to Categories',
            ),
          
          // ✅ IMPROVED: More visible toggle button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: _showChatInterface
                  ? LinearGradient(
                      colors: [AppColors.primaryCyan, AppColors.primaryBlue],
                    )
                  : null,
              color: _showChatInterface ? null : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showChatInterface 
                    ? AppColors.primaryCyan 
                    : AppColors.border,
                width: 2,
              ),
            ),
            child: IconButton(
              icon: Icon(
                _showChatInterface ? Icons.folder_outlined : Icons.chat_outlined,
                color: _showChatInterface ? Colors.white : AppColors.primaryCyan,
              ),
              onPressed: () {
                setState(() {
                  _showChatInterface = !_showChatInterface;
                });
              },
              tooltip: _showChatInterface ? 'View Documents' : 'Ask Questions',
            ),
          ),
          
          // Property selector dropdown
          PopupMenuButton<String>(
            icon: Icon(Icons.expand_more, color: AppColors.primaryCyan),
            tooltip: 'Switch Property',
            onSelected: (propertyId) {
              setState(() {
                _selectedPropertyId = propertyId;
                _selectedCategory = null;
                _showChatInterface = false;
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    user: _aiUser,
                    createdAt: DateTime.now(),
                    text: 'Switched to ${_getPropertyName(properties, propertyId)}. How can I help?',
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
                        color: _getPropertyColor(properties.indexOf(property)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        property.name,
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
          ),
        ],
      ),
      body: _showChatInterface
          ? _buildChatInterface()
          : (_selectedCategory == null
              ? _buildCategoryGrid()
              : _buildCategoryDocuments()),
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

  final documentsAsync = ref.watch(documindDocumentsProvider(_selectedPropertyId!));
  
  return documentsAsync.when(
    data: (allDocuments) {
      final categoryDocs = allDocuments
          .where((doc) => doc.category == _selectedCategory)
          .toList();
      
      if (categoryDocs.isEmpty) {
        return _buildEmptyCategoryState(_selectedCategory!);
      }
      
      // ✅ Wrap with Scaffold to add AppBar with back button
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: _getCategoryColor(_selectedCategory!),
            ),
            onPressed: () {
              setState(() {
                _selectedCategory = null; // ✅ Go back to category grid
              });
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getCategoryColor(_selectedCategory!).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getCategoryColor(_selectedCategory!).withOpacity(0.3),
                  ),
                ),
                child: _getCategoryIcon(_selectedCategory!),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCategoryLabel(_selectedCategory!),
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${categoryDocs.length} document${categoryDocs.length == 1 ? '' : 's'}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // ✅ Ask DocuMind button
            IconButton(
              onPressed: () {
                setState(() {
                  _showChatInterface = true;
                });
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryCyan.withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.primaryCyan,
                  size: 20,
                ),
              ),
              tooltip: 'Ask DocuMind',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            _buildDocumentsList(categoryDocs),
            
            // ✅ Upload overlay if uploading
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
        ),
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
  
  return Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: categoryColor,
        ),
        onPressed: () {
          setState(() {
            _selectedCategory = null;
          });
        },
      ),
      title: Row(
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
            child: categoryIcon,
          ),
          const SizedBox(width: 12),
          Text(
            _getCategoryLabel(category),
            style: AppTextStyles.titleMedium,
          ),
        ],
      ),
    ),
    body: Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Category-colored empty icon
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
              ),
              const SizedBox(height: 8),
              Text(
                'Upload your first document to get started',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              
              // ✅ Upload button with category color
              ElevatedButton.icon(
                onPressed: () => _uploadDocument(category),
                icon: Icon(Icons.upload_file, color: Colors.white),
                label: Text(
                  'Upload ${_getCategoryLabel(category)}',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
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
        
        // ✅ Upload overlay
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
              // ✅ Filename
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
              
              // ✅ Category badge + metadata
              Row(
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
                  const SizedBox(width: 12),
                  
                  // Upload time
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(doc.uploadedAt),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Chunks count
                  Icon(
                    Icons.grid_view_rounded,
                    size: 14,
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
  // ✅ Get category-specific colors
  final categoryColor = _getCategoryColor(category);
  final categoryIcon = _getCategoryIcon(category);
  
  return Container(
    margin: const EdgeInsets.only(top: 16),
    child: OutlinedButton.icon(
      onPressed: () => _uploadDocument(category),
      icon: Icon(
        categoryIcon.icon,
        color: categoryColor, // ✅ Dynamic color
      ),
      label: Text(
        'Add More ${_getCategoryLabel(category)}',
        style: TextStyle(
          color: categoryColor, // ✅ Dynamic color
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(
          color: categoryColor.withOpacity(0.5), // ✅ Dynamic border
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: categoryColor.withOpacity(0.1), // ✅ Dynamic background
      ),
    ),
  );
}

  Future<void> _uploadDocument(String category) async {
    if (_selectedPropertyId == null) {
      _showSnackBar('Please select a property first', isError: true);
      return;
    }
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      // ✅ Show loading state
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      try {
        final uploadAction = ref.read(uploadDocumentActionProvider);
        
        // ✅ Simulate progress (if needed)
        setState(() => _uploadProgress = 0.3);
        
        await uploadAction(
          propertyId: _selectedPropertyId!,
          category: category,
          file: File(result.files.single.path!),
        );

        // ✅ Complete progress
        setState(() => _uploadProgress = 1.0);
        
        // ✅ Wait a moment to show completion, then hide
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
          });
          _showSnackBar('✅ Document uploaded successfully!');
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
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancel',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted),
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

      // ✅ Call delete action from provider
      final deleteAction = ref.read(deleteDocumentActionProvider);
      await deleteAction(
        propertyId: _selectedPropertyId!,
        docId: doc.docId,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        _showSnackBar('✅ Document deleted successfully!');
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
  // CHAT INTERFACE
  // ══════════════════════════════════════════════════════
  Widget _buildChatInterface() {
    final hasUserMessages = _messages.any((msg) => msg.user.id == _currentUser.id);

    return Stack(
      children: [
        Column(
          children: [
            if (hasUserMessages) _buildQuickQuestionsBar(),
            
            Expanded(
              child: _isThinking
                  ? _buildThinkingState()
                  : DashChat(
                      currentUser: _currentUser,
                      onSend: _onSendMessage,
                      messages: _messages,
                      messageOptions: MessageOptions(
                        showTime: false,
                        containerColor: AppColors.surfaceLight,
                        currentUserContainerColor: AppColors.primaryCyan.withValues(alpha: 0.25),
                        currentUserTextColor: AppColors.textPrimary,
                        textColor: AppColors.textPrimary,
                        borderRadius: 16,
                        messagePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      inputOptions: InputOptions(
                        cursorStyle: CursorStyle(color: AppColors.primaryCyan),
                        inputMaxLines: 4,
                        inputDecoration: InputDecoration(
                          hintText: 'Ask about your documents…',
                          hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        // ✅ IMPROVED: Better contrast for send button
                        sendButtonBuilder: (send) => GestureDetector(
                          onTap: send,
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primaryCyan, AppColors.primaryBlue],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryCyan.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),

        // ✅ Centered quick questions (empty state)
        if (!hasUserMessages && !_isThinking)
          _buildCenteredQuickQuestions(),
      ],
    );
  }

  Widget _buildCenteredQuickQuestions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryCyan.withValues(alpha: 0.2),
                    AppColors.primaryBlue.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryCyan.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.chat_outlined,
                size: 48,
                color: AppColors.primaryCyan,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ask Me Anything',
              style: AppTextStyles.titleLarge.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a question below or type your own',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: _quickQuestions.length,
              itemBuilder: (context, index) => _buildQuickQuestionCard(_quickQuestions[index], index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQuestionCard(String question, int index) {
    final parts = question.split(' ');
    final emoji = parts.first;
    final text = parts.skip(1).join(' ');

    final gradients = [
      [AppColors.primaryBlue, AppColors.primaryCyan],
      [AppColors.purple, AppColors.primaryBlue],
      [AppColors.success, AppColors.primaryCyan],
      [AppColors.warning, AppColors.orange],
      [AppColors.primaryCyan, AppColors.success],
    ];

    final gradient = gradients[index % gradients.length];

    return GestureDetector(
      onTap: () => _sendQuickQuestion(question),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradient[0].withValues(alpha: 0.2),
              gradient[1].withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradient[0].withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQuestionsBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _quickQuestions.length,
        itemBuilder: (_, i) {
          final q = _quickQuestions[i];
          return GestureDetector(
            onTap: () => _sendQuickQuestion(q),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.25)),
              ),
              alignment: Alignment.center,
              child: Text(
                q,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryCyan),
              ),
            ),
          );
        },
      ),
    );
  }

  void _sendQuickQuestion(String question) {
    final message = ChatMessage(
      user: _currentUser,
      createdAt: DateTime.now(),
      text: question,
    );
    _onSendMessage(message);
  }

  Future<void> _onSendMessage(ChatMessage message) async {
    if (_selectedPropertyId == null) return;
    
    setState(() {
      _messages.insert(0, message);
      _isThinking = true;
    });

    try {
      final askAction = ref.read(askDocuMindQuestionActionProvider);
      final answer = await askAction(
        propertyId: _selectedPropertyId!,
        question: message.text,
      );

      String responseText = answer.answer;
      
      if (answer.citations.isNotEmpty) {
        responseText += '\n\n📚 Sources:\n';
        for (var cite in answer.citations.take(3)) {
          responseText += '• ${cite.filename} (page ${cite.page ?? 'N/A'})\n';
        }
      }

      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            user: _aiUser,
            createdAt: DateTime.now(),
            text: responseText,
          ),
        );
        _isThinking = false;
      });
    } catch (e) {
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            user: _aiUser,
            createdAt: DateTime.now(),
            text: '❌ Error: ${e.toString()}',
          ),
        );
        _isThinking = false;
      });
    }
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
      'lease': AppColors.primaryBlue,
      'warranty': AppColors.success,
      'insurance': AppColors.warning,
      'utility': AppColors.info,
      'receipt': AppColors.purple,
      'other': AppColors.textMuted,
    };
    
    return colorMap[category] ?? AppColors.textMuted;
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
      AppColors.primaryBlue,
      AppColors.purple,
      AppColors.success,
      AppColors.warning,
      AppColors.primaryCyan,
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
        content: Text(message),
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