import 'intent_classifier.dart';
import 'action_executor.dart';
import 'ai_conversation_engine.dart';
import 'context_manager.dart';
import 'analytics_logging.dart';
import 'error_recovery_system.dart';

class CommandDispatcher {
  final ContextManager contextManager;

  CommandDispatcher({required this.contextManager});

  Future<String> dispatch(String speechText, Function(String page)? onNavigate) async {
    AnalyticsLogging.log("Dispatcher", "Dispatching query: '$speechText'");
    contextManager.recordQuery(speechText);

    final intents = IntentClassifier.classify(speechText);
    if (intents.isEmpty) {
      return "I'm not sure I understood that command.";
    }

    final List<String> replies = [];

    for (final intent in intents) {
      if (intent.action == "CONVERSATION") {
        final reply = AiConversationEngine.generateReply(
          intent.value ?? "",
          contextManager.conversationHistory,
        );
        replies.add(reply);
      } else {
        // Execute command safely
        final reply = await ErrorRecoverySystem.runSafeAsync<String>(
          () => ActionExecutor.execute(intent.action, intent.value, onNavigate),
          "Failed to execute command ${intent.action}.",
        );
        replies.add(reply);
      }
    }

    final finalReply = replies.join(" And ");
    contextManager.recordResponse(finalReply);
    return finalReply;
  }
}
