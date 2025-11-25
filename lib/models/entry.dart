import 'package:hive/hive.dart';

part 'entry.g.dart';

@HiveType(typeId: 0)
class DiaryEntry extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final bool isAngel;

  @HiveField(2)
  final String note;

  @HiveField(3)
  final bool isDay; // true for day (7am-7pm), false for night (7pm-7am)

  DiaryEntry({
    required this.date,
    required this.isAngel,
    required this.note,
    required this.isDay,
  });
}
