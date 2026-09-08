import 'package:dio/dio.dart';
import '../models/prayer_model.dart';

class PrayerApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.aladhan.com/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
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

      // DEBUG: raw response console mein print karein taake dekh sakein
      // API se asal mein kya aa raha hai
      // ignore: avoid_print
      print('AZAAN_DEBUG raw response: ${response.data}');

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
    final List<PrayerTimes> weekly = [];
    final now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
          weekly.add(PrayerTimes.fromJson(response.data['data']));
        }
      } catch (e) {
        // ignore: avoid_print
        print('AZAAN_DEBUG weekly error for $dateString: $e');
        continue;
      }
    }
    return weekly;
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