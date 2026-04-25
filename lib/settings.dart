import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'buttomNavigation.dart';
import 'main.dart';

class Settings extends StatefulWidget {
  const Settings({super.key, required this.title});

  final String title;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _isDarkMode = false;
  bool _isFahrenheit = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = themeModeNotifier.value == ThemeMode.dark;
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
        _isFahrenheit = prefs.getBool('is_fahrenheit') ?? false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
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
              ToggleButtons(children: [Text('°C'), Text('°F')], borderRadius: BorderRadius.circular(10), isSelected: [ !_isFahrenheit, _isFahrenheit], onPressed: _changeFahrenheit),
            ],
          ),],
      ),
      bottomNavigationBar: ButtomNavigation(currentIndex: 2),
    );
  }
}