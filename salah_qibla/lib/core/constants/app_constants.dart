class AppConstants {
  AppConstants._();

  static const String appName = 'Salah & Qibla';

  static const String aladhanBaseUrl = 'https://api.aladhan.com/v1';

  static const List<String> prayerOrder = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  // Hive box names
  static const String settingsBox = 'settings_box';
  static const String prayerCacheBox = 'prayer_cache_box';
  static const String locationBox = 'location_box';

  // Hive keys
  static const String keySettings = 'app_settings';
  static const String keyLastLocation = 'last_location';
  static const String keyPrayerCachePrefix = 'timings_';
}
