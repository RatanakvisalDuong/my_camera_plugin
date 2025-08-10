import 'package:flutter_test/flutter_test.dart';
import 'package:my_camera_plugin/my_camera_plugin.dart';
import 'package:my_camera_plugin/my_camera_plugin_platform_interface.dart';
import 'package:my_camera_plugin/my_camera_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMyCameraPluginPlatform
    with MockPlatformInterfaceMixin
    implements MyCameraPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MyCameraPluginPlatform initialPlatform = MyCameraPluginPlatform.instance;

  test('$MethodChannelMyCameraPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMyCameraPlugin>());
  });

  test('getPlatformVersion', () async {
    MyCameraPlugin myCameraPlugin = MyCameraPlugin();
    MockMyCameraPluginPlatform fakePlatform = MockMyCameraPluginPlatform();
    MyCameraPluginPlatform.instance = fakePlatform;

    // expect(await myCameraPlugin.getPlatformVersion(), '42');
  });
}
