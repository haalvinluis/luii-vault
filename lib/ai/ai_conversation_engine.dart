import 'dart:math';
import '../audio/binaural_engine.dart';

class AiConversationEngine {
  static String generateReply(String query, List<String> history) {
    final clean = query.toLowerCase().trim();

    // Current playback checks
    if (clean.contains("what song is this") || 
        clean.contains("what song is playing") || 
        clean.contains("current song") ||
        clean.contains("what's currently playing")) {
      final activeSong = BinauralEngine().activeSong;
      if (activeSong != null) {
        return "This is ${activeSong.title} by ${activeSong.artist}.";
      } else {
        return "No song is currently playing right now.";
      }
    }

    if (clean.contains("what's the time") || clean.contains("what time is it") || clean.contains("current time")) {
      final now = DateTime.now();
      final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final minute = now.minute.toString().padLeft(2, '0');
      final period = now.hour >= 12 ? "PM" : "AM";
      return "The current time is $hour:$minute $period.";
    }

    if (clean.contains("what album") || 
        clean.contains("what genre") || 
        clean.contains("which album") || 
        clean.contains("which genre")) {
      final activeSong = BinauralEngine().activeSong;
      if (activeSong != null) {
        return "This song belongs to the album ${activeSong.album} and is categorized under the ${activeSong.playlistName} playlist.";
      } else {
        return "There's no active song playing to check metadata.";
      }
    }

    // Friendly conversational prompts (Jarvis mode)
    if (clean.contains("hello") || clean.contains("hi") || clean.contains("hey")) {
      return "At your service, sir. I'm J.A.R.V.I.S., your assistant. How may I help you today?";
    }
    if (clean.contains("who are you") || clean.contains("your name")) {
      return "I'm J.A.R.V.I.S., your calm and intelligent assistant here in your vault. I help manage your playlists, playback, and notes.";
    }
    if (clean.contains("joke") || clean.contains("funny")) {
      final jokes = [
        "Why don't programmers like nature? Too many bugs in the wild.",
        "How many programmers does it take to change a light bulb? None, that's a hardware issue.",
        "There are 10 types of people in the world: those who understand binary, and those who don't."
      ];
      return jokes[Random().nextInt(jokes.length)];
    }
    if (clean.contains("quantum physics") || clean.contains("quantum mechanics")) {
      return "Quantum physics is the study of matter and energy at its most fundamental level, where things can behave in strange and exciting ways, like existing in multiple states at once.";
    }
    if (clean.contains("code") || clean.contains("coding") || clean.contains("programming")) {
      return "I can definitely talk code with you. What languages are you working with today?";
    }
    if (clean.contains("thank") || clean.contains("thanks")) {
      return "Of course, anytime. Let me know if you need anything else.";
    }

    // Default conversational reply
    return "I get what you're saying, but I don't have access to that information yet. Let me know how else I can help.";
  }
}
