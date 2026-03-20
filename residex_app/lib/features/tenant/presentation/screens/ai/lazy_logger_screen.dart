import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

class _Property {
  final String id;
  final String name;
  final String unit;
  final Color color;
  _Property(this.id, this.name, this.unit, this.color);
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final bool hasCitation;
  _ChatMsg(this.text, {this.isUser = false, this.hasCitation = false});
}

class LazyLoggerScreen extends StatefulWidget {
  const LazyLoggerScreen({super.key});

  @override
  State<LazyLoggerScreen> createState() => _LazyLoggerScreenState();
}

class _LazyLoggerScreenState extends State<LazyLoggerScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isUploading = false;
  bool _showUploadSuccess = false;
  bool _showPropertySelector = false;

  final _properties = [
    _Property('p1', 'Verdi Eco-Dominium', 'Unit 4-2', AppColors.blue600),
    _Property('p2', 'The Grand Subang', 'Block B-12', AppColors.purple500),
    _Property('p3', 'Arcuz Kelana Jaya', 'Unit 08-01', AppColors.emerald500),
  ];

  late _Property _activeProperty;
  late List<_ChatMsg> _messages;

  @override
  void initState() {
    super.initState();
    _activeProperty = _properties[0];
    _messages = [
      _ChatMsg('Lazy Logger system online. I have indexed documents for ${_properties[0].name}. What do you need to find?'),
    ];
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMsg(text, isUser: true));
      _inputController.clear();
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      String response;
      bool hasCitation = true;
      final lower = text.toLowerCase();

      if (lower.contains('ac') || lower.contains('aircon') || lower.contains('warranty')) {
        response = 'Found in \'Acson_Warranty_${_activeProperty.unit.replaceAll(' ', '')}.pdf\': The warranty for the Master Bedroom AC in ${_activeProperty.name} expires on 15 March 2026. Coverage includes compressor and gas refill.';
      } else if (lower.contains('bill') || lower.contains('water') || lower.contains('tnb')) {
        response = 'Reference \'TNB_Sept2025.pdf\' for ${_activeProperty.unit}: The last electricity bill was RM 154.20 (Due 28 Sept). It was 12% higher than August.';
      } else if (lower.contains('insurance') || lower.contains('policy')) {
        response = 'According to \'Allianz_Home_Policy.pdf\', fire insurance for ${_activeProperty.name} covers up to RM 500,000. Next premium payment is due 01 Jan 2026.';
      } else {
        response = 'I couldn\'t find that in your documents. Can you be more specific?';
        hasCitation = false;
      }

      setState(() {
        _messages.add(_ChatMsg(response, hasCitation: hasCitation));
      });
      _scrollToBottom();
    });
  }

  void _simulateUpload() {
    setState(() => _isUploading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _showUploadSuccess = true;
        _messages.add(_ChatMsg('Successfully indexed document to ${_activeProperty.name} database.'));
      });
      _scrollToBottom();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showUploadSuccess = false);
      });
    });
  }

  void _switchProperty(_Property prop) {
    setState(() {
      _activeProperty = prop;
      _showPropertySelector = false;
      _messages.add(_ChatMsg('Context switched to ${prop.name} (${prop.unit}). Document search is now scoped to this property.'));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Indigo glow
          Positioned(
            top: 0, left: 0, right: 0, height: 500,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [AppColors.indigo500.withValues(alpha: 0.2), const Color(0xFF02040A)],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Stack(
                    children: [
                      _buildChatArea(),
                      _buildInputBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Upload overlay
          if (_isUploading) _buildUploadOverlay(),

          // Success toast
          if (_showUploadSuccess) _buildSuccessToast(),

          // Property selector modal
          if (_showPropertySelector) _buildPropertySelector(),
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
              decoration: BoxDecoration(
                color: AppColors.indigo500.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: AppColors.indigo400),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAZY LOGGER',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white, letterSpacing: -0.5)),
                Text('AI DOCUMENT INDEXER',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.indigo400.withValues(alpha: 0.6))),
              ],
            ),
          ),
          GestureDetector(
            onTap: _simulateUpload,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.indigo500,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.indigo500.withValues(alpha: 0.2), blurRadius: 20)],
              ),
              child: const Icon(Icons.upload, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      children: [
        // Context switcher
        _buildContextSwitcher(),
        const SizedBox(height: 16),
        // Messages
        ..._messages.map((msg) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildMessageBubble(msg),
        )),
      ],
    );
  }

  Widget _buildContextSwitcher() {
    return GestureDetector(
      onTap: () => setState(() => _showPropertySelector = true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A15).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _activeProperty.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.apartment, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACTIVE PROPERTY',
                      style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.indigo300)),
                  Text(_activeProperty.name,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(_activeProperty.unit,
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate500)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.indigo400),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMsg msg) {
    return Row(
      mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!msg.isUser) ...[
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.indigo500.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.indigo400),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: msg.isUser
                  ? AppColors.indigo500
                  : const Color(0xFF0A0A15),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                bottomRight: Radius.circular(msg.isUser ? 4 : 16),
              ),
              border: msg.isUser ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: msg.isUser
                  ? [BoxShadow(color: AppColors.indigo500.withValues(alpha: 0.2), blurRadius: 10)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg.text, style: GoogleFonts.inter(fontSize: 13, color: msg.isUser ? Colors.white : AppColors.textSecondary, height: 1.5)),
                if (msg.hasCitation) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
                    child: Row(
                      children: [
                        const Icon(Icons.description, size: 10, color: AppColors.indigo300),
                        const SizedBox(width: 6),
                        Text('Source Verified',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.indigo300)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (msg.isUser) ...[
          const SizedBox(width: 10),
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              color: AppColors.slate700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('ME', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputBar() {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black, Colors.black.withValues(alpha: 0.9), Colors.transparent],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search ${_activeProperty.name}...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.indigo500,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.send, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description, size: 60, color: AppColors.indigo400),
              const SizedBox(height: 24),
              Text('Indexing Document', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.indigo400),
                  ),
                  const SizedBox(width: 10),
                  Text('EXTRACTING VECTOR EMBEDDINGS...',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.indigo400)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessToast() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.emerald500.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text('Document Secured', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertySelector() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showPropertySelector = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Context',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('Choose property to query',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showPropertySelector = false),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 20, color: AppColors.slate400),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ..._properties.map((prop) {
                      final isSelected = _activeProperty.id == prop.id;
                      return GestureDetector(
                        onTap: () => _switchProperty(prop),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.indigo500.withValues(alpha: 0.15)
                                : AppColors.slate800.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.indigo500.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: prop.color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.apartment, size: 20, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(prop.name,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                    Text(prop.unit,
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 32, height: 32,
                                  decoration: const BoxDecoration(
                                    color: AppColors.indigo500,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
