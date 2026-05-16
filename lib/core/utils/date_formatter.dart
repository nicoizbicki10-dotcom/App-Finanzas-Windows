import 'package:intl/intl.dart';

abstract class DateFormatter {
  static String monthYear(DateTime date) =>
      DateFormat('MMMM yyyy', 'es_AR').format(date);

  static String short(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  static String dayMonth(DateTime date) =>
      DateFormat('d MMM', 'es_AR').format(date);

  static String time(DateTime date) =>
      DateFormat('HH:mm').format(date);

  static String relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }
}
