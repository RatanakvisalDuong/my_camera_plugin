import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'my_camera_plugin_method_channel.dart';

abstract class MyCameraPluginPlatform extends PlatformInterface {
  /// Constructs a MyCameraPluginPlatform.
  MyCameraPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static MyCameraPluginPlatform _instance = MethodChannelMyCameraPlugin();

  /// The default instance of [MyCameraPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelMyCameraPlugin].
  static MyCameraPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MyCameraPluginPlatform] when
  /// they register themselves.
  static set instance(MyCameraPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Abstract methods that must be implemented by platform-specific implementations
  Future<Map<dynamic, dynamic>?> startCamera() {
    throw UnimplementedError('startCamera() has not been implemented.');
  }

  Future<int?> stopCamera() {
    throw UnimplementedError('stopCamera() has not been implemented.');
  }

  Future<Map<dynamic, dynamic>?> switchCamera() {
    throw UnimplementedError('switchCamera() has not been implemented.');
  }

  Future<String?> takePhoto() {
    throw UnimplementedError('takePhoto() has not been implemented.');
  }
}