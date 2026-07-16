/// A single AI-recognized intent: an action name (matching the app's
/// existing ActionExecutor exactly) plus an optional value/parameter.
class AiIntent {
  final String action;
  final String? value;

  AiIntent({required this.action, this.value});

  factory AiIntent.fromJson(Map<String, dynamic> json) {
    return AiIntent(
      action: json['action'] as String? ?? 'CONVERSATION',
      value: json['value'] as String?,
    );
  }
}

/// The full structured response returned by the Luis AI brain for a single
/// user utterance.
class LuisAiResponse {
  /// "command" | "conversation" | "clarify"
  final String type;

  /// Short natural-language reply meant to be spoken aloud via TTS.
  final String reply;

  /// Zero or more intents/actions to execute, in order.
  final List<AiIntent> intents;

  LuisAiResponse({
    required this.type,
    required this.reply,
    required this.intents,
  });

  factory LuisAiResponse.fromJson(Map<String, dynamic> json) {
    final rawIntents = json['intents'] as List? ?? [];
    return LuisAiResponse(
      type: json['type'] as String? ?? 'conversation',
      reply: json['reply'] as String? ?? '',
      intents: rawIntents
          .map((i) => AiIntent.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }

  bool get isCommand => type == 'command';
}