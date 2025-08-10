import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MyCameraPlugin {
  static const MethodChannel channel = MethodChannel("my_camera_plugin");

  static Future<Map<dynamic, dynamic>?> startCamera() async {
    try {
      final result = await channel.invokeMethod<Map<dynamic, dynamic>>('startCamera');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Camera error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  static Future<int?> stopCamera() async {
    try {
      final result = await channel.invokeMethod<int>('stopCamera');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Camera error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  static Future<Map<dynamic, dynamic>?> switchCamera() async {
    try {
      final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
        'switchCamera',
      );
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Switch camera error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  static Future<String?> takePhoto() async {
    try {
      final result = await channel.invokeMethod<String>('takePhoto');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Take photo error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }
}
