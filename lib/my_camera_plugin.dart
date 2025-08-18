import 'package:testing_camera_plugin/my_camera_plugin_platform_interface.dart';

class MyCameraPlugin {
  static MyCameraPluginPlatform get _platform =>
      MyCameraPluginPlatform.instance;

  static Future<Map<dynamic, dynamic>?> startCamera() {
    return _platform.startCamera();
  }

  static Future<int?> stopCamera() async {
    return await _platform.stopCamera();
  }

  static Future<Map<dynamic, dynamic>?> switchCamera() async {
    return await _platform.switchCamera();
  }

  static Future<String?> takePhoto() async {
    return await _platform.takePhoto();
  }
}
