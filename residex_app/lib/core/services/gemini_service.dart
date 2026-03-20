import 'package:google_generative_ai/google_generative_ai.dart';
import 'gemini_api_key.dart';
import 'dart:convert';
import 'dart:typed_data';

  class GeminiService {
    // -------------------------------------------------------------------------
    // Tenant system prompt
    // -------------------------------------------------------------------------
    static const _systemPrompt = '''
  You are Rex, an AI housing assistant for the Residex app — a Malaysian residential management platform.
  You help tenants with:
  - Understanding lease agreements and tenant rights under Malaysian law
  - Reporting and tracking maintenance issues
  - Managing bills, rent payments, and shared expenses
  - Resolving disputes with landlords fairly
  - Chore scheduling and housemate coordination

  Keep responses concise and practical. Use simple language.
  When relevant, reference Malaysian tenancy norms (no formal tenancy act — common law applies).
  Do not give legal advice — suggest consulting a lawyer for serious disputes.
  ''';

    // -------------------------------------------------------------------------
    // Landlord system prompt
    // -------------------------------------------------------------------------
    static const _landlordSystemPrompt = '''
You are Rex, an AI property management assistant for the Residex app — a Malaysian residential management platform built for landlords and property owners.

You help landlords with:
- Drafting, reviewing, and explaining tenancy agreements under Malaysian common law (no formal Residential Tenancy Act — rely on Contract Act 1950 and case law)
- Tracking rental income, payment arrears, deposits, and financial projections
- Managing and prioritising maintenance requests from tenants
- Tenant screening, onboarding, and professional relations management
- Portfolio management: occupancy rates, property valuations, and market insights
- Resolving tenant disputes calmly and within legal and ethical frameworks
- Generating lease clauses, notice letters, and formal correspondence

Persona: You are authoritative, calm, and precise — like a seasoned property manager and legal advisor combined. Be direct, structured, and practical. Use confident language.
Format responses clearly. Use numbered lists or bullet points where helpful. Keep replies under 200 words unless a detailed breakdown is explicitly needed.
Never give formal legal advice — recommend consulting a Malaysian property lawyer for serious legal matters.
''';

    final GenerativeModel _model;
    late final GenerativeModel _landlordModel;
    late final GenerativeModel _visionModel;
    ChatSession? _chatSession;
    ChatSession? _landlordChatSession;

    GeminiService()
        : _model = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: GeminiApiKey.value,
            systemInstruction: Content.system(_systemPrompt),
            generationConfig: GenerationConfig(
              temperature: 0.7,
              maxOutputTokens: 512,
           ),
        )
        {
              _landlordModel = GenerativeModel(
                model: 'gemini-2.5-flash',
                apiKey: GeminiApiKey.value,
                systemInstruction: Content.system(_landlordSystemPrompt),
                generationConfig: GenerationConfig(
                  temperature: 0.7,
                  maxOutputTokens: 512,
                ),
              );
              _visionModel = GenerativeModel(
                model: 'gemini-2.5-flash',
                apiKey: GeminiApiKey.value,
                generationConfig: GenerationConfig(
                  temperature: 0.2,
                  maxOutputTokens: 4096,
                ),
              );
        }

    // -------------------------------------------------------------------------
    // Tenant chat
    // -------------------------------------------------------------------------

    /// Start or reset the tenant chat session
    void startNewChat() {
      _chatSession = _model.startChat();
    }

    /// Send a message and get a streaming response (tenant)
    Stream<String> sendMessage(String userMessage) async* {
      _chatSession ??= _model.startChat();

      final response = _chatSession!.sendMessageStream(
        Content.text(userMessage),
      );

      await for (final chunk in response) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    }

    // -------------------------------------------------------------------------
    // Landlord chat
    // -------------------------------------------------------------------------

    /// Start or reset the landlord chat session
    void startLandlordChat() {
      _landlordChatSession = _landlordModel.startChat();
    }

    /// Send a message and get a streaming response (landlord)
    Stream<String> sendLandlordMessage(String userMessage) async* {
      _landlordChatSession ??= _landlordModel.startChat();

      final response = _landlordChatSession!.sendMessageStream(
        Content.text(userMessage),
      );

      await for (final chunk in response) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    }
    /// Single-turn generation (no chat history)
    Future<String> generateOnce(String prompt) async {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    }

    Future<String> analyzePropertyCondition({
  required String areaName,
  required Uint8List moveInBytes,
  required Uint8List currentBytes,
}) async {
   final prompt = '''You are a professional property condition assessor evaluating a rental unit at move-out time.                                                                                                                                                                                                                                                                                                                                                                                                                                         
  CONTEXT:
  - Image 1 is the MOVE-IN baseline photo taken when the tenant first moved in
  - Image 2 is the CURRENT photo taken now, potentially 1-2 years later
  - The photos will NOT be from the same angle or have the same lighting — this is normal and expected
  - Your job is to assess the CONDITION of the area, not to compare framing or angles

  AREA BEING ASSESSED: $areaName

  STEP 1 — BASIC VALIDITY CHECK:
  Only fail validation if an image is clearly the wrong subject entirely
  (e.g. a selfie submitted instead of a room photo, or a kitchen photo for a bedroom assessment).
  Minor angle differences, zoom differences, or different lighting do NOT fail validation.
  Set baselineValid and currentValid to true unless the image is completely unrelated to $areaName.

  STEP 2 — CONDITION ASSESSMENT:
  Look at Image 2 (current photo) carefully and identify:
  - Any visible damage: cracks, holes, stains, burns, broken fixtures, mold, peeling paint
  - Any missing items that were present in Image 1
  - Any significant deterioration beyond normal wear and tear

  Then cross-reference with Image 1 to determine:
  - Was this damage already present at move-in? (if yes, tenant is not liable)
  - Is this new damage that appeared during tenancy? (if yes, potentially chargeable)

  STEP 3 — MATCH PERCENT:
  This represents the overall condition match, not visual similarity.
  - 90-100: Excellent condition, same as move-in, only natural aging visible
  - 75-89: Good condition, minor issues that are borderline wear and tear
  - 50-74: Noticeable damage or deterioration beyond normal wear
  - Below 50: Significant damage clearly caused during tenancy

  Normal wear and tear (NOT chargeable): faded paint, minor scuffs, small nail holes, worn carpet in high-traffic areas
  Chargeable damage: large stains, burns, holes in walls, broken fixtures, mold from neglect, missing items

  Return ONLY a raw JSON object with no markdown, no code blocks, no extra text:
  {
    "baselineValid": true or false,
    "currentValid": true or false,
    "sameArea": true or false,
    "validationError": null or a string only if the image is completely unrelated to $areaName,
    "matchPercent": integer 0-100,
    "findings": [
      {
        "severity": "ok" or "warning" or "critical",
        "title": "3-5 word title",
        "description": "Specific, objective observation. Mention if it was pre-existing or new."
      }
    ],
    "estimatedDeductionMin": integer in RM,
    "estimatedDeductionMax": integer in RM,
    "wearAndTearNote": "One sentence on what is chargeable vs normal wear for this specific area under Malaysian tenancy norms"
  }''';

   final response = await _visionModel.generateContent([                                                                                                                                                                                                                                Content.multi([                                                                                                                                                                                                                                                        
        TextPart(prompt),
        DataPart('image/jpeg', moveInBytes),
        DataPart('image/jpeg', currentBytes),
      ])
    ]);
    final raw = response.text ?? '';
    print('flutter: GEMINI RAW: $raw');
    return raw;
  }

  /// Validates that a baseline photo matches the expected room/area.
  /// Returns {valid: bool, reason: String}.
  Future<Map<String, dynamic>> validateBaselinePhoto({
    required String areaName,
    required Uint8List imageBytes,
  }) async {
    final prompt = '''You are validating a move-in baseline photo for a rental property inspection system.

EXPECTED AREA: $areaName

Look at the photo and determine if it matches the expected area.

Rules:
- VALID if the photo clearly shows $areaName, even if the angle, framing, or lighting is imperfect
- INVALID if the photo clearly shows a different room or area (e.g. a kitchen photo submitted for "Bedroom")
- INVALID if the photo is not a room at all (e.g. a selfie, food, a phone/laptop screen, an outdoor scene, a random close-up object)
- Be lenient with imperfect framing or partial views — only reject if the subject is unambiguously wrong

Return ONLY a raw JSON object with no markdown, no code blocks, no extra text:
{
  "valid": true or false,
  "reason": "One concise sentence describing what the photo shows and why it is valid or invalid."
}''';

    try {
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ]);
      final raw = (response.text ?? '')
          .trim()
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // If validation fails for any reason (network, parse error), accept gracefully
      return {'valid': true, 'reason': 'Validation could not be completed.'};
    }
  }
}
  
 
  