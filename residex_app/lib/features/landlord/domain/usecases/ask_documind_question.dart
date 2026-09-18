import '../entities/documind_document.dart';
import '../repositories/documind_repository.dart';

/// Use case: Ask question to DocuMind
class AskDocuMindQuestion {
  final DocuMindRepository repository;

  const AskDocuMindQuestion(this.repository);

  Future<DocuMindAnswer> call({
    required String propertyId,
    required String question,
    int topK = 4,
    List<String>? categories,
    String? unitId,
    String? sessionId,
    int conversationTurn = 1,
  }) async {
    // ✅ Business validation
    if (question.trim().isEmpty) {
      throw ArgumentError('Question cannot be empty');
    }

    if (topK < 1 || topK > 10) {
      throw ArgumentError('topK must be between 1 and 10');
    }

    print('✅ UseCase: Ask question');
    print('   - Question: $question');
    print('   - Property: $propertyId');

    return await repository.askQuestion(
      propertyId: propertyId,
      question: question,
      topK: topK,
      categories: categories,
      unitId: unitId,
      sessionId: sessionId,
      conversationTurn: conversationTurn,
    );
  }
}