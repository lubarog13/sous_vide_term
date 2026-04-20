import 'dart:convert';

Program programFromJson(String str) {
    final jsonData = json.decode(str);
    return Program.fromJson(jsonData);
}

String programToJson(Program data) {
    final dyn = data.toJson();
    return json.encode(dyn);
}


class Program {
  int? id;
  String name;
  int hours;
  int minutes;
  double temperature;
  double temperatureOffset;
  bool shakerEnabled;

  Program({required this.id, required this.name, required this.hours, required this.minutes, required this.temperature, required this.temperatureOffset, required this.shakerEnabled});

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(id: json['id'], name: json['name'], hours: json['hours'], minutes: json['minutes'], temperature: json['temperature'], temperatureOffset: json['temperature_offset'], shakerEnabled: json['shaker_enabled'] == 1 ? true : false);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hours': hours,
      'minutes': minutes,
      'temperature': temperature,
      'temperature_offset': temperatureOffset,
      'shaker_enabled': shakerEnabled ? 1 : 0,
    };
  }
}