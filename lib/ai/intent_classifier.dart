class VoiceIntent {
  final String action;
  final String? value;

  VoiceIntent({required this.action, this.value});
}

class IntentClassifier {
  /// Splits compound commands using 'and' or 'then' and classifies individual actions.
  static List<VoiceIntent> classify(String text) {
    final normalized = text.toLowerCase().trim()
        .replaceAll(RegExp(r'^(hey\s+luis,\s*|hey\s+luis\s+|luis,\s*|luis\s+|hay\s+luis,\s*|hay\s+luis\s+)'), '');
    
    // Check if it's a compound query, split on " and " or " then "
    if (normalized.contains(" and ") || normalized.contains(" then ")) {
      final parts = normalized.split(RegExp(r'\s+and\s+|\s+then\s+'));
      final List<VoiceIntent> list = [];
      for (var part in parts) {
        list.add(_classifySingle(part.trim()));
      }
      return list;
    }
    
    return [_classifySingle(normalized)];
  }

  static VoiceIntent _classifySingle(String text) {
    final clean = text.toLowerCase().trim();

    // Direct conversational shortcuts
    if (clean.contains("go home") || clean.contains("return home") || clean.contains("back home") || clean == "home") {
      return VoiceIntent(action: "NAVIGATE", value: "home");
    }
    if (clean.contains("gallery") || clean.contains("photos") || clean.contains("pictures") || clean.contains("images")) {
      if (clean.contains("open") || clean.contains("go to") || clean.contains("show") || clean.contains("navigate")) {
        return VoiceIntent(action: "NAVIGATE", value: "gallery");
      }
    }
    if (clean.contains("reels") || 
        clean.contains("reel") || 
        clean.contains("video") || 
        clean.contains("videos") || 
        clean.contains("shorts") || 
        clean.contains("clip") || 
        clean.contains("clips") || 
        clean.contains("downloader")) {
      if (clean.contains("open") || 
          clean.contains("go to") || 
          clean.contains("show") || 
          clean.contains("navigate") || 
          clean.contains("switch")) {
        return VoiceIntent(action: "NAVIGATE", value: "reels");
      }
    }
    if (clean.contains("music") || clean.contains("player") || clean.contains("playlist") || clean.contains("library") || clean.contains("songs")) {
      if (clean.contains("open") || clean.contains("go to") || clean.contains("show") || clean.contains("navigate")) {
        return VoiceIntent(action: "NAVIGATE", value: "music");
      }
    }
    if (clean.contains("download this reel") || clean.contains("save this reel") || clean.contains("download reel") || clean.contains("save reel")) {
      return VoiceIntent(action: "DOWNLOAD_REEL");
    }

    // Navigation fallback
    if (text.startsWith("open ") || 
        text.startsWith("go to ") || 
        text.startsWith("navigate to ") ||
        text.startsWith("show ") ||
        text.startsWith("bring up ") ||
        text.startsWith("switch to ") ||
        text.startsWith("move to ")) {
      final target = text.replaceAll(RegExp(r'^(open\s+|go\s+to\s+|navigate\s+to\s+|show\s+|bring\s+up\s+|switch\s+to\s+|move\s+to\s+)'), '').trim();
      return VoiceIntent(action: "NAVIGATE", value: target);
    }
    if (text == "reels" || 
        text == "reel" || 
        text == "video" || 
        text == "videos" || 
        text == "shorts" || 
        text == "clips" || 
        text == "downloader" || 
        text == "gallery" || 
        text == "playlists" || 
        text == "playlist" || 
        text == "player" || 
        text == "music" || 
        text == "photos") {
      return VoiceIntent(action: "NAVIGATE", value: text);
    }
    if (text == "return to home" || text == "go back" || text == "back") {
      return VoiceIntent(action: "NAVIGATE_BACK");
    }

    // Reels Playback Controls
    if (clean.contains("next video") || clean.contains("next reel") || clean.contains("play next video") || clean.contains("skip video") || clean.contains("skip reel")) {
      return VoiceIntent(action: "REELS_NEXT");
    }
    if (clean.contains("previous video") || clean.contains("previous reel") || clean.contains("prev video") || clean.contains("prev reel") || clean.contains("go back video")) {
      return VoiceIntent(action: "REELS_PREV");
    }
    if (clean.contains("pause video") || clean.contains("pause reel") || clean.contains("stop video") || clean.contains("stop reel")) {
      return VoiceIntent(action: "REELS_PAUSE");
    }
    if (clean.contains("resume video") || clean.contains("resume reel") || clean.contains("play video") || clean.contains("play reel")) {
      return VoiceIntent(action: "REELS_PLAY");
    }

    // Playback Controls
    if (clean.contains("play music") || clean.contains("play my playlist") || clean.contains("resume music") || clean == "resume" || clean == "play") {
      return VoiceIntent(action: "PLAY_MUSIC");
    }
    if (clean.contains("pause music") || clean == "pause" || clean == "stop music") {
      return VoiceIntent(action: "PAUSE_MUSIC");
    }
    if (clean.contains("next song") || clean == "next" || clean.contains("play next")) {
      return VoiceIntent(action: "NEXT_MUSIC");
    }
    if (clean.contains("previous song") || clean == "previous" || clean.contains("play previous")) {
      return VoiceIntent(action: "PREVIOUS_MUSIC");
    }
    if (clean == "shuffle" || clean == "turn shuffle on") {
      return VoiceIntent(action: "SHUFFLE_ON");
    }
    if (clean == "turn shuffle off") {
      return VoiceIntent(action: "SHUFFLE_OFF");
    }
    if (clean == "repeat" || clean == "repeat this song") {
      return VoiceIntent(action: "REPEAT_ON");
    }
    if (clean == "mute") {
      return VoiceIntent(action: "MUTE");
    }
    if (clean == "unmute") {
      return VoiceIntent(action: "UNMUTE");
    }

    // Volume level
    if (clean.startsWith("set the volume to ") || clean.startsWith("set volume to ")) {
      final volStr = clean.replaceAll(RegExp(r'^(set\s+the\s+volume\s+to\s+|set\s+volume\s+to\s+)'), '').replaceAll('%', '').trim();
      return VoiceIntent(action: "SET_VOLUME", value: volStr);
    }
    if (clean == "increase volume" || clean == "raise volume" || clean == "louder") {
      return VoiceIntent(action: "VOLUME_UP");
    }
    if (clean == "decrease volume" || clean == "lower volume" || clean == "quieter") {
      return VoiceIntent(action: "VOLUME_DOWN");
    }

    // specific song
    if (clean.contains("play ")) {
      final playIndex = clean.indexOf("play ");
      var song = clean.substring(playIndex + 5).trim();
      
      if (song.startsWith("song ")) song = song.substring(5).trim();
      if (song.startsWith("track ")) song = song.substring(6).trim();
      if (song.startsWith("the song ")) song = song.substring(9).trim();
      if (song.startsWith("the track ")) song = song.substring(10).trim();
      if (song.endsWith(" song")) song = song.substring(0, song.length - 5).trim();
      if (song.endsWith(" track")) song = song.substring(0, song.length - 6).trim();
      
      if (song.isNotEmpty && 
          song != "music" && 
          song != "my playlist" && 
          song != "playlist" && 
          song != "songs") {
        return VoiceIntent(action: "PLAY_SONG", value: song);
      }
    }

    // Search
    if (clean.startsWith("search for ") || clean.startsWith("search ")) {
      final query = clean.replaceAll(RegExp(r'^(search\s+for\s+|search\s+)'), '').trim();
      return VoiceIntent(action: "SEARCH", value: query);
    }

    // Productivity
    if (clean.startsWith("create note ") || clean.startsWith("add note ")) {
      final note = clean.replaceAll(RegExp(r'^(create\s+note\s+|add\s+note\s+)'), '').trim();
      return VoiceIntent(action: "CREATE_NOTE", value: note);
    }

    // Default general AI Conversation
    return VoiceIntent(action: "CONVERSATION", value: clean);
  }
}
