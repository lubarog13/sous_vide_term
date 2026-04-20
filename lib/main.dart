import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/flutter_picker_plus.dart';

import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'programModel.dart';
import 'programList.dart';
import 'buttomNavigation.dart';
  
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.lightBlue),
      ),
      home: const MyHomePage(title: 'Умный градусник'),
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



  @override
 void initState()  {
  print('initState');
    super.initState();
    print('initState');
    _initPrefs();

  }

  @override
  void dispose() {
    saveState();
    DBProvider.db.close();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    int? selectedProgram = _prefs?.getInt('selected_program') ;
    if (selectedProgram != null && selectedProgram != 0) {
      Program program = await DBProvider.db.getProgram(selectedProgram);
      _program = program;
      if (!(_prefs?.containsKey('current_hours') ?? false)) {
      _initialHours = program.hours;
      _initialMinutes = program.minutes;
      _hours = _initialHours;
      _minutes = _initialMinutes;
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
          _initialHours = _hours;
          _initialMinutes = _minutes;
          _endTime = DateTime.now().add(
            Duration(
              hours: _hours,
              minutes: _minutes,
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
                  _initialHours = _hours;
                  _initialMinutes = _minutes;
                  _endTime = DateTime.now().add(
                    Duration(
                      hours: _hours,
                      minutes: _minutes,
                    ),
                  );
                  _targetTemperature = _prefs?.getDouble('current_temperature') ?? 50.0;
                  _temperatureOffset = _prefs?.getDouble('current_temperature_offset') ?? 0.0;
                  _shakerEnabled = _prefs?.getBool('current_shaker_enabled') ?? false;
                }
              }
    }
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  void _startTimer() {
    setState(() {
      _timerRunning = true;
      createTimer();
    });
  }

  void _stopTimer() {
    setState(() {
      _timerRunning = false;
      createTimerPlaceholder();
      _timer = null;
    });
  }

  void _resetTimer() {
    setState(() {
      _timerRunning = false;
      _hours = _initialHours;
      _minutes = _initialMinutes;
      _endTime = DateTime.now().add(
        Duration(
          hours: _hours,
          minutes: _minutes,
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
        });
      },
    );
  }

  void createTimerPlaceholder() {
    _timerPlaceholder = Text('$_hours : $_minutes', style: TextStyle(fontSize: 50));
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
        });
      },
    ).showModal(context);
  }

  void showTimePicker(BuildContext context) {
    Picker(
      adapter: NumberPickerAdapter(data: [
        const NumberPickerColumn(begin: 0, end: 24),
        const NumberPickerColumn(begin: 0, end: 60),
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
          _hours = value[0];
          _minutes = value[1];
          _initialHours = _hours;
          _initialMinutes = _minutes;
          _endTime = DateTime.now().add(
            Duration(
              hours: _hours,
              minutes: _minutes,
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
      adapter:  PickerDataAdapter<Program>(
      pickerData: programs.map((program) => program.name).toList()
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
          _endTime = DateTime.now().add(
            Duration(
              hours: _hours,
              minutes: _minutes,
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
                List<String> programs = _prefs?.getStringList('programs') ?? [];
                String programName = _textFieldController.text;
                Program program = Program(id:null, name: programName, hours: _initialHours, minutes: _initialMinutes, temperature: _targetTemperature, temperatureOffset: _temperatureOffset, shakerEnabled: _shakerEnabled);
                print(program.toJson());
                int id = await DBProvider.db.insertProgram(program);
                program.id = id;
                print(program.toJson());
                await _prefs?.setInt('selected_program', program.id ?? 0);
                _program = program;
                print(_program?.toJson());
                Navigator.pop(context);
              },
            ),
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
      body:  Padding(
        padding: const EdgeInsets.all(30.0),
        child: Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        // Added padding around the Row using Padding widget
        child: 
           Column(
            mainAxisAlignment: .start,
            mainAxisSize: MainAxisSize.max,
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
                        '$_currentTemperature °C',
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
                          '$_targetTemperature °C',
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
                }, child: Text('${_program?.name ?? 'Не выбрана'}', style: TextStyle(fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize, color: Colors.blue))),
                ],
              ),
              Row(
                spacing: 10,
                children: [
                  Text('Погрешность температуры:', style: Theme.of(context).textTheme.bodyMedium),
                GestureDetector(onTap: () {
                  showTemperatureOffsetPicker(context);
                }, child: Text('±$_temperatureOffset °C', style: TextStyle(fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize, color: Colors.red.shade400))),
                ],
              ),
              Flexible(
                flex: 1,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      showTimePicker(context);
                    },
                    child: _timerRunning ? _timer : _timerPlaceholder
                  ),
                ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.small(onPressed: () {
                    _resetTimer();
                  }, child: Icon(Icons.stop), foregroundColor: Colors.white, backgroundColor: Colors.grey.shade300, shape: CircleBorder(),),
                  FloatingActionButton(onPressed: () {
                    if (_timerRunning) {
                      _stopTimer();
                    } else {
                      _startTimer();
                    }
                  }, child: _timerRunning ? Icon(Icons.pause) : Icon(Icons.play_arrow), foregroundColor: Colors.white, backgroundColor: Colors.redAccent, shape: CircleBorder(),),
                  FloatingActionButton.small(onPressed: () {
                    _displayTextInputDialog(context);
                  }, child: Icon(Icons.save), foregroundColor: Colors.white, backgroundColor: Colors.lightBlue.shade100, shape: CircleBorder(),),
                ],
              ),
            ]),
          ),
        ),
        
      bottomNavigationBar: ButtomNavigation(),
    );
  }
}
