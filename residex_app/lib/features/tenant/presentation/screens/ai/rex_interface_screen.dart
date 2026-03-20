import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/residex_bottom_nav.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/gemini_service.dart';

/// Represents a single chat message
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });
}

/// Status of a message
enum MessageStatus {
  sending,
  sent,
  error,
}

class RexInterfaceScreen extends StatefulWidget {
  final String? initialContext;
  final String? initialVoiceInput;

  const RexInterfaceScreen({
    super.key,
    this.initialContext,
    this.initialVoiceInput,
  });

  @override
  State<RexInterfaceScreen> createState() => _RexInterfaceScreenState();
}

class _RexInterfaceScreenState extends State<RexInterfaceScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _isAITyping = false;
  final GeminiService _geminiService = GeminiService();
  String _streamingResponse = '';

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _geminiService.startNewChat();
    _messageController.addListener(() => setState(() {}));

    if (widget.initialVoiceInput != null && widget.initialVoiceInput!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageController.text = widget.initialVoiceInput!;
        _handleSendMessage();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChat() {
    String greeting;

    if (widget.initialContext == 'lease') {
      greeting = "Hi! I can help you understand your lease agreement. What would you like to know?";
    } else if (widget.initialContext == 'maintenance') {
      greeting = "Hi! I'm here to help with maintenance issues. What's going on?";
    } else if (widget.initialContext == 'fairfix') {
      greeting = "Hi! Let's make sure your maintenance requests are handled fairly. How can I help?";
    } else {
      greeting = "Hi! I'm Rex, your AI housing assistant. How can I help you today?";
    }

    _messages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: greeting,
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.deepSpace,
              AppColors.spaceBase,
              AppColors.deepSpace,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              const SizedBox(height: 16),
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessageList(),
              ),
              _buildInputArea(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ResidexBottomNav(
        currentRoute: '/rex-interface',
        role: UserRole.tenant,
        onNavigate: (route) {
          context.go(route);
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.cyan500.withValues(alpha: 0.2),
                  AppColors.purple500.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.cyan500.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan500.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.bot,
              color: AppColors.cyan500,
              size: 24,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: const Duration(seconds: 2),
                color: AppColors.purple500.withValues(alpha: 0.3),
              ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REX',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.emerald500,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald500.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .fadeOut(duration: const Duration(seconds: 1))
                        .then()
                        .fadeIn(duration: const Duration(seconds: 1)),

                    const SizedBox(width: 6),

                    const Text(
                      'A.I. Assistant',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(
              LucideIcons.info,
              color: AppColors.textTertiary,
              size: 20,
            ),
            onPressed: () {},
            tooltip: 'About Rex',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.cyan500.withValues(alpha: 0.1),
                AppColors.purple500.withValues(alpha: 0.1),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.bot,
            size: 64,
            color: AppColors.cyan500,
          ),
        )
            .animate()
            .scale(duration: const Duration(milliseconds: 600))
            .then()
            .shimmer(duration: const Duration(seconds: 2)),

        const SizedBox(height: 24),

        const Text(
          "Hi! I'm Rex",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          "Your AI housing assistant",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 32),

        const Text(
          "Try asking:",
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSuggestionChip("What are my tenant rights?"),
                const SizedBox(height: 12),
                _buildSuggestionChip("How do I report maintenance?"),
                const SizedBox(height: 12),
                _buildSuggestionChip("Explain my lease"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GlassCard(
      opacity: 0.05,
      width: double.infinity,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _buildMessageBubble(context, message),
        );
      },
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    if (message.isUser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cyan500,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              _formatTime(message.timestamp),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      );
    }

    // REX bubble
    final isEmpty = message.content.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.deepSpace,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.cyan500.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(LucideIcons.bot, size: 13, color: AppColors.cyan500),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.indigo500,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: AppColors.indigo400.withValues(alpha: 0.3),
                    ),
                  ),
                  child: isEmpty
                      ? const _ThinkingDots()
                      : Text(
                          message.content,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            _formatTime(message.timestamp),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    final hasText = _messageController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.cyan500.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Ask Rex anything...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleSendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasText ? AppColors.cyan500 : AppColors.slate700,
                  shape: BoxShape.circle,
                  boxShadow: hasText
                      ? [
                          BoxShadow(
                            color: AppColors.cyan500.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  LucideIcons.send,
                  size: 16,
                  color: hasText ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isAITyping = true;
      _streamingResponse = '';
    });

    _scrollToBottom();

    final aiMsgId = '${DateTime.now().millisecondsSinceEpoch}_ai';
    setState(() {
      _messages.add(ChatMessage(
        id: aiMsgId,
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      ));
    });

    _geminiService.sendMessage(text).listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          _streamingResponse += chunk;
          final idx = _messages.indexWhere((m) => m.id == aiMsgId);
          if (idx != -1) {
            _messages[idx] = ChatMessage(
              id: aiMsgId,
              content: _streamingResponse,
              isUser: false,
              timestamp: DateTime.now(),
              status: MessageStatus.sending,
            );
          }
        });
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isAITyping = false;
          final idx = _messages.indexWhere((m) => m.id == aiMsgId);
          if (idx != -1) {
            _messages[idx] = ChatMessage(
              id: aiMsgId,
              content: _streamingResponse,
              isUser: false,
              timestamp: DateTime.now(),
              status: MessageStatus.sent,
            );
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _isAITyping = false;
          final idx = _messages.indexWhere((m) => m.id == aiMsgId);
          if (idx != -1) {
            _messages[idx] = ChatMessage(
              id: aiMsgId,
              content: 'Sorry, I had trouble connecting. Please try again.',
              isUser: false,
              timestamp: DateTime.now(),
              status: MessageStatus.error,
            );
          }
        });
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}

/// Animated bouncing dots shown while Rex is generating a response
class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              color: AppColors.indigo300,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .moveY(
                begin: 0,
                end: -5,
                delay: Duration(milliseconds: i * 150),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              )
              .then()
              .moveY(
                begin: -5,
                end: 0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
        }),
      ),
    );
  }
}
