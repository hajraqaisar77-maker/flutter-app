import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prayer_model.dart';
import '../services/prayer_api_service.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';

final prayerApiServiceProvider = Provider<PrayerApiService>((ref) {
  return PrayerApiService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final prayerTimesProvider = FutureProvider<PrayerTimes>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final apiService = ref.read(prayerApiServiceProvider);

  final position = await locationService.getCurrentPosition();
  return await apiService.fetchPrayerTimes(
    latitude: position.latitude,
    longitude: position.longitude,
  );
});

final weeklyPrayerProvider = FutureProvider<List<PrayerTimes>>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final apiService = ref.read(prayerApiServiceProvider);

  final position = await locationService.getCurrentPosition();
  return await apiService.fetchWeeklyPrayerTimes(
    latitude: position.latitude,
    longitude: position.longitude,
  );
});

final duaCountProvider = FutureProvider<int>((ref) async {
  final storage = ref.read(storageServiceProvider);
  return await storage.getDuaCount();
});
