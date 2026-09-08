import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prayer_model.dart';
import '../services/prayer_api_service.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';

// ========== SERVICES PROVIDERS ==========
final prayerApiServiceProvider = Provider<PrayerApiService>((ref) {
  return PrayerApiService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// ========== PRAYER TIMES PROVIDERS ==========
final prayerTimesProvider = FutureProvider<PrayerTimes>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final apiService = ref.read(prayerApiServiceProvider);

  try {
    final position = await locationService.getCurrentPosition();
    return await apiService.fetchPrayerTimes(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } catch (e) {
    // Agar error aaye toh throw karein
    throw Exception('Failed to load prayer times: $e');
  }
});

final weeklyPrayerProvider = FutureProvider<List<PrayerTimes>>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final apiService = ref.read(prayerApiServiceProvider);

  try {
    final position = await locationService.getCurrentPosition();
    return await apiService.fetchWeeklyPrayerTimes(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } catch (e) {
    throw Exception('Failed to load weekly prayer times: $e');
  }
});

// ========== STORAGE PROVIDERS ==========
final duaCountProvider = FutureProvider<int>((ref) async {
  final storage = ref.read(storageServiceProvider);
  try {
    return await storage.getDuaCount();
  } catch (e) {
    return 0; // Default value agar error ho
  }
});

// ========== CURRENT PRAYER PROVIDER ==========
final currentPrayerProvider = Provider<String>((ref) {
  final prayerTimesAsync = ref.watch(prayerTimesProvider);
  
  return prayerTimesAsync.when(
    data: (times) {
      final apiService = PrayerApiService();
      return apiService.getNextPrayer(times);
    },
    loading: () => 'Loading...',
    error: (_, __) => 'Maghrib', // Default fallback
  );
});

// ========== NEXT PRAYER TIME PROVIDER ==========
final nextPrayerTimeProvider = Provider<String>((ref) {
  final prayerTimesAsync = ref.watch(prayerTimesProvider);
  
  return prayerTimesAsync.when(
    data: (times) {
      final apiService = PrayerApiService();
      final nextPrayer = apiService.getNextPrayer(times);
      final timeMap = {
        'Fajr': times.fajr,
        'Dhuhr': times.dhuhr,
        'Asr': times.asr,
        'Maghrib': times.maghrib,
        'Isha': times.isha,
      };
      return timeMap[nextPrayer] ?? '--:--';
    },
    loading: () => '--:--',
    error: (_, __) => '--:--',
  );
});

// ========== TIME UNTIL NEXT PRAYER PROVIDER ==========
final timeUntilNextPrayerProvider = Provider<Duration>((ref) {
  final prayerTimesAsync = ref.watch(prayerTimesProvider);
  
  return prayerTimesAsync.when(
    data: (times) {
      final apiService = PrayerApiService();
      final nextPrayer = apiService.getNextPrayer(times);
      return apiService.getTimeUntilNext(nextPrayer, times);
    },
    loading: () => Duration.zero,
    error: (_, __) => Duration.zero,
  );
});