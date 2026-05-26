import 'package:flutter/material.dart';
import 'main.dart';
import 'programList.dart';
import 'settings.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MyHomePage(
            title: 'Главная',
            isActive: _currentIndex == 0,
          ),
          ProgramList(
            title: 'Программы',
            isActive: _currentIndex == 1,
            onProgramSelected: () => setState(() => _currentIndex = 0),
          ),
          const Settings(title: 'Настройки'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.food_bank), label: 'Программы'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}