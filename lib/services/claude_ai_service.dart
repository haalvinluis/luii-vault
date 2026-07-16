import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/luis_ai_response.dart';

/// Talks to YOUR backend proxy (server/server.js), which in turn calls
/// Claude. The API key never lives in the app.
class ClaudeAiService {
  /// Point this at wherever you deploy server/server.js, e.g.
  /// "https://luis-ai-proxy.onrender.com" or "http://10.0.2.2:3000" for the
  /// Android emulator talking to a local server.
  final String baseUrl;
  final http.Client _client;

  /// Rolling short-term memory sent with every request so Luis can resolve
  /// follow-ups like "the next one" or "explain it again". Kept small to
  /// keep latency down.
  final List<Map<String, String>> _history = [];
  static const int _maxHistoryTurns = 8;

  ClaudeAiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<LuisAiResponse> send(String transcript) async {
    final uri = Uri.parse('$baseUrl/api/luis');

    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'transcript': transcript,
        'history': _history,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Luis AI error (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final result = LuisAiResponse.fromJson(json);

    _pushHistory('user', transcript);
    _pushHistory('assistant', result.reply);

    return result;
  }

  void _pushHistory(String role, String content) {
    _history.add({'role': role, 'content': content});
    while (_history.length > _maxHistoryTurns * 2) {
      _history.removeAt(0);
    }
  }

  void clearHistory() => _history.clear();

  void dispose() => _client.close();
}
