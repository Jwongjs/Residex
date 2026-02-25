import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rex_ai_main_menu_screen.dart';
import 'landlord_rex_ai_screen.dart';
import '../../providers/landlord_rex_ai_provider.dart';

/// Rex AI Tab Wrapper - Shows main menu or chat interface
class RexAITabWrapper extends ConsumerWidget {
  const RexAITabWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, always show main menu (chat integration will come later)
    return const RexAIMainMenuScreen();
  }
}
