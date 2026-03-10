import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/landlord_rex_ai_provider.dart';
import '../../widgets/AI/rex_message_bubble.dart';

/// Landlord Rex AI Screen - AI Assistant Chat Interface
/// 
/// Features:
/// - Chat interface with Rex AI
/// - File upload for document analysis
/// - Context-aware responses (Lease Sentinel, DocuMind)
/// - Interactive cards for complex scenarios
class LandlordRexAIScreen extends ConsumerStatefulWidget {
  final RexContext? initialContext;

  const LandlordRexAIScreen({
    super.key,
    this.initialContext,
  });

  @override
  ConsumerState<LandlordRexAIScreen> createState() => _LandlordRexAIScreenState();
}

class _LandlordRexAIScreenState extends ConsumerState<LandlordRexAIScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(rexAIProvider(widget.initialContext).notifier).sendMessage(text);
    _textController.clear();

    // Scroll to bottom after message is added
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null && result.files.single.name.isNotEmpty) {
      ref
          .read(rexAIProvider(widget.initialContext).notifier)
          .uploadFile(result.files.single.name);

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final rexState = ref.watch(rexAIProvider(widget.initialContext));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 600,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    AppColors.purple.withOpacity(0.3),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(rexState.context),

                // Chat messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: rexState.messages.length + (rexState.isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Thinking indicator
                      if (index == rexState.messages.length && rexState.isThinking) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: _ThinkingIndicator(),
                        );
                      }

                      final message = rexState.messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: RexMessageBubble(message: message),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Input dock (floating at bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInputDock(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(RexContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Rex icon
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.slate800,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.purple.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withOpacity(0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              color: AppColors.purple,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rex',
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 18,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  context.label.toUpperCase(),
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.purple.withOpacity(0.8),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Score bridge widget (if applicable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withOpacity(0.4),
                  AppColors.warning.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '720',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'SCORE',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 8,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    size: 14,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputDock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.background.withOpacity(0.9),
            AppColors.background,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),

            // Text input
            Expanded(
              child: TextField(
                controller: _textController,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Input Directive...',
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),

            const SizedBox(width: 8),

            // File upload button
            IconButton(
              onPressed: _pickFile,
              icon: Icon(
                Icons.camera_alt_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),

            // Send button
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  gradient: _textController.text.isNotEmpty
                      ? AppColors.buttonGradient
                      : null,
                  color: _textController.text.isEmpty
                      ? AppColors.slate700
                      : null,
                  shape: BoxShape.circle,
                  boxShadow: _textController.text.isNotEmpty
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.send,
                  size: 18,
                  color: _textController.text.isNotEmpty
                      ? Colors.white
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thinking indicator animation
class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _AnimatedDot(delay: index * 200),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  final int delay;

  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _controller.value),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.purple,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}