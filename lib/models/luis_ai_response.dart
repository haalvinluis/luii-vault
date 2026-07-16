import '../ai/intent_classifier.dart';

/// The full structured response returned by the Luis AI brain for a single
/// user utterance.
class LuisAiResponse {
  /// "command" | "conversation" | "clarify"
  final String type;

  /// Short natural-language reply meant to be spoken aloud via TTS.
  final String reply;

  /// Zero or more intents/actions to execute, in order.
  final List<VoiceIntent> intents;

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
          .map((i) {
            final m = Map<String, dynamic>.from(i as Map);
            return VoiceIntent(
              action: m['action'] as String? ?? 'CONVERSATION',
              value: m['value'] as String?,
            );
          })
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'reply': reply,
      'intents': intents.map((i) => {
        'action': i.action,
        'value': i.value,
      }).toList(),
    };
  }

  bool get isCommand => type == 'command';
  bool get isClarify => type == 'clarify';
}
