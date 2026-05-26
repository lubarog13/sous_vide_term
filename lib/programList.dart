import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'programModel.dart';
import 'database.dart';
import 'utils/utils.dart';
class ProgramList extends StatefulWidget {
  const ProgramList({
    super.key,
    required this.title,
    this.isActive = false,
    this.onProgramSelected,
  });

  final String title;
  final bool isActive;
  final VoidCallback? onProgramSelected;

  @override
  State<ProgramList> createState() => _ProgramListState();
}

  class _ProgramListState extends State<ProgramList> {

  List<Program> programs = [];
  bool isFahrenheit = false;
  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _onPageVisible();
    }
  }

  @override
  void didUpdateWidget(ProgramList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _onPageVisible();
    }
  }

  void _onPageVisible() {
    getPrograms();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        isFahrenheit = prefs.getBool('is_fahrenheit') ?? false;
      });
    });
  }

  Future<void> getPrograms() async {
    final value = await DBProvider.db.getPrograms();
    if (!mounted) return;
    setState(() {
      programs = value;
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
                            SharedPreferences.getInstance().then((prefs) async {
                              await prefs.setInt('selected_program', programs[index].id ?? 0);
                              await prefs.setInt('current_hours', programs[index].hours);
                              await prefs.setInt('current_minutes', programs[index].minutes);
                              await prefs.setDouble('current_temperature', programs[index].temperature);
                              await prefs.setDouble('current_temperature_offset', programs[index].temperatureOffset);
                              await prefs.setBool('current_shaker_enabled', programs[index].shakerEnabled);
                              await prefs.setBool('set_from_list', true);
                              programListSelectionNotifier.value++;
                              widget.onProgramSelected?.call();
                            });
                          }, child: Card(child: _SampleCard(program: programs[index], isFahrenheit: isFahrenheit)));
                        },
                      ) : Center(child: Text('Программы не найдены')),
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