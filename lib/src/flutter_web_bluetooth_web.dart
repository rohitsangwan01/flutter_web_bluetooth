library flutter_web_bluetooth;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_bluetooth/js_web_bluetooth.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:rxdart/rxdart.dart';

part 'bluetooth_device.dart';

part 'errors/BluetoothAdapterNotAvailable.dart';

part 'flutter_web_bluetooth_interface.dart';

part 'request_options_builder.dart';

class FlutterWebBluetooth extends FlutterWebBluetoothInterface {
  FlutterWebBluetooth._();

  static FlutterWebBluetooth? _instance;

  static FlutterWebBluetoothInterface get instance {
    _instance ??= FlutterWebBluetooth._();
    return _instance!;
  }

  final Set<WebBluetoothDevice> _knownDevices = Set();
  final BehaviorSubject<Set<WebBluetoothDevice>> _knownDevicesStream =
      BehaviorSubject.seeded(Set());
  bool _checkedDevices = false;

  void _addKnownDevice(WebBluetoothDevice device) {
    _knownDevices.add(device);
    _knownDevicesStream.add(_knownDevices);
  }

  ///
  /// Get if the bluetooth api is available in this browser. This will only
  /// check if the api is in the `navigator`. Not if anything is available.
  /// This will sometimes return false if the website is not loaded in a
  /// [secure context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts).
  ///
  @override
  bool get isBluetoothApiSupported => Bluetooth.isBluetoothAPISupported();

  ///
  /// Get a [Stream] for the availability of a Bluetooth adapter.
  /// If a user inserts or removes a bluetooth adapter from their devices this
  /// stream will update.
  /// It will not necicerly update if the user enables/ disables a bleutooth
  /// adapter.
  ///
  /// Will return `Stream.value(false)` if [isBluetoothApiSupported] is false.
  ///
  @override
  Stream<bool> get isAvailable {
    return Bluetooth.onAvailabilitychanged();
  }

  @override
  Stream<Set<WebBluetoothDevice>> get devices {
    if (!_checkedDevices) {
      _getKnownDevices();
    }
    return _knownDevicesStream.stream;
  }

  ///
  /// Get the already known devices from the browser
  ///
  Future<void> _getKnownDevices({bool shouldCheck = true}) async {
    _checkedDevices = true;
    if (shouldCheck && !(await Bluetooth.getAvailability())) {
      if (!kReleaseMode) {
        debugPrint('flutter_web_bluetooth: could not get known devices because '
            'it\'s not available in this browser/ for this devices.');
      }
      _knownDevices.clear();
      _knownDevicesStream.add(_knownDevices);
      return;
    }
    final devices = await Bluetooth.getDevices();
    final devicesSet =
        Set<WebBluetoothDevice>.from(devices.map((e) => WebBluetoothDevice(e)));
    this._knownDevices.addAll(devicesSet);
    this._knownDevicesStream.add(this._knownDevices);
  }

  ///
  /// Request a [WebBluetoothDevice] from the browser (user). This will resolve
  /// into a single device even if the filter [options] (and enviornment) have
  /// multiple devices that fit that could be found.
  ///
  /// If you want multiple devices you will need to call this method multiple
  /// times, the user however can still click the already connected device twice.
  ///
  /// May throw [NativeAPINotImplementedError] if the native api is not
  /// implemented for this user agent (browser).
  /// May throw [BluetoothAdapterNotAvailable] if there is not bluetooth device
  /// available.
  /// May throw [UserCancelledDialogError] if the user cancels the pairing dialog.
  /// May throw [DeviceNotFoundError] if the device could not be found with the
  /// current request filters.
  ///
  Future<WebBluetoothDevice> requestDevice(
      RequestOptionsBuilder options) async {
    if (!this.isBluetoothApiSupported) {
      throw NativeAPINotImplementedError('requestDevice');
    }
    if (!(await Bluetooth.getAvailability())) {
      throw BluetoothAdapterNotAvailable('requestDevice');
    }
    final device = await Bluetooth.requestDevice(options.toRequestOptions());
    final webDevice = WebBluetoothDevice(device);
    _addKnownDevice(webDevice);
    return webDevice;
  }

  static void registerWith(Registrar registrar) {
    // Do nothing
  }
}
