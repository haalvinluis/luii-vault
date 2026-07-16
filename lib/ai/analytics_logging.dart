import 'package:flutter/foundation.dart';

class AnalyticsLogging {
  static void log(String category, String message, {Object? error}) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint("[$timestamp] [$category] $message");
    if (error != null) {
      debugPrint("Error details: $error");
    }
  }
}
