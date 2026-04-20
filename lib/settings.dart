import 'package:flutter/material.dart';

import 'buttomNavigation.dart';
class Settings extends StatefulWidget {
  const Settings({super.key, required this.title});

  final String title;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Text('Настройки'),
        ],
      ),
      bottomNavigationBar: ButtomNavigation(),
    );
  }
}