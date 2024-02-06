import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_service/nearby_service.dart';
import 'package:nearby_service_example_full/utils/files_saver.dart';

import 'app_state.dart';

class AppService extends ChangeNotifier {
  late final _nearbyService = NearbyService.getInstance()
    ..communicationChannelState.addListener(notifyListeners);

  AppState state = AppState.idle;
  List<NearbyDevice>? peers;
  NearbyDevice? connectedDevice;
  NearbyDeviceInfo? currentDeviceInfo;
  NearbyConnectionAndroidInfo? _connectionAndroidInfo;

  String platformVersion = 'Unknown';
  String platformModel = 'Unknown';

  StreamSubscription? _peersSubscription;
  StreamSubscription? _connectedDeviceSubscription;
  StreamSubscription? _connectionInfoSubscription;

  @override
  void dispose() {
    stopListeningAll();
    super.dispose();
  }

  Future<void> getPlatformInfo() async {
    platformVersion = await _nearbyService.getPlatformVersion() ?? 'Unknown';
    platformModel = await _nearbyService.getPlatformModel() ?? 'Unknown';
    notifyListeners();
  }

  Future<String> getSavedIOSDeviceName() async {
    return (await _nearbyService.ios?.getSavedDeviceName()) ?? platformModel;
  }

  Future<void> initialize(String? iosDeviceName) async {
    try {
      await _nearbyService.initialize(
        data: NearbyInitializeData(iosDeviceName: iosDeviceName),
      );
      await getCurrentDeviceInfo();
      updateState(
        Platform.isAndroid ? AppState.permissions : AppState.selectClientType,
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> getCurrentDeviceInfo() async {
    try {
      currentDeviceInfo = await _nearbyService.getCurrentDeviceInfo();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> requestPermissions() async {
    try {
      final result = await _nearbyService.android?.requestPermissions();
      if (result ?? false) {
        updateState(AppState.checkServices);
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<bool> checkWifiService() async {
    final result = await _nearbyService.android?.checkWifiService();
    if (result ?? false) {
      updateState(AppState.readyToDiscover);
      startListeningConnectionInfo();
      return true;
    }
    return false;
  }

  Future<void> openServicesSettings() async {
    await _nearbyService.openServicesSettings();
  }

  void setIsBrowser({required bool value}) {
    _nearbyService.ios?.setIsBrowser(value: value);
    updateState(AppState.readyToDiscover);
  }

  Future<void> discover() async {
    try {
      final result = await _nearbyService.discover();
      if (result) {
        updateState(AppState.discoveringPeers);
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> stopDiscovery() async {
    try {
      final result = await _nearbyService.stopDiscovery();
      if (result) {
        updateState(AppState.readyToDiscover);
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> connect(NearbyDevice device) async {
    try {
      await _nearbyService.connect(device);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    notifyListeners();
  }

  Future<void> disconnect([NearbyDevice? device]) async {
    try {
      await _nearbyService.disconnect(device);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    } finally {
      await stopListeningAll();
    }
    notifyListeners();
  }

  Future<void> stopListeningAll() async {
    await endCommunicationChannel();
    await stopListeningConnectedDevice();
    await stopListeningPeers();
    await stopListeningConnectionInfo();
    await stopDiscovery();
  }

  void updateState(AppState state, {bool shouldNotify = true}) {
    this.state = state;
    if (shouldNotify) {
      notifyListeners();
    }
  }

  void _notify() => notifyListeners();
}

extension GettersExtension on AppService {
  CommunicationChannelState get communicationChannelState {
    return _nearbyService.communicationChannelState.value;
  }

  bool get isIOSBrowser {
    return _nearbyService.ios?.isBrowser.value ?? false;
  }

  bool? get isAndroidGroupOwner {
    return _connectionAndroidInfo?.isGroupOwner;
  }
}

extension ConnectionInfoExtension on AppService {
  void startListeningConnectionInfo() {
    try {
      _connectionInfoSubscription =
          _nearbyService.android?.getConnectionInfoStream().listen(
        (event) async {
          _connectionAndroidInfo = event;
          _notify();
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    _notify();
  }

  Future<void> stopListeningConnectionInfo() async {
    await _connectionInfoSubscription?.cancel();
    _connectionInfoSubscription = null;
  }
}

extension PeersExtension on AppService {
  Future<void> startListeningPeers() async {
    try {
      _peersSubscription = _nearbyService.getPeersStream().listen(
        (event) {
          peers = event;
          _notify();
        },
      );
      updateState(AppState.streamingPeers);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> stopListeningPeers() async {
    await _peersSubscription?.cancel();
    peers = null;
    updateState(AppState.discoveringPeers);
  }
}

extension ConnectedDeviceExtension on AppService {
  Future<void> startListeningConnectedDevice(NearbyDevice device) async {
    updateState(AppState.loadingConnection);
    try {
      _connectedDeviceSubscription =
          _nearbyService.getConnectedDeviceStream(device).listen(
        (event) async {
          final wasConnected = connectedDevice?.status.isConnected ?? false;
          final nowConnected = event?.status.isConnected ?? false;
          if (wasConnected && !nowConnected) {
            stopListeningAll();
            return;
          }
          connectedDevice = event;
          if (connectedDevice != null &&
              state != AppState.connected &&
              state != AppState.communicationChannelCreated) {
            updateState(AppState.connected);
          }
          _notify();
        },
      );
    } catch (e) {
      updateState(AppState.streamingPeers, shouldNotify: false);
    }
    _notify();
  }

  Future<void> stopListeningConnectedDevice() async {
    await _connectedDeviceSubscription?.cancel();
    await _nearbyService.endCommunicationChannel();
    _connectedDeviceSubscription = null;
    connectedDevice = null;
    _notify();
  }
}

extension CommunicationChannelExtension on AppService {
  Future<void> startCommunicationChannel({
    ValueChanged<ReceivedNearbyMessage>? listener,
    ValueChanged<ReceivedNearbyFilesPack>? onFilesSaved,
  }) async {
    final messagesListener = NearbyServiceMessagesListener(
      onCreated: () {
        updateState(AppState.communicationChannelCreated);
      },
      onData: (event) {
        listener?.call(event);
      },
      onError: (e, [StackTrace? s]) {
        stopListeningAll();
      },
    );
    final filesListener = NearbyServiceFilesListener(
      onData: (event) async {
        final files = await FilesSaver.savePack(event);
        onFilesSaved?.call(
          ReceivedNearbyFilesPack(sender: event.sender, files: files),
        );
      },
    );

    await _nearbyService.startCommunicationChannel(
      NearbyCommunicationChannelData(
        connectedDevice!.info.id,
        messagesListener: messagesListener,
        filesListener: filesListener,
      ),
    );
  }

  Future<void> endCommunicationChannel() async {
    try {
      await _nearbyService.endCommunicationChannel();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    _notify();
  }
}

extension MessagingExtension on AppService {
  void sendMessage(String message) {
    try {
      if (connectedDevice == null) return;
      _nearbyService.send(
        OutgoingNearbyMessage(
          content: NearbyMessageTextContent(value: message),
          receiver: connectedDevice!.info,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  void sendFilesRequest(List<String> paths) {
    if (connectedDevice == null) return;
    _nearbyService.send(
      OutgoingNearbyMessage(
        content: NearbyMessageFilesRequest.create(
          files: [
            ...paths.map((e) => NearbyFileInfo(path: e)),
          ],
        ),
        receiver: connectedDevice!.info,
      ),
    );
  }

  void sendFilesResponse(String requestId, {required bool response}) {
    if (connectedDevice == null) return;
    _nearbyService.send(
      OutgoingNearbyMessage(
        receiver: connectedDevice!.info,
        content: NearbyMessageFilesResponse(
          id: requestId,
          response: response,
        ),
      ),
    );
  }
}
