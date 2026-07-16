class ContextManager {
  String? currentSongTitle;
  String? currentPlaylistName;
  String currentScreen = "reels";
  double currentVolume = 0.5;
  bool isShuffle = false;
  bool isRepeat = false;
  
  final List<String> _conversationHistory = [];

  void recordQuery(String query) {
    _conversationHistory.add(query);
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeAt(0);
    }
  }

  void recordResponse(String response) {
    _conversationHistory.add("Jarvis: $response");
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeAt(0);
    }
  }

  List<String> get conversationHistory => List.unmodifiable(_conversationHistory);

  void clearHistory() {
    _conversationHistory.clear();
  }
}
