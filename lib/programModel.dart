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
    // Supports both the "old" DB/JSON keys:
    // - temperature / hours / minutes / temperature_offset
    // and the "new" schema keys:
    // - target_temp / duration_minutes / temp_offset
    return Program(
      id: json['id'],
      name: json['name'],
      hours: () {
        final durationMinutesRaw = json['duration_minutes'] as num?;
        if (durationMinutesRaw != null) {
          final durationMinutes = durationMinutesRaw.toInt();
          return durationMinutes ~/ 60;
        }
        return (json['hours'] as num?)?.toInt() ?? 0;
      }(),
      minutes: () {
        final durationMinutesRaw = json['duration_minutes'] as num?;
        if (durationMinutesRaw != null) {
          final durationMinutes = durationMinutesRaw.toInt();
          return durationMinutes % 60;
        }
        return (json['minutes'] as num?)?.toInt() ?? 0;
      }(),
      temperature: (() {
        final targetTempRaw = json['target_temp'] as num?;
        if (targetTempRaw != null) return targetTempRaw.toDouble();
        final temperatureRaw = json['temperature'] as num?;
        return (temperatureRaw ?? 0).toDouble();
      })(),
      temperatureOffset: (() {
        final tempOffsetRaw = json['temp_offset'] as num?;
        if (tempOffsetRaw != null) return tempOffsetRaw.toDouble();
        final temperatureOffsetRaw = json['temperature_offset'] as num?;
        return temperatureOffsetRaw?.toDouble() ?? 0;
      })(),
      shakerEnabled: json['shaker_enabled'] == 1 || json['shaker_enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'temperature': temperature,
      'temperature_offset': temperatureOffset,
      'hours': hours,
      'minutes': minutes,
      'shaker_enabled': shakerEnabled ? 1 : 0,
    };
  }
}