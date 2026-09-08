import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/prayer_model.dart';

const String _azaanAsset = 'audio/azaan.mp3'; // assets/audio/azaan.mp3
const String _channelId = 'azaan_channel';
const String _channelName = 'Azaan Alerts';

/// ---------------------------------------------------------------------
/// BACKGROUND ENTRY POINT
/// This function runs in its own isolate, spawned by Android's AlarmManager
/// even if the app has been fully closed/killed. It must be a top-level
/// (or static) function, annotated with @pragma('vm:entry-point') so the
/// Dart compiler does not tree-shake it away in release builds.
/// ---------------------------------------------------------------------
@pragma('vm:entry-point')
void azaanAlarmCallback(int id, Map<String, dynamic>? params) async {
  final prayerName = params?['prayerName'] as String? ?? 'Prayer';

  // 1. Show a notification with a Stop action.
  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidInit),
  );

  const androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    importance: Importance.max,
    priority: Priority.high,
    playSound: false, // audio is played separately below
    ongoing: true,
    autoCancel: false,
    actions: [AndroidNotificationAction('stop_azaan', 'Stop')],
  );

  await notifications.show(
    id,
    '$prayerName Prayer Time',
    'It is time for $prayerName. Tap Stop to silence.',
    const NotificationDetails(android: androidDetails),
  );

  // 2. Play the azaan audio right here in the background isolate.
  final player = AudioPlayer();
  await player.play(AssetSource(_azaanAsset));
}

/// Handles scheduling automatic azaan alarms for each prayer time,
/// playing the azaan audio when a prayer time is reached (even if the app
/// is closed), and stopping it when the user taps the notification action
/// or the in-app Stop button.
class AzaanAlarmService {
  static final AzaanAlarmService _instance = AzaanAlarmService._internal();
  factory AzaanAlarmService() => _instance;
  AzaanAlarmService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;

  /// Call once at app startup (e.g. in main() before runApp).
  Future<void> init() async {
    if (_initialized) return;

    // Alarms/notifications aren't supported on the web platform. Skip
    // setup there so `flutter run -d web-server`/Chrome doesn't crash;
    // the real feature works on Android.
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // Boots the background alarm manager plugin. Must be called before
    // any oneShotAt/periodic scheduling.
    await AndroidAlarmManager.initialize();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) async {
        if (response.actionId == 'stop_azaan') {
          await stopAzaan();
        }
      },
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Automatic azaan alerts at each prayer time',
        importance: Importance.max,
      );
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Schedules today's 5 prayer alarms from a PrayerTimes object.
  /// Call this whenever fresh prayer times are fetched (e.g. right after
  /// weeklyPrayerProvider / prayerTimesProvider resolves for today).
  Future<void> scheduleTodayAlarms(PrayerTimes times) async {
    if (kIsWeb) return; // Alarms/notifications aren't supported on web.

    await _cancelAll();

    final entries = {
      1: MapEntry('Fajr', times.fajr),
      2: MapEntry('Dhuhr', times.dhuhr),
      3: MapEntry('Asr', times.asr),
      4: MapEntry('Maghrib', times.maghrib),
      5: MapEntry('Isha', times.isha),
    };

    for (final entry in entries.entries) {
      final id = entry.key;
      final name = entry.value.key;
      final timeStr = entry.value.value;
      await _scheduleOne(id, name, timeStr);
    }
  }

  Future<void> _scheduleOne(int id, String prayerName, String timeStr) async {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    // If the time already passed today, don't schedule for today.
    if (scheduled.isBefore(now)) return;

    // This is the key call: it registers a real Android system alarm
    // that will wake a background isolate and run azaanAlarmCallback,
    // even if the app has been swiped away / fully closed.
    await AndroidAlarmManager.oneShotAt(
      scheduled,
      id,
      azaanAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      alarmClock: true, // treated like a real alarm clock by Android
      params: {'prayerName': prayerName},
    );
  }

  /// Plays the azaan audio immediately (e.g. for a "test azaan" button
  /// inside the app, or from the foreground when needed).
  Future<void> playAzaan() async {
    await _player.stop();
    await _player.play(AssetSource(_azaanAsset));
  }

  Future<void> stopAzaan() async {
    await _player.stop();
    await _notifications.cancelAll();
  }

  /// Aaj ke tamam azaan alarms mita deta hai — jab user settings se
  /// azaan band kar de.
  Future<void> cancelAllAlarms() => _cancelAll();

  Future<void> _cancelAll() async {
    if (kIsWeb) return;
    for (int id = 1; id <= 5; id++) {
      await AndroidAlarmManager.cancel(id);
    }
    await _notifications.cancelAll();
  }
}
