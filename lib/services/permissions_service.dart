import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  /// Request microphone permission
  static Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  /// Check if mic permission already granted
  static Future<bool> hasMicPermission() async {
    final status = await Permission.microphone.status;
    return status == PermissionStatus.granted;
  }
}
