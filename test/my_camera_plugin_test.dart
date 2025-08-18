import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:testing_camera_plugin/my_camera_plugin_platform_interface.dart';

class MockMyCameraPluginPlatform
    with MockPlatformInterfaceMixin
    implements MyCameraPluginPlatform {
  
  @override
  Future<Map?> startCamera() {
    throw UnimplementedError();
  }
  
  @override
  Future<int?> stopCamera() {
    throw UnimplementedError();
  }
  
  @override
  Future<Map?> switchCamera() {
    throw UnimplementedError();
  }
  
  @override
  Future<String?> takePhoto() {
    throw UnimplementedError();
  }
}

void main() {
  // final MyCameraPluginPlatform initialPlatform = MyCameraPluginPlatform.instance;

  // test('$MethodChannelMyCameraPlugin is the default instance', () {
  //   expect(initialPlatform, isInstanceOf<MethodChannelMyCameraPlugin>());
  // });

  // test('getPlatformVersion', () async {
  //   MyCameraPlugin myCameraPlugin = MyCameraPlugin();
  //   MockMyCameraPluginPlatform fakePlatform = MockMyCameraPluginPlatform();
  //   MyCameraPluginPlatform.instance = fakePlatform;

  //   expect(await MyCameraPlugin.startCamera(), '42');
  // });
}
