import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

class CustomBluetoothService {
  // Singleton instance
  static final CustomBluetoothService _instance = CustomBluetoothService._internal();
  factory CustomBluetoothService() => _instance;
  CustomBluetoothService._internal();

  // Connected device
  BluetoothDevice? _connectedDevice;
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;
  
  // Stream controllers for UI updates
  final _connectionStatus = StreamController<bool>.broadcast();
  final _receivedData = StreamController<String>.broadcast();
  
  // Getters
  Stream<bool> get connectionStatus => _connectionStatus.stream;
  Stream<String> get receivedData => _receivedData.stream;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  
  // Scan classic Bluetooth devices (paired and discoverable unpaired)
  Stream<List<BluetoothDevice>> scanDevices(int durationSeconds) async* {
    final devicesByAddress = <String, BluetoothDevice>{};

    print("Loading bonded classic Bluetooth devices");
    final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    for (final device in bondedDevices) {
      devicesByAddress[device.address] = device;
    }
    yield devicesByAddress.values.toList();

    print("Discovering unpaired classic Bluetooth devices");
    final discovery = FlutterBluetoothSerial.instance.startDiscovery().timeout(
      Duration(seconds: durationSeconds),
      onTimeout: (sink) => sink.close(),
    );

    await for (final result in discovery) {
      devicesByAddress[result.device.address] = result.device;
      yield devicesByAddress.values.toList();
    }
  }
  
  // Stop scanning
  Future<void> stopScan() async {
    // No active scan stream in classic mode.
  }
  
  // Connect to device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      final bluetoothState = await FlutterBluetoothSerial.instance.state;
      if (bluetoothState != BluetoothState.STATE_ON) {
        throw Exception("Bluetooth is turned off");
      }

      final isDiscovering = await FlutterBluetoothSerial.instance.isDiscovering;
      if (isDiscovering ?? false) {
        await FlutterBluetoothSerial.instance.cancelDiscovery();
      }

      _connectedDevice = device;
      print(device.address);
      print(device.name);
      if (!device.isBonded) {
        final bondResult = await FlutterBluetoothSerial.instance
            .bondDeviceAtAddress(device.address);
        if (bondResult != true) {
          throw Exception("Pairing failed for ${device.name ?? device.address}");
        }
      }
      print("Bonded device: ${device.address}");
      _connection = await BluetoothConnection.toAddress(device.address);
      _inputSubscription?.cancel();
      _inputSubscription = _connection!.input?.listen((bytes) {
        print("Bytes:"+bytes.toString());
        if (bytes.isNotEmpty) {
          final data = utf8.decode(bytes, allowMalformed: true).trim();
          if (data.isNotEmpty) {
            _receivedData.add(data);
          }
        }
      }, onDone: () async {
        await disconnect();
      });

      _connectionStatus.add(true);
      return true;
    } catch (e) {
      print("Connection error: $e");
      await disconnect();
      return false;
    }
  }
  
  // Send command to Arduino
  Future<void> sendCommand(String command) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception("Not connected to any device");
    }

    final cmdWithNewline = "$command\n";
    _connection!.output.add(Uint8List.fromList(utf8.encode(cmdWithNewline)));
    await _connection!.output.allSent;
  }
  
  // Disconnect
  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    await _connection?.close();
    _connection = null;
    _connectedDevice = null;
    _connectionStatus.add(false);
  }
  
  // Check if Bluetooth is available
  Future<bool> isBluetoothAvailable() async {
    final state = await FlutterBluetoothSerial.instance.state;
    return state == BluetoothState.STATE_ON;
  }
  
  // Cleanup
  void dispose() {
    disconnect();
    _connectionStatus.close();
    _receivedData.close();
  }
}