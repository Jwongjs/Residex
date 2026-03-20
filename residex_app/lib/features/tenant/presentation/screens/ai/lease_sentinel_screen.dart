import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

enum _SentinelStep { upload, analyzing, dashboard }

class _ExtractedInsight {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isWarning;
  _ExtractedInsight(this.label, this.value, this.icon, this.color, {this.isWarning = false});
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, {this.isUser = false});
}

class LeaseSentinelScreen extends StatefulWidget {
  const LeaseSentinelScreen({super.key});

  @override
  State<LeaseSentinelScreen> createState() => _LeaseSentinelScreenState();
}

class _LeaseSentinelScreenState extends State<LeaseSentinelScreen> {
  _SentinelStep _step = _SentinelStep.upload;
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isThinking = false;
  bool _isDragOver = false;

  final _insights = [
    _ExtractedInsight('Monthly Rent', 'RM 1,800', Icons.attach_money, AppColors.emerald400),
    _ExtractedInsight('Deposit', '2.5 Months', Icons.warning_amber, AppColors.amber500, isWarning: true),
    _ExtractedInsight('Notice Period', '2 Months', Icons.schedule, AppColors.blue400),
    _ExtractedInsight('Pet Policy', 'Allowed (Small)', Icons.check_circle, AppColors.emerald400),
  ];

  final List<_ChatMessage> _messages = [
    _ChatMessage('I\'ve indexed your lease agreement. Here\'s my analysis:\n\n'
        '1. Rent is standard for the area.\n'
        '2. Deposit of 2.5 months is above the legal limit of 2 months — this is a red flag.\n'
        '3. Notice period is standard.\n\n'
        'Ask me anything about your contract.'),
  ];

  void _onUpload() {
    setState(() => _step = _SentinelStep.analyzing);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _step = _SentinelStep.dashboard);
    });
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text, isUser: true));
      _chatController.clear();
      _isThinking = true;
    });

    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      String response;
      final lower = text.toLowerCase();
      if (lower.contains('pet') || lower.contains('animal')) {
        response = 'Your lease allows small pets under 10kg. There\'s a RM 200 pet deposit clause in Section 4.2. This is within normal range.';
      } else if (lower.contains('visitor') || lower.contains('guest')) {
        response = 'Section 6.1 states overnight visitors must be registered after 3 consecutive nights. This is a common clause in Malaysian tenancies.';
      } else if (lower.contains('paint') || lower.contains('wall') || lower.contains('damage')) {
        response = 'Normal wear and tear is covered under Section 8. You are NOT liable for minor wall scuffs or paint fading. Only intentional damage can be deducted from deposit.';
      } else if (lower.contains('deposit') || lower.contains('refund')) {
        response = 'The 2.5-month deposit exceeds the legal maximum of 2 months under the Housing Accommodation Act. I recommend negotiating this down.';
      } else {
        response = 'Based on my analysis of your lease, I\'ll look into that. The contract appears to be a standard Malaysian tenancy agreement with a few notable clauses worth monitoring.';
      }
      setState(() {
        _isThinking = false;
        _messages.add(_ChatMessage(response));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: 500,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [AppColors.indigo500.withValues(alpha: 0.2), const Color(0xFF020617)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, size: 20, color: AppColors.slate400),
            ),
          ),
          const SizedBox(width: 16),
          Text('LEASE SENTINEL', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case _SentinelStep.upload:
        return _buildUploadView();
      case _SentinelStep.analyzing:
        return _buildAnalyzingView();
      case _SentinelStep.dashboard:
        return _buildDashboardView();
    }
  }

  // ─────────────────────────────────
  // UPLOAD VIEW
  // ─────────────────────────────────
  Widget _buildUploadView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GestureDetector(
          onTap: _onUpload,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 280,
            decoration: BoxDecoration(
              color: _isDragOver ? AppColors.indigo500.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: _isDragOver ? AppColors.indigo500.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.indigo500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.upload_file, size: 32, color: AppColors.indigo400),
                  ),
                  const SizedBox(height: 16),
                  Text('Upload Contract', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Tap to select PDF or image', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
                  const SizedBox(height: 16),
                  Text(
                    'Rex will scan for hidden clauses,\nunfair terms, and legal red flags.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // ANALYZING VIEW
  // ─────────────────────────────────
  Widget _buildAnalyzingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + 0.2 * value,
                child: Opacity(opacity: value, child: child),
              );
            },
            child: const Icon(Icons.description, size: 64, color: AppColors.indigo400),
          ),
          const SizedBox(height: 24),
          Text(
            'ANALYZING LEGALESE',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: AppColors.slate800,
                valueColor: AlwaysStoppedAnimation(AppColors.indigo500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Extracting Clauses...', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // DASHBOARD VIEW
  // ─────────────────────────────────
  Widget _buildDashboardView() {
    return Column(
      children: [
        // Insights grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: _insights.map((i) => _buildInsightCard(i)).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Analysis complete banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.emerald500.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 14, color: AppColors.emerald400),
              const SizedBox(width: 6),
              Text('Analysis Complete', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emerald400)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Chat area
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: _messages.length + (_isThinking ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isThinking && index == _messages.length) return _buildThinkingBubble();
              return _buildMessageBubble(_messages[index]);
            },
          ),
        ),

        // Input bar
        _buildInputBar(),
      ],
    );
  }

  Widget _buildInsightCard(_ExtractedInsight insight) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(insight.icon, size: 14, color: insight.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  insight.label.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.slate500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            insight.value,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: insight.isWarning ? insight.color : Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.indigo500.withValues(alpha: 0.3) : AppColors.slate800.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: msg.isUser ? null : Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: msg.isUser
            ? Text(msg.text, style: GoogleFonts.inter(fontSize: 13, color: Colors.white, height: 1.5))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: AppColors.indigo500, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.smart_toy, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(msg.text, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5))),
                ],
              ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.slate800.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 600 + i * 200),
              builder: (context, value, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.indigo400.withValues(alpha: 0.3 + 0.7 * value),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _chatController,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask about your lease...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.slate600),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.indigo500, AppColors.purple500]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
