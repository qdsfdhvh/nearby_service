import 'package:nearby_service/nearby_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nearby_service_method_channel.dart';

abstract class NearbyServicePlatform extends PlatformInterface {
  NearbyServicePlatform() : super(token: _token);

  static final Object _token = Object();

  static NearbyServicePlatform _instance = MethodChannelNearbyService();

  /// The default instance of [NearbyServicePlatform] to use.
  ///
  /// Defaults to [MethodChannelNearbyService].
  static NearbyServicePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NearbyServicePlatform] when
  /// they register themselves.
  static set instance(NearbyServicePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> getPlatformModel() {
    throw UnimplementedError('getPlatformModel() has not been implemented.');
  }

  Future<NearbyDeviceInfo?> getCurrentDeviceInfo() {
    throw UnimplementedError('getCurrentDevice() has not been implemented.');
  }

  Future<void> openServicesSettings() {
    throw UnimplementedError(
        'openServicesSettings() has not been implemented.');
  }

  Future<List<NearbyDeviceBase>> getPeers() {
    throw UnimplementedError('getPeers() has not been implemented.');
  }

  Stream<List<NearbyDeviceBase>> getPeersStream() {
    throw UnimplementedError('streamPeers() has not been implemented.');
  }

  Stream<NearbyDeviceBase?> getConnectedDeviceStream(NearbyDeviceBase device) {
    throw UnimplementedError(
        'getConnectedDeviceStream() has not been implemented.');
  }

  Future<bool> disconnect(NearbyDeviceBase device) {
    throw UnimplementedError('disconnect() has not been implemented.');
  }
}
