import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_model.dart';
import '../models/reminder_settings.dart';

/// App ke tamam local notifications ek hi jagah se schedule hote hain,
/// taake ids aur channels kahin takrayein nahin.
///
/// Waqt hamesha [tz.TZDateTime] mein nikala jata hai. Yehi wajah thi ke
/// pehle `LateInitializationError: Field '_local'` aata tha — timezone
/// database load kiye baghair `tz.local` chhoo liya gaya tha. Ab
/// [initialize] app shuru hote hi ye kaam kar deta hai.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  /// Kya timezone database load ho chuka hai.
  static bool get isReady => _ready;

  // ---------------------------------------------------------------------
  // Notification ids
  //
  //   1  ..  5   AzaanAlarmService (AndroidAlarmManager) ke liye mahfooz
  // 100  .. 104  azaan, ain namaz ke waqt
  // 200  .. 204  namaz se pehle yaad-dihani
  // 300          Jumma Mubarak
  // 301          Jumma ko Surah Al-Kahf
  // 400          rozana Surah Ar-Rahman
  // ---------------------------------------------------------------------
  static const int _azaanBaseId = 100;
  static const int _preReminderBaseId = 200;
  static const int _jummaId = 300;
  static const int _kahfId = 301;
  static const int _rahmanId = 400;

  static const String _azanChannelId = 'azan_channel';
  static const String _prayerReminderChannelId = 'prayer_reminder_channel';
  static const String _jummaChannelId = 'jumma_channel';
  static const String _surahChannelId = 'surah_channel';

  static const List<String> _prayerOrder = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  // =====================================================================
  // INITIALIZE
  // =====================================================================

  /// `main()` mein `runApp()` se pehle bulana zaroori hai.
  static Future<void> initialize() async {
    if (_ready) return;

    // Web par local notifications aur alarms nahin chalte. Yahan chup-chaap
    // wapas ho jate hain taake `flutter run -d chrome` crash na kare.
    if (kIsWeb) {
      _ready = true;
      return;
    }

    await _configureTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _createChannels();

    _ready = true;
  }

  /// Device ka apna timezone maloom karke `tz.local` set karta hai.
  ///
  /// Pehle yahan `Asia/Karachi` hardcoded tha — us se app mulk se bahar
  /// ghalat waqt par notification bhejta. Ab device se poocha jata hai,
  /// aur nakaami ki soorat mein Karachi par wapas aa jata hai.
  static Future<void> _configureTimeZone() async {
    tzdata.initializeTimeZones();

    String identifier = 'Asia/Karachi';
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      if (info.identifier.isNotEmpty) identifier = info.identifier;
    } catch (e) {
      debugPrint('Device timezone nahi mila, Asia/Karachi le rahe hain: $e');
    }

    try {
      tz.setLocalLocation(tz.getLocation(identifier));
    } catch (e) {
      debugPrint('"$identifier" timezone database mein nahi mila: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    }
  }

  static Future<void> _createChannels() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _azanChannelId,
      'Azan Alarm',
      description: 'Namaz ke waqt Azan ka reminder',
      importance: Importance.max,
      playSound: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _prayerReminderChannelId,
      'Namaz se pehle yaad-dihani',
      description: 'Har namaz se kuch minute pehle itlaa',
      importance: Importance.high,
      playSound: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _jummaChannelId,
      'Jumma aur Surah Al-Kahf',
      description: 'Jumma Mubarak aur Surah Al-Kahf parhne ki yaad-dihani',
      importance: Importance.high,
      playSound: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _surahChannelId,
      'Surah Ar-Rahman Reminder',
      description: 'Rozana Surah Ar-Rahman sunne ki yaad dilaye',
      importance: Importance.high,
      playSound: true,
    ));
  }

  /// Android 13+ par notification ki ijazat maangta hai.
  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  // =====================================================================
  // EK HI DARWAZA — sab kuch yahan se schedule hota hai
  // =====================================================================

  /// Tamam rozana/haftawar reminders dobara set karta hai.
  ///
  /// Ye app khulne par aur jab bhi naye prayer times aayein, dono waqt
  /// bulaya jata hai. Purane schedules pehle mita diye jate hain, is liye
  /// isay baar baar bulana bilkul mehfooz hai.
  static Future<void> rescheduleAll({
    PrayerTimes? times,
    required ReminderSettings settings,
  }) async {
    if (kIsWeb) return;
    if (!_ready) await initialize();

    await requestPermissions();

    if (times != null) {
      // Ain namaz ke waqt ki azaan `AzaanAlarmService` sambhalti hai — wo
      // poori azaan ki audio bajati hai (app band ho tab bhi) aur "Stop"
      // ka button deti hai. Yahan se bhi notification bhejte to user ko
      // do itlaayen miltin, is liye purani wali cancel kar dete hain.
      await _cancelRange(_azaanBaseId, _prayerOrder.length);

      if (settings.prePrayerEnabled) {
        await schedulePrePrayerReminders(
          times,
          minutesBefore: settings.prePrayerMinutes,
        );
      } else {
        await _cancelRange(_preReminderBaseId, _prayerOrder.length);
      }
    }

    if (settings.jummaEnabled) {
      await scheduleJummaReminder(settings);
    } else {
      await _notifications.cancel(_jummaId);
    }

    if (settings.kahfEnabled) {
      await scheduleKahfReminder(settings);
    } else {
      await _notifications.cancel(_kahfId);
    }

    await scheduleSurahRahmanReminder(settings, ishaTime: times?.isha);
  }

  // =====================================================================
  // AZAAN — ain namaz ke waqt
  // =====================================================================

  static Future<void> scheduleAzanAlarms(PrayerTimes times) async {
    if (kIsWeb) return;
    if (!_ready) await initialize();

    await _cancelRange(_azaanBaseId, _prayerOrder.length);

    final map = _asMap(times);
    for (var i = 0; i < _prayerOrder.length; i++) {
      final name = _prayerOrder[i];
      final at = _parseClock(map[name]);
      if (at == null) continue;

      await _scheduleDaily(
        id: _azaanBaseId + i,
        channelId: _azanChannelId,
        channelName: 'Azan Alarm',
        title: '$name ki Azan',
        body: '$name ki namaz ka waqt ho gaya hai',
        hour: at.$1,
        minute: at.$2,
        importance: Importance.max,
        sound: const RawResourceAndroidNotificationSound('azaan'),
      );
    }
  }

  // =====================================================================
  // NAMAZ SE PEHLE YAAD-DIHANI
  // =====================================================================

  /// Har namaz se [minutesBefore] minute pehle itlaa.
  static Future<void> schedulePrePrayerReminders(
    PrayerTimes times, {
    int minutesBefore = 15,
  }) async {
    if (kIsWeb) return;
    if (!_ready) await initialize();

    await _cancelRange(_preReminderBaseId, _prayerOrder.length);

    final map = _asMap(times);
    for (var i = 0; i < _prayerOrder.length; i++) {
      final name = _prayerOrder[i];
      final at = _parseClock(map[name]);
      if (at == null) continue;

      // Namaz ke waqt se peechhe hat kar minute nikalte hain. Aadhi raat
      // se pehle chala jaye to agle din ka wahi lamha le liya jata hai —
      // rozana repeat hone ki wajah se ye khud-b-khud durust rehta hai.
      final total = at.$1 * 60 + at.$2 - minutesBefore;
      final wrapped = (total % (24 * 60) + (24 * 60)) % (24 * 60);

      await _scheduleDaily(
        id: _preReminderBaseId + i,
        channelId: _prayerReminderChannelId,
        channelName: 'Namaz se pehle yaad-dihani',
        title: '$name ka waqt qareeb hai',
        body: '$minutesBefore minute baad $name ka waqt ho jayega '
            '(${ReminderSettings.formatTime12h(at.$1, at.$2)}). Tayyari kar lijiye.',
        hour: wrapped ~/ 60,
        minute: wrapped % 60,
      );
    }
  }

  // =====================================================================
  // JUMMA
  // =====================================================================

  static Future<void> scheduleJummaReminder(ReminderSettings settings) async {
    if (kIsWeb) return;
    if (!_ready) await initialize();

    await _scheduleWeekly(
      id: _jummaId,
      weekday: DateTime.friday,
      channelId: _jummaChannelId,
      channelName: 'Jumma aur Surah Al-Kahf',
      title: 'Jumma Mubarak',
      body: 'Aaj Jumma hai — ghusl, khushbu aur jaldi masjid jane ki sunnat '
          'na bhooliye. Nabi kareem (ﷺ) par kasrat se durood bhejiye.',
      hour: settings.jummaHour,
      minute: settings.jummaMinute,
    );
  }

  static Future<void> scheduleKahfReminder(ReminderSettings settings) async {
    if (kIsWeb) return;
    if (!_ready) await initialize();

    await _scheduleWeekly(
      id: _kahfId,
      weekday: DateTime.friday,
      channelId: _jummaChannelId,
      channelName: 'Jumma aur Surah Al-Kahf',
      title: 'Surah Al-Kahf parhne ka waqt',
      body: 'Jumma ke din Surah Al-Kahf parhna baais-e-noor hai. '
            'Quran section se abhi kholiye.',
      hour: settings.kahfHour,
      minute: settings.kahfMinute,
    );
  }

  // =====================================================================
  // SURAH AR-RAHMAN — rozana, user ke chune hue waqt par
  // =====================================================================

  /// [settings] ke mutabiq rozana reminder set karta hai.
  ///
  /// [RahmanReminderMode.afterIsha] ki soorat mein [ishaTime] ("HH:mm")
  /// chahiye hota hai; wo na mile to user ka custom waqt le liya jata hai.
  static Future<void> scheduleSurahRahmanReminder(
    ReminderSettings settings, {
    String? ishaTime,
  }) async {
    if (kIsWeb) return;
    if (!_ready) await initialize();

    await _notifications.cancel(_rahmanId);
    if (!settings.rahmanEnabled) return;

    int hour = settings.rahmanHour;
    int minute = settings.rahmanMinute;

    if (settings.rahmanMode == RahmanReminderMode.afterIsha) {
      final isha = _parseClock(ishaTime);
      if (isha != null) {
        final total =
            isha.$1 * 60 + isha.$2 + settings.rahmanMinutesAfterIsha;
        final wrapped = total % (24 * 60);
        hour = wrapped ~/ 60;
        minute = wrapped % 60;
      }
    }

    await _scheduleDaily(
      id: _rahmanId,
      channelId: _surahChannelId,
      channelName: 'Surah Ar-Rahman Reminder',
      title: 'Surah Ar-Rahman',
      body: 'Surah Ar-Rahman sunne ka waqt ho gaya. '
          '"Tum apne Rab ki kaun kaun si nemat ko jhutlao ge?"',
      hour: hour,
      minute: minute,
    );
  }

  /// Purana naam — messages screen isay bulati thi. Ab settings ke
  /// zariye chalta hai taake user ka chuna hua waqt qaim rahe.
  static Future<void> scheduleDailyReminder({
    ReminderSettings settings = const ReminderSettings(rahmanEnabled: true),
    String? ishaTime,
  }) {
    return scheduleSurahRahmanReminder(settings, ishaTime: ishaTime);
  }

  // =====================================================================
  // CANCEL
  // =====================================================================

  static Future<void> cancelNotification(int id) => _notifications.cancel(id);

  static Future<void> cancelAllNotifications() => _notifications.cancelAll();

  static Future<void> _cancelRange(int baseId, int count) async {
    for (var i = 0; i < count; i++) {
      await _notifications.cancel(baseId + i);
    }
  }

  // =====================================================================
  // NEECHE KE CHHOTE HISSE
  // =====================================================================

  static Map<String, String> _asMap(PrayerTimes t) => {
        'Fajr': t.fajr,
        'Dhuhr': t.dhuhr,
        'Asr': t.asr,
        'Maghrib': t.maghrib,
        'Isha': t.isha,
      };

  /// "HH:mm" ko (hour, minute) mein todta hai. Kharab ya khaali waqt par
  /// `null` — API se kabhi "--:--" bhi aa jata hai.
  static (int, int)? _parseClock(String? value) {
    if (value == null) return null;
    final parts = value.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (h, m);
  }

  static Future<void> _scheduleDaily({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required int hour,
    required int minute,
    Importance importance = Importance.high,
    AndroidNotificationSound? sound,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: importance,
          priority: Priority.high,
          playSound: true,
          sound: sound,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> _scheduleWeekly({
    required int id,
    required int weekday,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeekday(weekday, hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Aaj ka [hour]:[minute]; guzar chuka ho to kal ka.
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Agla [weekday] (misal Jumma) us waqt par.
  static tz.TZDateTime _nextInstanceOfWeekday(
    int weekday,
    int hour,
    int minute,
  ) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
