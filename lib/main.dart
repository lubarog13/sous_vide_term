import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/flutter_picker_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import 'database.dart';
import 'programModel.dart';
import 'buttomNavigation.dart';
import 'utils/utils.dart';
import 'services/bluetoothService.dart';
import 'utils/colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
  
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<int> programListSelectionNotifier = ValueNotifier(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
  themeModeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Умный градусник',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: const MainShell(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    this.isActive = false,
  });

  final String title;
  final bool isActive;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _targetTemperature = 50.0;
  double _currentTemperature = 0;
  double _temperatureOffset = 0.5;
  bool _firstInit = true;
  bool _setFromList = false;
  Program? _program;
  int _hours = 0;
  int _minutes = 30;
  int _seconds = 0;
  int _initialHours = 0;
  int _initialMinutes = 30;
  DateTime _endTime = DateTime.now().copyWith(second: 0).add(
    Duration(
      hours: 0,
      minutes: 30,
    ),
  );
  bool _shakerEnabled = false;
  TimerCountdown? _timer;
  Text? _timerPlaceholder;
  bool _timerRunning = false;
  SharedPreferences? _prefs;
  TextEditingController _textFieldController = TextEditingController();
  BluetoothDevice? _connectedDevice;
  bool _needSync = false;
  bool _canSync = false;
  bool _isFahrenheit = false;
  String _deviceName = "";
  int _progress = 0;


final CustomBluetoothService _bluetoothService = CustomBluetoothService();
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isConnected = false;
  bool _scanSuccess = false;
  String _statusMessage = "Выберите устройство";
  @override
  void initState() {
    super.initState();
    _isConnected = _bluetoothService.isConnected;
    programListSelectionNotifier.addListener(_onProgramListSelection);
    _setupBluetoothListeners();
    _initPrefs();
    createTimerPlaceholder();
  }

  @override
  void didUpdateWidget(MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _onPageVisible();
    }
  }

  Future<void> _onPageVisible() async {
    await _reloadDisplayPrefs();
  }

  Future<void> _reloadDisplayPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    final isFahrenheit = _prefs?.getBool('is_fahrenheit') ?? false;
    final deviceName = _prefs?.getString('device_name') ?? dotenv.get('DEVICE_NAME');
    if (!mounted) return;
    setState(() {
      _isFahrenheit = isFahrenheit;
      _deviceName = deviceName;
    });
  }

  @override
  void dispose() {
    programListSelectionNotifier.removeListener(_onProgramListSelection);
    saveState();
    super.dispose();
  }

  Future<void> _onProgramListSelection() async {
    await applyProgramFromList();
  }

  Future<void> applyProgramFromList() async {
    _prefs ??= await SharedPreferences.getInstance();
    _setFromList = _prefs?.getBool('set_from_list') ?? false;
    if (!_setFromList) return;
    _prefs?.remove('set_from_list');

    final selectedProgram = _prefs?.getInt('selected_program');
    if (selectedProgram != null && selectedProgram != 0) {
      _program = await DBProvider.db.getProgram(selectedProgram);
    }
    _hours = _prefs?.getInt('current_hours') ?? _program?.hours ?? 20;
    _minutes = _prefs?.getInt('current_minutes') ?? _program?.minutes ?? 30;
    _seconds = 0;
    _initialHours = _hours;
    _initialMinutes = _minutes;
    _endTime = DateTime.now().copyWith(second: 0).add(
      Duration(hours: _hours, minutes: _minutes),
    );
    _targetTemperature = _prefs?.getDouble('current_temperature') ?? _program?.temperature ?? 50.0;
    _temperatureOffset = _prefs?.getDouble('current_temperature_offset') ?? _program?.temperatureOffset ?? 0.5;
    _shakerEnabled = _prefs?.getBool('current_shaker_enabled') ?? _program?.shakerEnabled ?? false;
    if (!mounted) return;
    setState(() {});
    if (_isConnected) {
      _startTimer();
    }
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    int? selectedProgram = _prefs?.getInt('selected_program') ;
    _setFromList = _prefs?.getBool('set_from_list') ?? false;
    if (_setFromList) {
      _prefs?.remove('set_from_list');
    }
    _isFahrenheit = _prefs?.getBool('is_fahrenheit') ?? false;
    _deviceName = _prefs?.getString('device_name') ?? dotenv.get('DEVICE_NAME');
    if (selectedProgram != null && selectedProgram != 0) {
      Program program = await DBProvider.db.getProgram(selectedProgram);
      _program = program;
      if (!(_prefs?.containsKey('current_hours') ?? false)) {
      _initialHours = program.hours;
      _initialMinutes = program.minutes;
      _hours = _initialHours;
      _minutes = _initialMinutes;
      _seconds = 0;
      _endTime = DateTime.now().copyWith(second: 0).add(
        Duration(
          hours: _hours,
          minutes: _minutes,
        ),
      );
      _targetTemperature = program.temperature;
      _temperatureOffset = program.temperatureOffset;
      _shakerEnabled = program.shakerEnabled;
      }  else {
          _hours = _prefs?.getInt('current_hours') ?? 20;
          _minutes = _prefs?.getInt('current_minutes') ?? 30;
          _seconds = _prefs?.getInt('current_seconds') ?? 0;
          _initialHours = _hours;
          _initialMinutes = _minutes;
          _endTime = DateTime.now().copyWith(second: 0).add(
            Duration(
              hours: _hours,
              minutes: _minutes,
            ),
          );
          _targetTemperature = _prefs?.getDouble('current_temperature') ?? 50.0;
          _temperatureOffset = _prefs?.getDouble('current_temperature_offset') ?? 0.5;
          _shakerEnabled = _prefs?.getBool('current_shaker_enabled') ?? false;
        }
      } else {
        List<Program> programs = await DBProvider.db.getPrograms();
        if (programs.isNotEmpty) {
          _program = programs[0];
                if (!(_prefs?.containsKey('current_hours') ?? false)) {

          _initialHours = _program?.hours ?? 20;
          _initialMinutes = _program?.minutes ?? 30;
          _hours = _initialHours;
          _minutes = _initialMinutes;
          _endTime = DateTime.now().copyWith(second: 0).add(
            Duration(
              hours: _hours,
              minutes: _minutes,
            ),
          );
          _targetTemperature = _program?.temperature ?? 50.0;
          _temperatureOffset = _program?.temperatureOffset ?? 0.5;
          _shakerEnabled = _program?.shakerEnabled ?? false;
                } else {
                  _hours = _prefs?.getInt('current_hours') ?? 20;
                  _minutes = _prefs?.getInt('current_minutes') ?? 30;
                  _seconds = _prefs?.getInt('current_seconds') ?? 0;
                  _initialHours = _hours;
                  _initialMinutes = _minutes;
                  _endTime = DateTime.now().copyWith(second: 0).add(
                    Duration(
                      hours: _hours,
                      minutes: _minutes,
                    ),
                  );
                  _targetTemperature = _prefs?.getDouble('current_temperature') ?? 50.0;
                  _temperatureOffset = _prefs?.getDouble('current_temperature_offset') ?? 0.5;
                  _shakerEnabled = _prefs?.getBool('current_shaker_enabled') ?? false;
                }
              }
    }
    final deviceJson = _prefs?.getString('device');
    if (deviceJson != null) {
      try {
        _connectedDevice = BluetoothDevice.fromMap(
          Map<String, dynamic>.from(jsonDecode(deviceJson) as Map),
        );
      } catch (_) {
        _connectedDevice = null;
      }
    }
    if (_connectedDevice != null) {
      _connectToDevice(_connectedDevice!);
    }
  }

  void _setupBluetoothListeners() {
    // Listen to connection status
    _bluetoothService.connectionStatus.listen((isConnected) {
      setState(() {
        _isConnected = isConnected;
        _scanSuccess = _isConnected;
        _statusMessage = isConnected ? "Подключено к устройству" : "Не подключено к устройству";
      });
    });
    
    // Listen to received data
    _bluetoothService.receivedData.listen((data) {
      setState(() {
        _parseReceivedMessage(data);
      });
    });
  }

  Future<void> _requestPermissions() async {
    // Request location permission for Android
    if (Theme.of(context).platform == TargetPlatform.android) {
      await Permission.locationWhenInUse.request();
      if (!await Permission.locationWhenInUse.isGranted) {
        setState(() {
          _statusMessage = "Необходимо разрешить доступ к местоположению";
        });
        return;
      }
    }
    
    // Request Bluetooth permissions
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    if (!await Permission.bluetooth.isGranted) {
      setState(() {
        _statusMessage = "Необходимо разрешить Bluetooth";
      });
      return;
    }
    if (!await Permission.bluetoothConnect.isGranted) {
      setState(() {
        _statusMessage = "Необходимо разрешить Bluetooth Connect";
      });
      return;
    }
    if (!await Permission.bluetoothScan.isGranted) {
      setState(() {
        _statusMessage = "Необходимо разрешить Bluetooth Scan";
      });
      return;
    }
  }

  Future<void> _scanDevices() async {
    const int scanDurationSeconds = 5;
    // Request permissions first
    await _requestPermissions();
    
    setState(() {
      _isScanning = true;
      _devices.clear();
      _statusMessage = "Сканирование устройств...";
    });
    
    try {
      print("Scanning devices");
      final subscription = _bluetoothService
          .scanDevices(scanDurationSeconds, _deviceName)
          .listen((devices) {
        setState(() {
          _devices = devices;
          print("Devices: ${_devices.map((result) => result.name ?? result.address).toList()}");
        });
      });

      await Future.delayed(const Duration(seconds: scanDurationSeconds));
      await subscription.cancel();
      await _bluetoothService.stopScan();

      print("Devices: ${_devices.length}");
      setState(() {
        _isScanning = false;
        if (_devices.isEmpty) {
          _statusMessage = "Не найдено устройств. Убедитесь, что устройство включено.";
          _scanSuccess = false;
        } else {
          _statusMessage = "Найдено ${_devices.length} устройств";
          _scanSuccess = true;
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanSuccess = false;
        _statusMessage = "Ошибка: $e";
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _statusMessage = "Подключение к ${device.name ?? device.address}...";
    });
    
    bool success = await _bluetoothService.connectToDevice(device);
    
    if (success) {
      setState(() {
        _statusMessage = "Подключено к ${device.name ?? device.address}";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Подключено к ${device.name ?? device.address}"),
          backgroundColor: Colors.green,
        ),
      );
      await _prefs?.setString('device', jsonEncode(device.toMap()));
      _connectedDevice = device;
      if (_setFromList) {
        _startTimer();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Не удалось подключиться к ${device.name ?? device.address}"),
          backgroundColor: Colors.red,
        ),
      );
      _connectedDevice = null;
      _stopTimer();
      await _prefs?.remove('device');
    }
  }
  
  Future<void> _sendCommand(String command) async {
    if (!_isConnected) {
      return;
    }
    try {
      await _bluetoothService.sendCommand(command);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ошибка: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void showDevicePicker(BuildContext context) {
    Picker(
      adapter: PickerDataAdapter<String>(
        pickerData: _devices.map((device) => device.name ?? device.address).toList(),
      ),
      confirmText: 'Подключить',
      cancelText: 'Отмена',
      confirmTextStyle: TextStyle(fontSize: 20, color: Colors.blue),
      title: const Text('Выберите устройство'),
      onConfirm: (Picker picker, List<int> value) {
        _connectToDevice(_devices[value[0]]);
      },
    ).showModal(context);
  }

  void _parseReceivedMessage(String msg) {
              List<String> messages = msg.split('\n');
      bool _validMessage = false;
      bool _canSetData = false;
      // print(msg);
      // print(messages.length);
      try {
      messages.forEach((message) {
        if (message.startsWith('Tr:') && (!_setFromList && (_firstInit || _timerRunning || _canSync))) {
          _timerRunning = message.substring(3, 4) == '1' ? true : false; 
           _validMessage = true;
          if (_timerRunning && _firstInit) {
            _canSetData = true;
          }
        } else if (message.startsWith('Tr:') && !_setFromList && (message.substring(3, 4) == '1' && !_timerRunning))  {
          _needSync = true;
        }
      else if (message.startsWith('Ct:')) {
        _currentTemperature = double.parse(message.substring(3));
        _validMessage = true;
      } else if (message.startsWith('O:') && (_canSetData || _timerRunning || _canSync)) {
        _temperatureOffset = double.parse(message.substring(2));
        _validMessage = true;
      } 
      else if (message.startsWith('O:') && double.parse(message.substring(2)) != _temperatureOffset) {
        _needSync = true;
      }
      else if (message.startsWith('Tt:') && (_canSetData || _timerRunning || _canSync)) {
        print(_progress);
        print(_initialMinutes);
        print(_minutes);
          print('Target temperature: ${message.substring(3)} ${double.parse(message.substring(3))} != ${_targetTemperature}');
        _targetTemperature = double.parse(message.substring(3));
        _validMessage = true;
        _needSync = false;
      } 
      else if (message.startsWith('Tt:') && double.parse(message.substring(3)) != _targetTemperature) {
        print('Target temperature changed: ${message.substring(3)} ${double.parse(message.substring(3))} != ${_targetTemperature}');
        _needSync = true;
      }
      else if (message.startsWith('M:') && (_canSetData || _timerRunning || _canSync)) {
        int minutes = int.parse(message.substring(2));
        print(minutes);
        if (minutes > 0 && minutes!= _hours * 60 + _minutes) {
          _hours = minutes ~/ 60;
          _minutes = minutes % 60;
          _endTime = DateTime.now().copyWith(second: 0).add(
            Duration(
              hours: _hours,
              minutes: _minutes,
            ),
          );
          int tempProgress =  (((_initialHours - _hours) * 60 * 60 + (_initialMinutes - _minutes) * 60) / (_initialHours * 60 * 60 + _initialMinutes * 60 ) * 100).toInt();
          print("${tempProgress} ${_progress}");
          if ((tempProgress - _progress).abs() > 1) {
            _progress = tempProgress;
            print(_progress);
          }
          if (_timerRunning) {
            _timer = null;
            createTimer();
          } else {
            _initialHours = _hours;
            _initialMinutes = _minutes;
            createTimerPlaceholder();
          }
          _validMessage = true;
        }
        _needSync = false;
      }
        else if (message.startsWith('M:') && int.parse(message.substring(2))!=(_hours*60+_minutes)) {
          _needSync = true;
        }
      else if (message.startsWith('S:') && (_canSetData || _timerRunning || _canSync)) {
          _shakerEnabled = message.substring(2) == '1' ? true : false;
          _validMessage = true;
          _needSync = false;
        }
      });
      // if ((_canSetData && _canSync) && (_program?.temperature != _targetTemperature || _program?.temperatureOffset != _temperatureOffset || _program?.shakerEnabled != _shakerEnabled)) {
      //                 _program = Program(id: null, name: 'Не выбрана', hours: _hours, minutes: _minutes, temperature: _targetTemperature, temperatureOffset: _temperatureOffset, shakerEnabled: _shakerEnabled);
      //   }
      } catch (e) {
        print(msg);
        print(e);
      }
      if (_validMessage && messages.length > 1) {
        _firstInit = false;
        _setFromList = false;
        _canSync = false;
      }
  }
  void _startTimer() {
    setState(() {
      _timerRunning = true;
      _sendCommand('Tt:${_targetTemperature}\nO:${_temperatureOffset}\nS:${_shakerEnabled ? 1 : 0}\nM:${_hours * 60 + _minutes}\nSTART');
      createTimer();
    });
  }

  void _stopTimer() {
    setState(() {
      _timerRunning = false;
      _sendCommand('STOP');
      createTimerPlaceholder();
      _timer = null;
    });
  }

  void _resetTimer() {
    setState(() {
      _timerRunning = false;
      _sendCommand('STOP');
      _hours = _initialHours;
      _minutes = _initialMinutes;
      _seconds = 0;
      _endTime = DateTime.now().copyWith(second: 0).add(
        Duration(
          hours: _hours,
          minutes: _minutes,
        ),
      );
      _sendCommand('Tt:${_targetTemperature}\nO:${_temperatureOffset}\nS:${_shakerEnabled ? 1 : 0}\nM:${_hours * 60 + _minutes}');
      createTimerPlaceholder();
      _timer = null;
    });
  }

  void createTimer() {
    _timer = TimerCountdown(
      format: CountDownTimerFormat.hoursMinutes,
      endTime: _endTime.copyWith(second: 0),
      enableDescriptions: false,
      timeTextStyle: TextStyle(fontSize: 50),
      colonsTextStyle: TextStyle(fontSize: 50),
      onEnd: () {
        setState(() {
          _resetTimer();
        });
      },
      onTick: (duration) {
        setState(() {
          _hours = duration.inHours;
          _minutes = duration.inMinutes % 60 + 1;
          print(_progress);
          _progress =  (((_initialHours - _hours) * 60 * 60 + (_initialMinutes - _minutes) * 60) / (_initialHours * 60 * 60 + _initialMinutes * 60 ) * 100).toInt();
          print('Duration: ${duration.inHours} ${duration.inMinutes % 60}');
        });
      },
    );
  }

  void createTimerPlaceholder() {
    print('createTimerPlaceholder: ${_hours} ${_minutes}');
    _progress = (((_initialHours - _hours) * 60 * 60 + (_initialMinutes - _minutes) * 60) / (_initialHours * 60 * 60 + _initialMinutes * 60 ) * 100).toInt();
    _timerPlaceholder = Text('${_hours.toString().padLeft(2, '0')} : ${_minutes.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 50));
  }


  void showTemperaturePicker(BuildContext context) {
    int initTemperature = _targetTemperature.toInt();
    int initTemperatureFloatPart = ((_targetTemperature - initTemperature.toDouble()) * 10).toInt();
    Picker(
      adapter: NumberPickerAdapter(data: [
        NumberPickerColumn(begin: 0, end: 100, initValue: initTemperature),
        NumberPickerColumn(begin: 0, end: 10, initValue: initTemperatureFloatPart),
      ]),
      delimiter: [
      PickerDelimiter(
        child: Container(
          width: 30.0,
          alignment: Alignment.center,
          child: const Text('.', style: TextStyle(fontSize: 40)),
        ),
        column: 1,
      ),
    ],
    confirmText: 'Установить',
    cancelText: 'Отмена',
    looping: true,
    confirmTextStyle: TextStyle(fontSize: 20, color: Colors.blue),
    
      title: const Text('Выберите температуру'),
      onConfirm: (Picker picker, List<int> value) {
        setState(() {
          _targetTemperature = value[0] + value[1] / 10;
          print('Tt:${_targetTemperature}');
          _sendCommand('Tt:${_targetTemperature}');
        });
      },
    ).showModal(context);
  }

  void showTemperatureOffsetPicker(BuildContext context) {
    int initTemperatureOffset = _temperatureOffset.toInt();
    int initTemperatureOffsetFloatPart = ((_temperatureOffset - initTemperatureOffset.toDouble()) * 10).toInt();
    Picker(
      adapter: NumberPickerAdapter(data: [
        NumberPickerColumn(begin: 0, end: 99, initValue: initTemperatureOffset),
        NumberPickerColumn(begin: 0, end: 10, initValue: initTemperatureOffsetFloatPart),
      ]),
      delimiter: [
      PickerDelimiter(
        child: Container(
          width: 30.0,
          alignment: Alignment.center,
          child: const Text('.', style: TextStyle(fontSize: 40)),
        ),
        column: 1,
      ),
    ],
    confirmText: 'Установить',
    cancelText: 'Отмена',
    looping: true,
    confirmTextStyle: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary),
    
      title: const Text('Выберите погрешность температуры'),
      onConfirm: (Picker picker, List<int> value) {
        setState(() {
          _temperatureOffset = value[0] + value[1] / 10;
          _sendCommand('O:${_temperatureOffset}');
        });
      },
    ).showModal(context);
  }

  void showTimePicker(BuildContext context) {
    Picker(
      adapter: NumberPickerAdapter(data: [
        NumberPickerColumn(begin: 0, end: 24, initValue: _hours),
        NumberPickerColumn(begin: 0, end: 59, initValue: _minutes),
      ]),
      delimiter: [
      PickerDelimiter(
        child: Container(
          width: 30.0,
          alignment: Alignment.center,
          child: const Text(':', style: TextStyle(fontSize: 40)),
        ),
        column: 1,
      ),
    ],
    confirmText: 'Установить',
    cancelText: 'Отмена',
    looping: true,
    confirmTextStyle: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary),
    
      title: const Text('Выберите время'),
      onConfirm: (Picker picker, List<int> value) {
        setState(() {
          _timerRunning = false;
          _sendCommand('STOP');
          _hours = value[0];
          _minutes = value[1];
          _seconds = 0;
          _initialHours = _hours;
          _initialMinutes = _minutes;
          _seconds = 0;
          _endTime = DateTime.now().copyWith(second: 0).add(
            Duration(
              hours: _hours,
              minutes: _minutes,
            ),
          );
          _timer = null;
          createTimerPlaceholder();
        });
      },
    ).showModal(context);
  }

  Future<void> showProgramsPicker(BuildContext context) async {
    List<Program> programs = await DBProvider.db.getPrograms();
    programs.insert(0, Program(id: null, name: 'Не выбрана', hours: _initialHours, minutes: _initialMinutes, temperature: _targetTemperature, temperatureOffset: _temperatureOffset, shakerEnabled: _shakerEnabled));
    if (_program != null && _program?.id != null) {
      int index = programs.indexWhere((prog) => prog.id == _program!.id);
      if (index >= 0) {
        Program current = programs.removeAt(index);
        programs.insert(0, current);
      }
    }
    Picker(
      adapter:  PickerDataAdapter<String>(
      pickerData: programs.map((program) => program.name + ' [${program.id}]').toList(),
    ),
    confirmText: 'Установить',
    cancelText: 'Отмена',
    confirmTextStyle: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary),
    
      title: const Text('Выберите программу'),
      onConfirm: (Picker picker, List<int> value) {
        setState(() {
          _program = programs[value[0]];
          _initialHours = programs[value[0]].hours;
          _initialMinutes = programs[value[0]].minutes;
          _hours = _initialHours;
          _minutes = _initialMinutes;
          _seconds = 0;
          _endTime = DateTime.now().copyWith(second: 0).add(
            Duration(
              hours: _hours,
              minutes: _minutes,
            ),
          );
          _targetTemperature = programs[value[0]].temperature;
          _temperatureOffset = programs[value[0]].temperatureOffset;
          _shakerEnabled = programs[value[0]].shakerEnabled;
          _stopTimer();
          createTimerPlaceholder();
        });
      },
    ).showModal(context);
  }

  Future<void> _displayTextInputDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Введите название программы'),
          content: TextField(
            controller: _textFieldController,
            decoration: InputDecoration(hintText: "Название программы"),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text('Отмена'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: Text('Сохранить'),
              onPressed: () async {
                String programName = _textFieldController.text;
                Program program = Program(id:null, name: programName, hours: _initialHours, minutes: _initialMinutes, temperature: _targetTemperature, temperatureOffset: _temperatureOffset, shakerEnabled: _shakerEnabled);
                print(program.toJson());
                int id = await DBProvider.db.insertProgram(program);
                program.id = id;
                
                print(program.toJson());
                await _prefs?.setInt('selected_program', program.id ?? 0);
                setState(() {
                  _program = program;

                });
                print(_program?.toJson());
                Navigator.pop(context);
              },
            ),
            if (_program?.id != null) ...[
              ElevatedButton(
              child: Text('Обновить'),
              onPressed: () async {
                String programName = _textFieldController.text;
                Program program = Program(id: _program?.id, name: programName.isEmpty ? _program?.name ?? '' : programName, hours: _initialHours, minutes: _initialMinutes, temperature: _targetTemperature, temperatureOffset: _temperatureOffset, shakerEnabled: _shakerEnabled);
                await DBProvider.db.updateProgram(program);
                setState(() {
                  _program = program;
                });
                Navigator.pop(context);
              },
            ),
            ],
          ],
        );
      },
    );
  }

  void saveState() {
    _prefs?.setInt('current_hours', _hours);
    _prefs?.setInt('current_minutes', _minutes);
    _prefs?.setDouble('current_temperature', _targetTemperature);
    _prefs?.setInt('selected_program', _program?.id ?? 0);
    _prefs?.setDouble('current_temperature_offset', _temperatureOffset);
    _prefs?.setBool('current_shaker_enabled', _shakerEnabled);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body:  SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Container(
        alignment: Alignment.center,
        // Added padding around the Row using Padding widget
        child: 
           Column(
            mainAxisAlignment: .start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            
            spacing: 15,
            children: [
              SizedBox(width: MediaQuery.of(context).size.width - 20, child: 
              Row(
                spacing: 10,
                children: [
                  Flexible(
                    flex: 1,
                    child: 
                  GestureDetector(onTap: () {
                    if (!_isConnected && !_isScanning && !_scanSuccess) {
                      _scanDevices();
                    } else if (_scanSuccess) {
                      showDevicePicker(context);
                    }
                  },
                    child: Text(_statusMessage, softWrap: true, style: TextStyle(fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize, color: _isScanning ? Colors.grey.shade400 : _isConnected ? Theme.of(context).colorScheme.primary :  _scanSuccess ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error))),
                  ),
                  if (_scanSuccess) ...[
                    SizedBox(width: 30),
                    GestureDetector(onTap: () {
                      _scanDevices();
                    }, child: Text('Сканировать', style: TextStyle(fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize, color: Colors.grey.shade500))),
                  ],
                ],
              ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Текущая\nтемпература:'),
                      Text(
                        Utils.getTemperatureString(_currentTemperature, _isFahrenheit),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Целевая\nтемпература:', textAlign: TextAlign.end,),
                      GestureDetector(
                        onTap: () {
                          showTemperaturePicker(context);
                        },
                        child: Text(
                          Utils.getTemperatureString(_targetTemperature, _isFahrenheit),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Row(
                spacing: 10,
                children: [
                  Text('Программа:', style: Theme.of(context).textTheme.bodyMedium),
                GestureDetector(onTap: () {
                  showProgramsPicker(context);
                }, child: Text('${_program?.name ?? 'Не выбрана'} ${_program?.id != null ? ' [${_program?.id}]' : ''}', style: TextStyle(fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize, color: Theme.of(context).colorScheme.tertiary))),
                ],
              ),
              SizedBox(height: 10),
                 Center(
                  child: GestureDetector(
                    onTap: () {
                      showTimePicker(context);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularStepProgressIndicator(
                          totalSteps: 100,
                          currentStep: _progress,
                          width: 180,
                          height: 180,
                          stepSize: 10,
                          selectedColor: Theme.of(context).colorScheme.tertiary,
                          unselectedColor: Colors.grey.shade300,
                          selectedStepSize: 10,
                          roundedCap: (_, __) => true,
                        ),
                        if (_timerRunning)
                          _timer!
                        else
                          _timerPlaceholder!
                      ],
                    ),
                  ),
              ),
              SizedBox(height: 10),
              _needSync ?
                GestureDetector(onTap: () {
                  print('Синхронизировать');
                  setState(() {
                    _canSync = true;
                  });
                }, child: Row(spacing: 5, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sync, color: Theme.of(context).colorScheme.error, size: Theme.of(context).textTheme.bodyMedium?.fontSize,), Text('Синхронизировать', style: TextStyle(fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize, color: Theme.of(context).colorScheme.error))]))
              : SizedBox.shrink(),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.small(onPressed: () {
                    _resetTimer();
                  }, heroTag: 'stop_timer', child: Icon(Icons.stop), foregroundColor: Theme.of(context).colorScheme.secondaryContainer, backgroundColor: Colors.grey.shade500, shape: CircleBorder(),),
                  FloatingActionButton(heroTag: 'start_timer', onPressed: () {
                    if (_timerRunning) {
                      _stopTimer();
                    } else {
                      _startTimer();
                    }
                  }, child: _timerRunning ? Icon(Icons.pause) : Icon(Icons.play_arrow), foregroundColor: Theme.of(context).colorScheme.secondaryContainer, backgroundColor: Theme.of(context).colorScheme.error, shape: CircleBorder(),),
                  FloatingActionButton.small(
                    heroTag: 'save_program',
                    onPressed: () {
                    _displayTextInputDialog(context);
                  }, child: Icon(Icons.save), foregroundColor: Theme.of(context).colorScheme.secondaryContainer, backgroundColor: Theme.of(context).colorScheme.tertiaryFixed, shape: CircleBorder(),),
                ],
              ),
              Row(
                spacing: 10,
                children: [
                  Text('Погрешность температуры:', style: Theme.of(context).textTheme.bodyMedium),
                GestureDetector(onTap: () {
                  showTemperatureOffsetPicker(context);
                }, child: Text('±${Utils.getTemperatureString(_temperatureOffset, _isFahrenheit)}', style: TextStyle(fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize, color: Colors.red.shade400))),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Перемешивание:', style: Theme.of(context).textTheme.bodyMedium),
                  Switch(value: _shakerEnabled, onChanged: (value) {
                    setState(() {
                      _shakerEnabled = value;
                    });
                  }),
                ],
              ),

            ]),
          ),),
        ),
        
    );
  }
}
