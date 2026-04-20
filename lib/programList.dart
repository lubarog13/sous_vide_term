import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'programModel.dart';
import 'database.dart';
import 'buttomNavigation.dart';
class ProgramList extends StatefulWidget {
  const ProgramList({super.key, required this.title});

  final String title;

  @override
  State<ProgramList> createState() => _ProgramListState();
}

  class _ProgramListState extends State<ProgramList> {

  List<Program> programs = [];
    @override
    void initState() {
      super.initState();
      getPrograms();
    }

  void getPrograms() async {
    programs = await DBProvider.db.getPrograms();
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
      body: Column(
        children: [
          ListView.builder(
            itemBuilder: (context, index) {
              return Card(child: _SampleCard(program: programs[index]));
            },
          ),
        ],
      ),
        bottomNavigationBar: ButtomNavigation(),
    );
  }
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.program});
  final Program program;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('selected_program', program.id ?? 0);
        prefs.setInt('current_hours', program.hours);
        prefs.setInt('current_minutes', program.minutes);
        prefs.setDouble('current_temperature', program.temperature);
        prefs.setDouble('current_temperature_offset', program.temperatureOffset);
        prefs.setBool('current_shaker_enabled', program.shakerEnabled);
      });
    }, child: SizedBox(
        width: 300,
        height: 100,
        child: Center(child: Column(
          children: [
            Text(program.name),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${program.hours}:${program.minutes}'),
                Text('${program.temperature} °C'),
              ],
            ),
          ],
        )),
      ),
    );
  }
}