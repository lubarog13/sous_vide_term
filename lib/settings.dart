import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'main.dart';
import 'utils/texts.dart';

class Settings extends StatefulWidget {
  const Settings({super.key, required this.title});

  final String title;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _isDarkMode = false;
  bool _isFahrenheit = false;
  String _deviceName = "";
  final TextEditingController _deviceNameController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _isDarkMode = themeModeNotifier.value == ThemeMode.dark;
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
        _isFahrenheit = prefs.getBool('is_fahrenheit') ?? false;
        _deviceName = prefs.getString('device_name') ?? dotenv.get('DEVICE_NAME');
        _deviceNameController.text = _deviceName;
      });
    });
  }

  Future<void> _changeTheme(bool isDarkMode) async {
    setState(() {
      _isDarkMode = isDarkMode;
    });
    themeModeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDarkMode);
  }

  Future<void> _changeFahrenheit(int index) async {
    setState(() {
      _isFahrenheit = index == 1;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_fahrenheit', _isFahrenheit);
    print('is_fahrenheit: $_isFahrenheit');
  }

  Future<void> _saveDeviceName() async {
    if (_deviceNameController.text.isEmpty) {
      return;
    }
    setState(() {
      _deviceName = _deviceNameController.text;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', _deviceName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Тёмная тема'),
            value: _isDarkMode,
            onChanged: _changeTheme,
          ),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Температурные единицы:'),
              ToggleButtons(
                children: [Text('°C'), Text('°F')],
                borderRadius: BorderRadius.circular(10),
                isSelected: [!_isFahrenheit, _isFahrenheit],
                onPressed: _changeFahrenheit,
              ),
            ],
          ),
          Divider(),
          Form(
            child: Row(children: [
              Text('Имя устройства:'),
              Expanded(
                child:
                    Padding(padding: EdgeInsets.only(right: 10, left: 10), child: 
              TextFormField(
                controller: _deviceNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Имя устройства не может быть пустым';
                  } 
                  return null;
                },
              ),
                    ),
              ),
              ElevatedButton(onPressed: _saveDeviceName, 
              child: Text('Сохранить', style: TextStyle(color: Colors.white),), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),),),
            ],
          )),
          SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Руководство пользователя'),
                  content: SingleChildScrollView(child: Text(rulesText)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Закрыть'),
                    ),
                  ],
                ),
              );
            },
            child: Text(
              'Руководство пользователя',
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              showDialog(context: context, builder: (context) => AlertDialog(title: Text('Пользовательское соглашение'), content: SingleChildScrollView(child: Text(termsOfUseText)), actions: [
                TextButton(onPressed: () {
                  Navigator.of(context).pop();
                }, child: Text('Закрыть')),
              ],
              ));
            },
            child: Text('Пользовательское соглашение', style: TextStyle(fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize, color: Colors.grey.shade500),),
          ),
        ],
      ),
    );
  }
}
