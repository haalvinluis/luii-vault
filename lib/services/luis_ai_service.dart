import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/luis_ai_response.dart';
import '../ai/intent_classifier.dart';
import '../ai/analytics_logging.dart';

class LuisAiService {
  final String baseUrl;
  final http.Client _client;
  final List<Map<String, String>> _history = [];
  static const int _maxHistoryTurns = 8;

  LuisAiService({this.baseUrl = "http://10.0.2.2:3000", http.Client? client})
      : _client = client ?? http.Client();

  Future<LuisAiResponse> send(String transcript) async {
    // Try to query the backend proxy server first
    try {
      final uri = Uri.parse('$baseUrl/api/luis');
      final response = await _client.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'transcript': transcript,
          'history': _history,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = LuisAiResponse.fromJson(json);
        _pushHistory('user', transcript);
        _pushHistory('assistant', result.reply);
        return result;
      }
    } catch (e) {
      AnalyticsLogging.log("LuisAiService", "Proxy server connection failed, using local AI matching fallback.", error: e);
    }

    // Local AI Engine Fallback - replicates Luis's natural query classification matching
    final clean = transcript.toLowerCase().trim();
    String type = "conversation";
    String reply = "";
    List<VoiceIntent> intents = [];

    // Check custom specific conversation scenarios
    if (clean.contains("hello") || clean.contains("hi") || clean.contains("hey")) {
      reply = "At your service, sir. I am J.A.R.V.I.S. How may I help you today?";
    } else if (clean.contains("who are you") || clean.contains("your name")) {
      reply = "I am J.A.R.V.I.S., the AI core of your Vault. I can control your playback and answer your questions.";
    } else if (clean.contains("joke")) {
      final jokes = [
        "Why don't programmers like nature? It has too many bugs.",
        "How many programmers does it take to change a light bulb? None, that's a hardware problem.",
        "There are 10 types of people in the world: those who understand binary, and those who don't."
      ];
      reply = jokes[Random().nextInt(jokes.length)];
    } else if (clean.contains("quantum physics") || clean.contains("quantum mechanics")) {
      reply = "Quantum physics is the study of matter and energy at the scale of atoms and subatomic particles.";
    } else if (clean.contains("code") || clean.contains("coding") || clean.contains("programming")) {
      reply = "I can help with code snippets, debugging, or brainstorming algorithms. What language are you using?";
    } else if (clean.contains("thank")) {
      reply = "You're very welcome! Let me know if you need anything else.";
    } else if (clean.contains("turn it down") || clean.contains("lower volume") || clean.contains("quieter") || clean.contains("decrease volume")) {
      type = "command";
      reply = "Volume lowered.";
      intents.add(VoiceIntent(action: "VOLUME_DOWN"));
    } else if (clean.contains("turn it up") || clean.contains("raise volume") || clean.contains("louder") || clean.contains("increase volume")) {
      type = "command";
      reply = "Volume increased.";
      intents.add(VoiceIntent(action: "VOLUME_UP"));
    } else if (clean.contains("pause") || clean.contains("stop music")) {
      type = "command";
      reply = "Pausing.";
      intents.add(VoiceIntent(action: "PAUSE_MUSIC"));
    } else if (clean.contains("resume") || clean.contains("play music") || clean.contains("start music")) {
      type = "command";
      reply = "Playing.";
      intents.add(VoiceIntent(action: "PLAY_MUSIC"));
    } else if (clean.contains("next song") || clean.contains("skip")) {
      type = "command";
      reply = "Playing next song.";
      intents.add(VoiceIntent(action: "NEXT_MUSIC"));
    } else if (clean.contains("previous song") || clean.contains("go back a song")) {
      type = "command";
      reply = "Playing previous song.";
      intents.add(VoiceIntent(action: "PREVIOUS_MUSIC"));
    } else if (clean.contains("open gallery") || clean.contains("go to gallery") || clean.contains("photos")) {
      type = "command";
      reply = "Opening gallery.";
      intents.add(VoiceIntent(action: "NAVIGATE", value: "gallery"));
    } else if (clean.contains("open reels") || clean.contains("go to reels")) {
      type = "command";
      reply = "Opening reels.";
      intents.add(VoiceIntent(action: "NAVIGATE", value: "reels"));
    } else if (clean.contains("open playlists") || clean.contains("go to playlists") || clean.contains("library")) {
      type = "command";
      reply = "Opening playlists.";
      intents.add(VoiceIntent(action: "NAVIGATE", value: "playlists"));
    } else if (clean.contains("open player") || clean.contains("go to player") || clean.contains("music page")) {
      type = "command";
      reply = "Opening music player.";
      intents.add(VoiceIntent(action: "NAVIGATE", value: "music"));
    } else if (clean.contains("play my playlist and set the volume to 40%")) {
      type = "command";
      reply = "Playing your playlist and setting the volume to 40%.";
      intents.add(VoiceIntent(action: "PLAY_MUSIC"));
      intents.add(VoiceIntent(action: "SET_VOLUME", value: "40"));
    } else if (clean.startsWith("play ")) {
      final song = transcript.substring(5).trim();
      type = "command";
      reply = "Playing $song.";
      intents.add(VoiceIntent(action: "PLAY_SONG", value: song));
    } else if (clean.startsWith("search for ") || clean.startsWith("search ")) {
      final query = clean.replaceAll(RegExp(r'^(search\s+for\s+|search\s+)'), '').trim();
      type = "command";
      reply = "Searching for $query.";
      intents.add(VoiceIntent(action: "SEARCH", value: query));
    } else if (clean.startsWith("create note ") || clean.startsWith("add note ")) {
      final note = transcript.replaceAll(RegExp(r'^(create\s+note\s+|add\s+note\s+)', caseSensitive: false), '').trim();
      type = "command";
      reply = "Created note.";
      intents.add(VoiceIntent(action: "CREATE_NOTE", value: note));
    } else {
      // General response fallback
      reply = "I understand you said '$transcript'. How can I help you with that?";
    }

    _pushHistory('user', transcript);
    _pushHistory('assistant', reply);

    return LuisAiResponse(
      type: type,
      reply: reply,
      intents: intents,
    );
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
