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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
