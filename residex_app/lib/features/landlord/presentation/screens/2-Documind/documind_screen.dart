import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/documind_provider.dart';
import '../../providers/property_providers.dart';
import '../../providers/unit_providers.dart';
import '../../../domain/entities/documind_document.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import '../../widgets/common/document_categories.dart';
import 'documind_chat_logic.dart';
import 'document_viewer_screen.dart';
import 'unit_label_resolver.dart';

/// DocuMind Screen — the AI document Q&A assistant. Chat-only since Stage E
/// split the document-manager folder view out into DocumentsScreen
/// (5-Documents/documents_screen.dart) and its own bottom-nav tab.
class DocuMindScreen extends ConsumerStatefulWidget {
  const DocuMindScreen({super.key});

  @override
  ConsumerState<DocuMindScreen> createState() => _DocuMindScreenState();
}

class _DocuMindScreenState extends ConsumerState<DocuMindScreen> {
  String? _selectedPropertyId;

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

  // Granular category vocabulary the chat checkpoint can override to.
  static const List<String> _overrideCategories = [
    'lease',
    'insurance',
    'loan',
    'tax',
    'upkeep',
    'maintenance',
    'rental_invoice',
    'expenses',
  ];

  // Focus of the chat input. The empty-state overlay hides while it has
  // focus — the keyboard signal can't come from viewInsets because the
  // Scaffold consumes those before this subtree reads them.
  final FocusNode _chatInputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _currentUser = ChatUser(id: 'user_1', firstName: 'Landlord');
    _aiUser =
        ChatUser(id: 'docuMind_ai', firstName: 'DocuMind', lastName: 'AI');
    _chatInputFocusNode.addListener(_onChatInputFocusChange);
  }

  void _onChatInputFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chatInputFocusNode
      ..removeListener(_onChatInputFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesStreamProvider);

    return propertiesAsync.when(
      data: (properties) {
        if (properties.isEmpty) {
          return _buildNoPropertiesState();
        }

        final navTarget = ref.watch(documindNavTargetProvider);

        if (_selectedPropertyId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(documindNavTargetProvider.notifier).state = null;
            setState(() {
              _selectedPropertyId =
                  (navTarget != null && properties.any((p) => p.id == navTarget))
                      ? navTarget
                      : properties.first.id;
            });
          });
          return _buildLoadingState();
        }

        if (navTarget != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(documindNavTargetProvider.notifier).state = null;
            if (navTarget != _selectedPropertyId &&
                properties.any((p) => p.id == navTarget)) {
              _switchToProperty(navTarget, properties);
            }
          });
        }

        return _buildMainUI(properties);
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  /// Property switch: reset the conversation and greet on the new property.
  /// Used by the header dropdown and the dashboard expiry-tile tap-through.
  void _switchToProperty(String propertyId, List<Property> properties) {
    setState(() {
      _selectedPropertyId = propertyId;
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
          Expanded(child: _buildChatInterface()),
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
              onSelected: (propertyId) =>
                  _switchToProperty(propertyId, properties),
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
        ],
      ),
    );
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
    final displayUnitLabel = resolveUnitLabel(
      unitId: citation.unitId,
      storedLabel: citation.unitLabel,
      liveUnits: _liveUnits(),
    );

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
        // Filename is the only elastic part of the line: the page number and
        // unit badge keep their space, so "p.X" can never be squeezed out.
        child: Row(
          children: [
            Expanded(
              child: Text(
                citation.filename,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              ' · p.${citation.page ?? '—'}',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            if (displayUnitLabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    displayUnitLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
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
    final showEmptyPrompt =
        _messages.isEmpty && !_isThinking && !_chatInputFocusNode.hasFocus;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: DashChat(
                  currentUser: _currentUser,
                  onSend: _onSendMessage,
                  messages: _messages,
                  typingUsers: _isThinking ? [_aiUser] : const [],
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
                      final quickReplies =
                          message.customProperties?['quickReplies']
                              as List<String>?;
                      final showQuickReplies = quickReplies != null &&
                          quickReplies.isNotEmpty &&
                          _awaitingUserAction &&
                          _messages.isNotEmpty &&
                          identical(_messages.first, message);
                      final hasCitations =
                          citations != null && citations.isNotEmpty;
                      if (!hasCitations && !showQuickReplies) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasCitations) _buildRelevanceMeter(citations),
                          if (showQuickReplies)
                            _buildQuickReplyChips(quickReplies),
                        ],
                      );
                    },
                  ),
                  inputOptions: InputOptions(
                    focusNode: _chatInputFocusNode,
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
                        borderSide:
                            BorderSide(color: AppColors.registry, width: 2),
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
        if (showEmptyPrompt) IgnorePointer(child: _buildEmptyState()),
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
    if (_selectedPropertyId == null || _isThinking) return;

    setState(() {
      _messages.insert(0, message);
      _isThinking = true;
    });

    try {
      final askAction = ref.read(askDocuMindQuestionActionProvider);
      final userAction = mapDocuMindUserAction(
        awaitingUserAction: _awaitingUserAction,
        messageText: message.text,
        categories: _overrideCategories,
        unitOptions: _pendingUnitOptions,
      );
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

  void _consumeAnswer(DocuMindAnswer answer, String sourceQuestion) {
    _lastQuestion = sourceQuestion;
    _docuMindSessionId = answer.sessionId ?? _docuMindSessionId;
    _docuMindConversationTurn = answer.conversationTurn + 1;
    _awaitingUserAction = answer.userActionRequired;
    _pendingUnitOptions =
        answer.userActionRequired ? answer.unitOptions : const [];

    final responseText = buildDocuMindAssistantText(
      answer: answer,
      categoryLabelResolver: getCategoryLabel,
    );
    final quickReplies = buildDocuMindQuickReplies(answer);
    final customProperties = <String, dynamic>{
      if (answer.citations.isNotEmpty) 'citations': answer.citations,
      if (quickReplies.isNotEmpty) 'quickReplies': quickReplies,
    };

    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          user: _aiUser,
          createdAt: DateTime.now(),
          text: responseText,
          isMarkdown: true,
          customProperties: customProperties.isEmpty ? null : customProperties,
        ),
      );
      _isThinking = false;
    });
  }

  /// Checkpoint quick replies: tapping a chip sends its text as a normal
  /// user message, so the transcript shows the choice and the reply flows
  /// through the same mapDocuMindUserAction path as a typed answer.
  Widget _buildQuickReplyChips(List<String> replies) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: replies.map((reply) {
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _sendQuickReply(reply),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.registry.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.registry.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                reply,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.registry,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _sendQuickReply(String reply) {
    if (_isThinking) return;
    _onSendMessage(
      ChatMessage(
        user: _currentUser,
        createdAt: DateTime.now(),
        text: reply,
      ),
    );
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
}
