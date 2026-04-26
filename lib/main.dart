import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/flutter_picker_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import 'database.dart';
import 'programModel.dart';
import 'programList.dart';
import 'buttomNavigation.dart';
import 'utils/utils.dart';
import 'services/bluetoothService.dart';
  
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
  themeModeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
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
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.lightBlue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: const MyHomePage(title: 'Умный градусник'),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  double _targetTemperature = 50.0;
  double _currentTemperature = 0;
  double _temperatureOffset = 0.0;
  Program? _program;
  int _hours = 20;
  int _minutes = 30;
  int _seconds = 0;
  int _initialHours = 20;
  int _initialMinutes = 30;
  DateTime _endTime = DateTime.now().add(
    Duration(
      hours: 20,
      minutes: 30,
    ),
  );
  bool _shakerEnabled = false;
  TimerCountdown? _timer;
  Text? _timerPlaceholder;
  bool _timerRunning = false;
  SharedPreferences? _prefs;
  TextEditingController _textFieldController = TextEditingController();
  bool _isFahrenheit = false;


final CustomBluetoothService _bluetoothService = CustomBluetoothService();
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isConnected = false;
  String _statusMessage = "Выберите устройство";
  String _receivedMessage = "";
  @override
 void initState()  {
  print('initState');
    super.initState();
    print('initState');
    _initPrefs();
    _setupBluetoothListeners();
  }

  @override
  void dispose() {
    saveState();
    DBProvider.db.close();
    _bluetoothService.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    int? selectedProgram = _prefs?.getInt('selected_program') ;
    _isFahrenheit = _prefs?.getBool('is_fahrenheit') ?? false;
    if (selectedProgram != null && selectedProgram != 0) {
      Program program = await DBProvider.db.getProgram(selectedProgram);
      _program = program;
      if (!(_prefs?.containsKey('current_hours') ?? false)) {
      _initialHours = program.hours;
      _initialMinutes = program.minutes;
      _hours = _initialHours;
      _minutes = _initialMinutes;
      _seconds = 0;
      _endTime = DateTime.now().add(
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
          _endTime = DateTime.now().add(
            Duration(
              hours: _hours,
              minutes: _minutes,
              seconds: _seconds,
            ),
          );
          _targetTemperature = _prefs?.getDouble('current_temperature') ?? 50.0;
          _temperatureOffset = _prefs?.getDouble('current_temperature_offset') ?? 0.0;
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
          _endTime = DateTime.now().add(
            Duration(
              hours: _hours,
              minutes: _minutes,
            ),
          );
          _targetTemperature = _program?.temperature ?? 50.0;
          _temperatureOffset = _program?.temperatureOffset ?? 0.0;
          _shakerEnabled = _program?.shakerEnabled ?? false;
                } else {
                  _hours = _prefs?.getInt('current_hours') ?? 20;
                  _minutes = _prefs?.getInt('current_minutes') ?? 30;
                  _seconds = _prefs?.getInt('current_seconds') ?? 0;
                  _initialHours = _hours;
                  _initialMinutes = _minutes;
                  _endTime = DateTime.now().add(
                    Duration(
                      hours: _hours,
                      minutes: _minutes,
                      seconds: _seconds,
                    ),
                  );
                  _targetTemperature = _prefs?.getDouble('current_temperature') ?? 50.0;
                  _temperatureOffset = _prefs?.getDouble('current_temperature_offset') ?? 0.0;
                  _shakerEnabled = _prefs?.getBool('current_shaker_enabled') ?? false;
                }
              }
    }
  }

  void _setupBluetoothListeners() {
    // Listen to connection status
    _bluetoothService.connectionStatus.listen((isConnected) {
      setState(() {
        _isConnected = isConnected;
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
    // Request permissions first
    await _requestPermissions();
    
    setState(() {
      _isScanning = true;
      _devices.clear();
      _statusMessage = "Сканирование устройств...";
    });
    
    try {
      await _bluetoothService.scanDevices(10).forEach((devices) {
        setState(() {
          _devices = devices;
        });
      });
      
      setState(() {
        _isScanning = false;
        if (_devices.isEmpty) {
          _statusMessage = "Не найдено устройств. Убедитесь, что устройство включено.";
        } else {
          _statusMessage = "Найдено ${_devices.length} устройств";
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = "Ошибка: $e";
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _statusMessage = "Подключение к ${device.name}...";
    });
    
    bool success = await _bluetoothService.connectToDevice(device);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Подключено к ${device.name}"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Не удалось подключиться"),
          backgroundColor: Colors.red,
        ),
      );
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
        pickerData: _devices.map((device) => device.name).toList(),
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

  void _parseReceivedMessage(String message) {
    print(message);
    setState(() {
      try {
      if (message.startsWith('T:')) {
        _currentTemperature = double.parse(message.substring(2));
      } else if (message.startsWith('O:')) {
        _temperatureOffset = double.parse(message.substring(2));
      } else if (message.startsWith('Tt:')) {
        _targetTemperature = double.parse(message.substring(3));
      } else if (message.startsWith('M:')) {
        int minutes = int.parse(message.substring(2));
        if (minutes > 0) {
          _hours = minutes ~/ 60;
          _minutes = minutes % 60;
          _endTime = DateTime.now().add(
            Duration(
              hours: _hours,
              minutes: _minutes,
              seconds: _seconds,
            ),
          );
          _timer = null;
          createTimer();
        }
      } else if (message.startsWith('S:')) {
          _shakerEnabled = message.substring(2) == '1' ? true : false;
        }
      } catch (e) {
        print(e);
      }
    });
  }
  void _startTimer() {
    setState(() {
      _timerRunning = true;
      _sendCommand('Tt:${_targetTemperature}');
      _sendCommand('O:${_temperatureOffset}');
      _sendCommand('S:${_shakerEnabled ? 1 : 0}');
      _sendCommand('M:${_hours * 60 + _minutes}');
      _sendCommand('START');
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
      _hours = _initialHours;
      _minutes = _initialMinutes;
      _seconds = 0;
      _endTime = DateTime.now().add(
        Duration(
          hours: _hours,
          minutes: _minutes,
          seconds: _seconds,
        ),
      );
      createTimerPlaceholder();
      _timer = null;
    });
  }

  void createTimer() {
    _timer = TimerCountdown(
      format: CountDownTimerFormat.hoursMinutes,
      endTime: _endTime,
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
          _minutes = duration.inMinutes % 60;
          _seconds = duration.inSeconds % 60;
        });
      },
    );
  }

  void createTimerPlaceholder() {
    _timerPlaceholder = Text('$_hours : ${_minutes.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 50));
  }


  void showTemperaturePicker(BuildContext context) {
    Picker(
      adapter: NumberPickerAdapter(data: [
        const NumberPickerColumn(begin: 0, end: 100),
        const NumberPickerColumn(begin: 0, end: 10),
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
          _sendCommand('Tt:${_targetTemperature}');
        });
      },
    ).showModal(context);
  }

  void showTemperatureOffsetPicker(BuildContext context) {
    Picker(
      adapter: NumberPickerAdapter(data: [
        const NumberPickerColumn(begin: 0, end: 99),
        const NumberPickerColumn(begin: 0, end: 10),
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
        const NumberPickerColumn(begin: 0, end: 24),
        const NumberPickerColumn(begin: 0, end: 59),
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
    confirmTextStyle: TextStyle(fontSize: 20, color: Colors.blue),
    
      title: const Text('Выберите время'),
      onConfirm: (Picker picker, List<int> value) {
        setState(() {
          _timerRunning = false;
          _hours = value[0];
          _minutes = value[1];
          _seconds = 0;
          _initialHours = _hours;
          _initialMinutes = _minutes;
          _seconds = 0;
          _endTime = DateTime.now().add(
            Duration(
              hours: _hours,
              minutes: _minutes,
              seconds: _seconds,
            ),
          );
          _timer = null;
          createTimer();
        });
      },
    ).showModal(context);
  }

  Future<void> showProgramsPicker(BuildContext context) async {
    List<Program> programs = await DBProvider.db.getPrograms();
    Picker(
      adapter:  PickerDataAdapter<String>(
      pickerData: programs.map((program) => program.name + ' [${program.id}]').toList()
    ),
    confirmText: 'Установить',
    cancelText: 'Отмена',
    confirmTextStyle: TextStyle(fontSize: 20, color: Colors.blue),
    
      title: const Text('Выберите программу'),
      onConfirm: (Picker picker, List<int> value) {
        setState(() {
          _program = programs[value[0]];
          _initialHours = programs[value[0]].hours;
          _initialMinutes = programs[value[0]].minutes;
          _hours = _initialHours;
          _minutes = _initialMinutes;
          _seconds = 0;
          _endTime = DateTime.now().add(
            Duration(
              hours: _hours,
              minutes: _minutes,
              seconds: _seconds,
            ),
          );
          _targetTemperature = programs[value[0]].temperature;
          _temperatureOffset = programs[value[0]].temperatureOffset;
          _shakerEnabled = programs[value[0]].shakerEnabled;
          _timerRunning = false;
          _timer = null;
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
    createTimerPlaceholder();
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
         child:  SizedBox(
              height: (MediaQuery.of(context).size.height - 150), child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Container(
        alignment: Alignment.center,
        // Added padding around the Row using Padding widget
        child: 
           Column(
            mainAxisAlignment: .start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            
            spacing: 30,
            children: [
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
                }, child: Text('${_program?.name ?? 'Не выбрана'} ${_program?.id != null ? ' [${_program?.id}]' : ''}', style: TextStyle(fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize, color: Colors.blue))),
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
                children: [
                  GestureDetector(onTap: () {
                    if (!_isConnected && !_isScanning) {
                      _scanDevices();
                    }
                  }, child: Text(_statusMessage, softWrap: true, style: TextStyle(fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize, color: _isScanning ? Colors.grey.shade400 : _isConnected ? Colors.green.shade400 : Colors.red.shade400))),
                ],
              ),
              Spacer(),
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
                          currentStep:  (((_initialHours - _hours) * 60 * 60 + (_initialMinutes - _minutes) * 60 - _seconds) / (_initialHours * 60 * 60 + _initialMinutes * 60 ) * 100).toInt(),
                          width: 200,
                          height: 200,
                          stepSize: 10,
                          selectedColor: Colors.blueAccent.shade400,
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
                            Spacer(),

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.small(onPressed: () {
                    _resetTimer();
                  }, heroTag: 'stop_timer', child: Icon(Icons.stop), foregroundColor: Colors.white, backgroundColor: Colors.grey.shade300, shape: CircleBorder(),),
                  FloatingActionButton(heroTag: 'start_timer', onPressed: () {
                    if (_timerRunning) {
                      _stopTimer();
                    } else {
                      _startTimer();
                    }
                  }, child: _timerRunning ? Icon(Icons.pause) : Icon(Icons.play_arrow), foregroundColor: Colors.white, backgroundColor: Colors.redAccent, shape: CircleBorder(),),
                  FloatingActionButton.small(
                    heroTag: 'save_program',
                    onPressed: () {
                    _displayTextInputDialog(context);
                  }, child: Icon(Icons.save), foregroundColor: Colors.white, backgroundColor: Colors.lightBlue.shade100, shape: CircleBorder(),),
                ],
              ),
            ]),
          ),),),
        ),
        
      bottomNavigationBar: ButtomNavigation(currentIndex: 0),
    );
  }
}
