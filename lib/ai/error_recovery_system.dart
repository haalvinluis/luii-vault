import 'analytics_logging.dart';

class ErrorRecoverySystem {
  static T runSafe<T>(T Function() operation, T fallback) {
    try {
      return operation();
    } catch (e) {
      AnalyticsLogging.log("ErrorRecovery", "Recovered from operation failure", error: e);
      return fallback;
    }
  }

  static Future<T> runSafeAsync<T>(Future<T> Function() operation, T fallback) async {
    try {
      return await operation();
    } catch (e) {
      AnalyticsLogging.log("ErrorRecovery", "Recovered from async operation failure", error: e);
      return fallback;
    }
  }
}
