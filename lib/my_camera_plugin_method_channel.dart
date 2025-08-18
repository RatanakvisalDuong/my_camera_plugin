import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'my_camera_plugin_platform_interface.dart';

/// An implementation of [MyCameraPluginPlatform] that uses method channels.
class MethodChannelMyCameraPlugin extends MyCameraPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('my_camera_plugin');

  @override
  Future<Map<dynamic, dynamic>?> startCamera() async {
    try {
      final result = await channel.invokeMethod<Map<dynamic, dynamic>>('startCamera');
      return result;
    } on PlatformException catch (e) {
      throw e.toString();
    }
  }

  @override
  Future<int?> stopCamera() async {
    try {
      final result = await channel.invokeMethod<int>('stopCamera');
      return result;
    } on PlatformException catch (e) {
      throw e.toString();
    }
  }

  @override
  Future<Map<dynamic, dynamic>?> switchCamera() async {
    try {
      final result = await channel.invokeMethod<Map<dynamic, dynamic>>('switchCamera');
      return result;
    } on PlatformException catch (e) {
      throw e.toString();
    }
  }

  @override
  Future<String?> takePhoto() async {
    try {
      final result = await channel.invokeMethod<String>('takePhoto');
      return result;
    } on PlatformException catch (e) {
      throw e.toString();
    }
  }
}