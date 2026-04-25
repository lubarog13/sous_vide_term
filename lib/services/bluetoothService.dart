import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:convert';

class CustomBluetoothService {
  // Singleton instance
  static final CustomBluetoothService _instance = CustomBluetoothService._internal();
  factory CustomBluetoothService() => _instance;
  CustomBluetoothService._internal();

  // Flutter Blue Plus instance
  final FlutterBluePlus flutterBlue = FlutterBluePlus();
  
  // Connected device
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  
  // Stream controllers for UI updates
  final _connectionStatus = StreamController<bool>.broadcast();
  final _receivedData = StreamController<String>.broadcast();
  
  // Getters
  Stream<bool> get connectionStatus => _connectionStatus.stream;
  Stream<String> get receivedData => _receivedData.stream;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  
  // UUIDs for Bluetooth communication
  final String serviceUUID = "0000ffe0-0000-1000-8000-00805f9b34fb";
  final String txUUID = "0000ffe1-0000-1000-8000-00805f9b34fb"; // Write
  final String rxUUID = "0000ffe1-0000-1000-8000-00805f9b34fb"; // Read/Notify
  
  // Scan for devices
  Stream<List<BluetoothDevice>> scanDevices(int durationSeconds) async* {
    // Start scan
    await FlutterBluePlus.startScan(timeout: Duration(seconds: durationSeconds));
    
    // Listen to scan results
    yield* FlutterBluePlus.scanResults.map(
      (results) => results
          .where((result) => result.device.name.isNotEmpty)
          .map((result) => result.device)
          .toList(),
    );
  }
  
  // Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
  
  // Connect to device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Connect
      await device.connect(license: License.commercial);
      _connectedDevice = device;
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find our service
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID) {
          // Find characteristics
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            String charUUID = characteristic.uuid.toString().toLowerCase();
            
            if (charUUID == txUUID) {
              _txCharacteristic = characteristic;
            }
            if (charUUID == rxUUID) {
              _rxCharacteristic = characteristic;
              // Listen to notifications
              await characteristic.setNotifyValue(true);
              characteristic.value.listen((value) {
                if (value.isNotEmpty) {
                  String data = utf8.decode(value);
                  _receivedData.add(data.trim());
                }
              });
            }
          }
        }
      }
      
      if (_txCharacteristic == null || _rxCharacteristic == null) {
        throw Exception("Required characteristics not found");
      }
      
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
    if (_txCharacteristic == null || _connectedDevice == null) {
      throw Exception("Not connected to any device");
    }
    
    // Add newline character as Arduino code expects it
    String cmdWithNewline = "$command\n";
    await _txCharacteristic!.write(utf8.encode(cmdWithNewline));
  }
  
  // Disconnect
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    _connectedDevice = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _connectionStatus.add(false);
  }
  
  // Check if Bluetooth is available
  Future<bool> isBluetoothAvailable() async {
    return await FlutterBluePlus.isAvailable;
  }
  
  // Cleanup
  void dispose() {
    _connectionStatus.close();
    _receivedData.close();
  }
}