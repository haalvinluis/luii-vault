import 'dart:io';
import 'dart:math';
import '../audio/binaural_engine.dart';
import '../services/storage_service.dart';
import '../models/music_model.dart';
import 'analytics_logging.dart';

class ActionExecutor {
  static final BinauralEngine _binaural = BinauralEngine();
  static final StorageService _storage = StorageService();

  static Future<String> execute(String action, String? value, Function(String page)? onNavigate) async {
    AnalyticsLogging.log("ActionExecutor", "Executing: $action, Value: $value");

    switch (action) {
      case "PLAY_MUSIC":
        _binaural.play();
        return "Playing.";

      case "PAUSE_MUSIC":
        _binaural.pause();
        return "Pausing.";

      case "NEXT_MUSIC":
        _binaural.next();
        return "Playing next song.";

      case "PREVIOUS_MUSIC":
        _binaural.previous();
        return "Playing previous song.";

      case "SHUFFLE_ON":
        if (!_binaural.isShuffle) _binaural.toggleShuffle();
        return "Shuffle enabled.";

      case "SHUFFLE_OFF":
        if (_binaural.isShuffle) _binaural.toggleShuffle();
        return "Shuffle disabled.";

      case "MUTE":
        _binaural.mute();
        return "Muted.";

      case "UNMUTE":
        _binaural.unmute();
        return "Unmuted.";

      case "SET_VOLUME":
        final val = double.tryParse(value ?? "") ?? 0.5;
        final targetVol = val > 1.0 ? val / 100.0 : val;
        _binaural.setVolume(targetVol.clamp(0.0, 1.0));
        return "Volume set.";

      case "VOLUME_UP":
        _binaural.setVolume((_binaural.volume + 0.15).clamp(0.0, 1.0));
        return "Volume up.";

      case "VOLUME_DOWN":
        _binaural.setVolume((_binaural.volume - 0.15).clamp(0.0, 1.0));
        return "Volume down.";

      case "NAVIGATE":
        final target = (value ?? "").toLowerCase();
        String page = "reels";
        if (target == "gallery" || target == "photos") {
          page = "gallery";
        } else if (target == "playlists" || target == "library" || target == "downloads") {
          page = "playlists";
        } else if (target == "music" || target == "player") {
          page = "music";
        } else if (target == "assistant" || target == "ai assistant") {
          page = "assistant";
        } else if (target == "home" || target == "home screen") {
          page = "home";
        }
        if (onNavigate != null) {
          onNavigate(page);
        }
        return "Opening $target.";

      case "DOWNLOAD_REEL":
        if (onNavigate != null) {
          onNavigate("reels");
        }
        return "Opening Reels downloader page. Paste any Instagram Reel link there to save it directly to the vault.";

      case "PLAY_SONG":
        final query = (value ?? "").toLowerCase().trim();
        final rawSongs = _storage.loadDownloadedSongs();
        final songsList = rawSongs.map((s) => SongModel.fromJson(s)).toList();
        if (songsList.isEmpty) {
          return "I couldn't find any songs in your offline music library. Please scan for music files first.";
        }
        
        var matches = songsList.where((s) => s.title.toLowerCase() == query).toList();
        if (matches.isEmpty) {
          matches = songsList.where((s) => s.title.toLowerCase().contains(query) || query.contains(s.title.toLowerCase())).toList();
        }
        if (matches.isEmpty) {
          matches = songsList.where((s) => s.artist.toLowerCase().contains(query)).toList();
        }

        if (matches.length == 1) {
          await _binaural.playSong(matches.first);
          if (onNavigate != null) {
            onNavigate("music");
          }
          return "Playing ${matches.first.title} by ${matches.first.artist} now.";
        } else if (matches.length > 1) {
          final titles = matches.map((s) => s.title).take(3).join(", ");
          return "I found multiple matching songs: $titles. Which one would you like to play?";
        }
        
        // Try fuzzy matching
        SongModel? bestMatch;
        double bestScore = 0.0;
        for (final song in songsList) {
          final score = _calculateSimilarity(query, song.title);
          if (score > bestScore) {
            bestScore = score;
            bestMatch = song;
          }
        }
        
        if (bestMatch != null && bestScore >= 0.6) {
          await _binaural.playSong(bestMatch);
          if (onNavigate != null) {
            onNavigate("music");
          }
          return "Playing closest match: ${bestMatch.title} by ${bestMatch.artist}.";
        }
        
        return "Polite Notice: I couldn't find '$query' in your offline music library.";

      default:
        return "Done.";
    }
  }

  static double _calculateSimilarity(String s1, String s2) {
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();
    if (s1 == s2) return 1.0;
    if (s1.contains(s2) || s2.contains(s1)) return 0.8;
    
    final len1 = s1.length;
    final len2 = s2.length;
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));
    
    for (int i = 0; i <= len1; i++) matrix[i][0] = i;
    for (int j = 0; j <= len2; j++) matrix[0][j] = j;
    
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((curr, next) => curr < next ? curr : next);
      }
    }
    
    final distance = matrix[len1][len2];
    final maxLength = max(len1, len2);
    if (maxLength == 0) return 1.0;
    return 1.0 - (distance / maxLength);
  }
}
