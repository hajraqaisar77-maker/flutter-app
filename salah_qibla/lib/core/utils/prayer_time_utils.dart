import '../../models/prayer_times_model.dart';

class NextPrayerInfo {
  final String name;
  final String time; // HH:mm
  final Duration remaining;

  NextPrayerInfo({required this.name, required this.time, required this.remaining});
}

/// Pure calculation helpers kept outside widgets so they're trivially
/// unit-testable.
class PrayerTimeUtils {
  PrayerTimeUtils._();

  static const List<String> _ordered = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static DateTime _parse(String hhmm, DateTime reference) {
    final parts = hhmm.split(':');
    return DateTime(reference.year, reference.month, reference.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Finds the next upcoming prayer (Sunrise excluded — it's informational,
  /// not an obligatory prayer) relative to [now]. Wraps to tomorrow's Fajr
  /// if every prayer for today has already passed.
  static NextPrayerInfo nextPrayer(PrayerTimesModel timings, DateTime now) {
    final map = timings.asMap;
    for (final name in _ordered) {
      final time = _parse(map[name]!, now);
      if (time.isAfter(now)) {
        return NextPrayerInfo(name: name, time: map[name]!, remaining: time.difference(now));
      }
    }
    final tomorrowFajr = _parse(map['Fajr']!, now.add(const Duration(days: 1)));
    return NextPrayerInfo(name: 'Fajr', time: map['Fajr']!, remaining: tomorrowFajr.difference(now));
  }

  static String formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String format12h(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $period';
  }
}
