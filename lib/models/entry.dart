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

  DiaryEntry({required this.date, required this.isAngel, required this.note});
}
