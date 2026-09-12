import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/prayer_model.dart';

class PrayerApiService {
  // Timeout 10 second tha, jo dheeme mobile data par kaafi nahi hota. Us
  // soorat mein prayer times aate hi nahi the, aur unke baghair azaan ke
  // alarms bhi set nahi hote the. 30 second se ye masla khatam ho jata hai.
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.aladhan.com/v1',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<PrayerTimes> fetchPrayerTimes({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get(
        '/timings',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'method': 1, // University of Islamic Sciences, Karachi
          'school': 1, // Hanafi Asr calculation
        },
      );

      if (response.statusCode == 200) {
        return PrayerTimes.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to load prayer times');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<List<PrayerTimes>> fetchWeeklyPrayerTimes({
    required double latitude,
    required double longitude,
  }) async {
    final now = DateTime.now();

    // Saat din ek ke baad ek maangne se screen 7 x timeout tak atki rehti
    // thi. Ab saaton request saath chalti hain, to kul waqt ek request ke
    // barabar reh jata hai. Jo din nakaam ho wo chhoot jata hai, baqi aa
    // jate hain — tarteeb bhi qaim rehti hai.
    final results = await Future.wait(
      List.generate(7, (i) {
        final date = now.add(Duration(days: i));
        final dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        return _fetchForDate(dateString, latitude, longitude);
      }),
    );

    return results.whereType<PrayerTimes>().toList();
  }

  Future<PrayerTimes?> _fetchForDate(
    String dateString,
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await _dio.get(
        '/timings/$dateString',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'method': 1, // University of Islamic Sciences, Karachi
          'school': 1, // Hanafi Asr calculation
        },
      );

      if (response.statusCode == 200) {
        return PrayerTimes.fromJson(response.data['data']);
      }
    } catch (e) {
      debugPrint('Prayer times $dateString ke liye nahi mile: $e');
    }
    return null;
  }

  String getNextPrayer(PrayerTimes times) {
    final now = DateTime.now();
    final prayers = {
      'Fajr': _parseTime(times.fajr),
      'Dhuhr': _parseTime(times.dhuhr),
      'Asr': _parseTime(times.asr),
      'Maghrib': _parseTime(times.maghrib),
      'Isha': _parseTime(times.isha),
    };

    DateTime? next;
    String? nextName;

    for (var entry in prayers.entries) {
      if (entry.value.isAfter(now)) {
        if (next == null || entry.value.isBefore(next)) {
          next = entry.value;
          nextName = entry.key;
        }
      }
    }

    if (next == null) {
      final first = prayers.entries.first;
      next = first.value.add(const Duration(days: 1));
      nextName = first.key;
    }

    return nextName!;
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Duration getTimeUntilNext(String prayerName, PrayerTimes times) {
    final now = DateTime.now();
    final timeMap = {
      'Fajr': times.fajr,
      'Dhuhr': times.dhuhr,
      'Asr': times.asr,
      'Maghrib': times.maghrib,
      'Isha': times.isha,
    };

    final timeStr = timeMap[prayerName] ?? '00:00';
    final parts = timeStr.split(':');
    final prayerTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    if (prayerTime.isAfter(now)) {
      return prayerTime.difference(now);
    } else {
      return prayerTime.add(const Duration(days: 1)).difference(now);
    }
  }
}