import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'programModel.dart';

class DBProvider {
  DBProvider._();
  static final DBProvider db = DBProvider._();
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    } else {
      _database = await initDB();
      return _database!;
    }
  }

  Future<Database> initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
        String path = join(documentsDirectory.path, "sous_vide_term.db");
    print(path);
    return await openDatabase(path, version: 1, onOpen: (db) {
    }, onCreate: (Database db, int version) async {
      await db.execute("CREATE TABLE Program ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT,"
          "name TEXT,"
          "hours INTEGER,"
          "minutes INTEGER,"
          "temperature REAL,"
          "temperature_offset REAL,"
          "shaker_enabled INTEGER"
          ")");
      await insertInitialData();
    });
  }

  Future<void> insertInitialData() async {
    final db = await database;
    List<Map<String, dynamic>> initialData = json.decode('assets/initialData.json');
    for (var item in initialData) {
      Program program = Program.fromJson(item);
      await db.insert('Program', program.toJson());
    }
  }

  Future<int> insertProgram(Program program) async {
    final db = await database;
    print(program.toJson());
    return await db.insert('Program', program.toJson());
  }

  Future<List<Program>> getPrograms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Program');
    if (maps.isEmpty) {
      await insertInitialData();
      return await getPrograms();
    }
    return List.generate(maps.length, (i) => Program.fromJson(maps[i]));
  }

  Future<int> updateProgram(Program program) async {
    final db = await database;
    return await db.update('Program', program.toJson(), where: 'id = ?', whereArgs: [program.id]);
  }

  Future<int> deleteProgram(int id) async {
    final db = await database;
    return await db.delete('Program', where: 'id = ?', whereArgs: [id]);
  }

  Future<Program> getProgram(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Program', where: 'id = ?', whereArgs: [id]);
    return Program.fromJson(maps.first);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

