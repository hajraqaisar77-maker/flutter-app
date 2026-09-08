import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings_model.dart';
import '../repositories/location_repository.dart';
import '../repositories/prayer_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_api_service.dart';
import '../services/storage_service.dart';

/// The single [StorageService] instance, created and initialized in
/// main() before runApp — see `overrideWithValue` at app bootstrap.
final storageServiceProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('storageServiceProvider must be overridden in main()'),
);

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

final prayerApiServiceProvider = Provider<PrayerApiService>((ref) => PrayerApiService());

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  return PrayerRepository(
    api: ref.watch(prayerApiServiceProvider),
    storage: ref.watch(storageServiceProvider),
  );
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(
    locationService: ref.watch(locationServiceProvider),
    storage: ref.watch(storageServiceProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(storageServiceProvider));
});

/// App settings as observable state — every settings screen control reads
/// and writes through this notifier so the whole app reacts instantly.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettingsModel>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettingsModel> {
  @override
  AppSettingsModel build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> update(AppSettingsModel Function(AppSettingsModel) updater) async {
    final updated = updater(state);
    state = updated;
    await ref.read(settingsRepositoryProvider).save(updated);
  }
}
