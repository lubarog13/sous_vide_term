import 'package:flutter/material.dart';
import 'main.dart';
import 'programList.dart';
import 'settings.dart';
class ButtomNavigation extends StatelessWidget {
  ButtomNavigation({super.key, required this.currentIndex});
  final int currentIndex;
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == 0) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => MyHomePage(title: 'Главная')));
        } 
        if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProgramList(title: 'Программы')));
        }
        if (index == 2) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => Settings(title: 'Настройки')));
        }
      },
      items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.food_bank), label: 'Программы'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
    );
  }
}