import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sous_vide_term/main.dart';
import 'programModel.dart';
import 'database.dart';
import 'buttomNavigation.dart';
import 'utils/utils.dart';
class ProgramList extends StatefulWidget {
  const ProgramList({super.key, required this.title});

  final String title;

  @override
  State<ProgramList> createState() => _ProgramListState();
}

  class _ProgramListState extends State<ProgramList> {

  List<Program> programs = [];
  bool isFahrenheit = false;
    @override
    void initState() {
      super.initState();
      print('init');
      getPrograms();
      SharedPreferences.getInstance().then((prefs) {
        setState(() {
          isFahrenheit = prefs.getBool('is_fahrenheit') ?? false;
        });
      });
    }

  void getPrograms() async {
      DBProvider.db.getPrograms().then((value) {
        setState(() {
          programs = value;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: programs.isNotEmpty ? ListView.builder(
                        itemCount: programs.length,
                        scrollDirection: Axis.vertical,
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          return GestureDetector(onTap: () {
                            print(programs[index].toJson());
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setInt('selected_program', programs[index].id ?? 0);
                              prefs.setInt('current_hours', programs[index].hours);
                              prefs.setInt('current_minutes', programs[index].minutes);
                              prefs.setDouble('current_temperature', programs[index].temperature);
                              prefs.setDouble('current_temperature_offset', programs[index].temperatureOffset);
                              prefs.setBool('current_shaker_enabled', programs[index].shakerEnabled);
                              prefs.setBool('set_from_list', true);
                            });
                            Navigator.push(context, MaterialPageRoute(builder: (context) => MyHomePage(title: 'Главная')));
                          }, child: Card(child: _SampleCard(program: programs[index], isFahrenheit: isFahrenheit)));
                        },
                      ) : Center(child: Text('Программы не найдены')),
        bottomNavigationBar: ButtomNavigation(currentIndex: 1),
    );
  }
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.program, required this.isFahrenheit});
  final Program program;
  final bool isFahrenheit;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 300,
        height: 100,
        child: Padding(padding: const EdgeInsets.only(left: 10, right: 10, top: 15, bottom: 10), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(program.name, style: Theme.of(context).textTheme.bodyLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${program.hours.toString().padLeft(2, '0')}:${program.minutes.toString().padLeft(2, '0')}', style: Theme.of(context).textTheme.bodyMedium),
                  Text('${Utils.getTemperatureString(program.temperature, isFahrenheit)}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        )),
    );
  }
}