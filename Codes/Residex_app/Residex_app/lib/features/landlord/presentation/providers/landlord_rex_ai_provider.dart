// lib/features/landlord/presentation/providers/landlord_rex_ai_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Message types for Rex AI responses
enum MessageType {
  text,
  actionRequired,
  suggestion,
  warning,
  cardWarningShot,
  cardFinalStraw,
  cardJuryDuty,
}

/// Chat message model
class RexMessage {
  final String id;
  final String sender; // 'REX' or 'USER'
  final String text;
  final MessageType type;
  final String? attachment;
  final Map<String, dynamic>? cardData;
  final DateTime timestamp;

  RexMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.type = MessageType.text,
    this.attachment,
    this.cardData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Rex AI context modes
enum RexContext {
  concierge('Concierge Mode'),
  fiscalAnalyst('Fiscal Analyst'),
  harmonyEngine('Harmony Engine'),
  contractGuardian('Contract Guardian'),
  maintenanceChief('Maintenance Chief'),
  propertyCommander('Property Commander');

  final String label;
  const RexContext(this.label);
}

/// Rex AI state
class RexAIState {
  final List<RexMessage> messages;
  final bool isThinking;
  final RexContext context;

  RexAIState({
    required this.messages,
    this.isThinking = false,
    this.context = RexContext.propertyCommander,
  });

  RexAIState copyWith({
    List<RexMessage>? messages,
    bool? isThinking,
    RexContext? context,
  }) {
    return RexAIState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      context: context ?? this.context,
    );
  }
}

/// Rex AI provider (mock logic for Phase 1)
class RexAINotifier extends Notifier<RexAIState> {
  final RexContext? initialContext;
  
  RexAINotifier(this.initialContext);

  @override
  RexAIState build() {
    return RexAIState(
      messages: [
        RexMessage(
          id: '1',
          sender: 'REX',
          text: _getInitialGreeting(initialContext ?? RexContext.propertyCommander),
          type: MessageType.text,
        ),
      ],
      context: initialContext ?? RexContext.propertyCommander,
    );
  }

  static String _getInitialGreeting(RexContext context) {
    switch (context) {
      case RexContext.fiscalAnalyst:
        return "Fiscal protocols engaged. Rent is due in T-minus 72 hours. Your liability share is RM 600. Initiating settlement sequence?";
      case RexContext.harmonyEngine:
        return "Harmony diagnostics online. Roster check: You are assigned 'Trash Disposal' today. Failure to execute will impact your social standing.";
      case RexContext.contractGuardian:
        return "Lease Sentinel active. Upload the PDF. I will scan for predation, ambiguity, and non-standard clauses.";
      case RexContext.maintenanceChief:
        return "Systems check initiated. I detect 3 active alerts. Do you wish to override the AC repair schedule or escalate the plumbing ticket?";
      case RexContext.propertyCommander:
        return "Commander on deck. Portfolio revenue is up 8.4%. I have a draft lease ready for Unit 4-2. Awaiting your signature.";
      default:
        return "Greetings, Commander. Rex Neural Core is fully operational. Sync Score: STABLE. Awaiting your directive.";
    }
  }

  /// Send user message
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    // Add user message
    final userMessage = RexMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'USER',
      text: text,
      type: MessageType.text,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isThinking: true,
    );

    // Simulate AI processing
    Future.delayed(const Duration(milliseconds: 1500), () {
      final response = _processLogic(text);
      state = state.copyWith(
        messages: [...state.messages, response],
        isThinking: false,
      );
    });
  }

  /// Mock AI logic (Phase 1)
  RexMessage _processLogic(String query) {
    final q = query.toLowerCase();

    if (q.contains('bill') || q.contains('pay') || q.contains('owe')) {
      return RexMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'REX',
        text: "Acknowledged. Financial reconciliation requested. To proceed with the split protocol, I require a verified transaction artifact (Receipt/PDF).",
        type: MessageType.actionRequired,
      );
    }

    if (q.contains('hi') || q.contains('hello')) {
      return RexMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'REX',
        text: "We have already established connection. State your intent.",
        type: MessageType.text,
      );
    }

    if (q.contains('lease') || q.contains('contract')) {
      return RexMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'REX',
        text: "Lease analysis module active. Upload contract document for risk assessment.",
        type: MessageType.actionRequired,
      );
    }

    return RexMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'REX',
      text: "Directive unclear. My neural net is optimized for Housing Management, Finance, and Dispute Resolution. Please refine your query.",
      type: MessageType.text,
    );
  }

  /// Handle file upload (mock)
  void uploadFile(String fileName) {
    final uploadMessage = RexMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'USER',
      text: 'Uploaded: $fileName',
      type: MessageType.text,
      attachment: fileName,
    );

    state = state.copyWith(
      messages: [...state.messages, uploadMessage],
      isThinking: true,
    );

    Future.delayed(const Duration(milliseconds: 2000), () {
      final response = RexMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'REX',
        text: "Scan complete. Data extracted with 99.8% confidence. Total: RM 45.50. Distribution protocol ready. Execute notification sequence?",
        type: MessageType.suggestion,
      );

      state = state.copyWith(
        messages: [...state.messages, response],
        isThinking: false,
      );
    });
  }

  /// Simulate warning scenarios (for testing)
  void simulateWarning() {
    state = state.copyWith(isThinking: true);

    Future.delayed(const Duration(milliseconds: 1000), () {
      final warning = RexMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'REX',
        text: 'Alert: Anomaly detected in your stewardship record.',
        type: MessageType.cardWarningShot,
        cardData: {'chore': 'Kitchen Duty', 'timeLeft': '2h'},
      );

      state = state.copyWith(
        messages: [...state.messages, warning],
        isThinking: false,
      );
    });
  }
}

/// Provider for Rex AI chat
final rexAIProvider = NotifierProvider.family<RexAINotifier, RexAIState, RexContext?>(
  RexAINotifier.new,
);