import 'dart:convert';

/// Kis tarah Surah Ar-Rahman ka rozana reminder ka waqt tay hoga.
enum RahmanReminderMode {
  /// User ka chuna hua fixed waqt, misal 10:00 PM.
  customTime,

  /// Aaj ke Isha ke azaan ke kuch minute baad.
  afterIsha,
}

/// App ke tamam reminders ki settings, ek jagah.
///
/// SharedPreferences mein JSON ki shakl mein mehfooz hoti hain, is liye
/// naye field barhane par purani settings toot-ti nahi — jo field nahi
/// milta uski default value le li jati hai.
class ReminderSettings {
  const ReminderSettings({
    this.azaanAlarmEnabled = true,
    this.prePrayerEnabled = true,
    this.prePrayerMinutes = 15,
    this.jummaEnabled = true,
    this.jummaHour = 10,
    this.jummaMinute = 0,
    this.kahfEnabled = true,
    this.kahfHour = 7,
    this.kahfMinute = 0,
    this.rahmanEnabled = false,
    this.rahmanMode = RahmanReminderMode.customTime,
    this.rahmanHour = 22,
    this.rahmanMinute = 0,
    this.rahmanMinutesAfterIsha = 30,
  });

  /// Namaz ke waqt asli azaan alarm ki tarah bajegi — app band ho tab bhi.
  ///
  /// Ye `AzaanAlarmService` chalata hai (Android ka apna AlarmManager), is
  /// liye phone locked ya app killed hone par bhi bajti hai.
  final bool azaanAlarmEnabled;

  /// Har namaz se pehle yaad-dihani.
  final bool prePrayerEnabled;

  /// Namaz se kitne minute pehle. Default 15.
  final int prePrayerMinutes;

  /// Jumma ke din khaas paigham.
  final bool jummaEnabled;
  final int jummaHour;
  final int jummaMinute;

  /// Jumma ko Surah Al-Kahf parhne ki yaad-dihani.
  final bool kahfEnabled;
  final int kahfHour;
  final int kahfMinute;

  /// Surah Ar-Rahman sunne ka rozana reminder.
  final bool rahmanEnabled;
  final RahmanReminderMode rahmanMode;

  /// [RahmanReminderMode.customTime] ke liye waqt.
  final int rahmanHour;
  final int rahmanMinute;

  /// [RahmanReminderMode.afterIsha] ke liye Isha ke baad ke minute.
  final int rahmanMinutesAfterIsha;

  ReminderSettings copyWith({
    bool? azaanAlarmEnabled,
    bool? prePrayerEnabled,
    int? prePrayerMinutes,
    bool? jummaEnabled,
    int? jummaHour,
    int? jummaMinute,
    bool? kahfEnabled,
    int? kahfHour,
    int? kahfMinute,
    bool? rahmanEnabled,
    RahmanReminderMode? rahmanMode,
    int? rahmanHour,
    int? rahmanMinute,
    int? rahmanMinutesAfterIsha,
  }) {
    return ReminderSettings(
      azaanAlarmEnabled: azaanAlarmEnabled ?? this.azaanAlarmEnabled,
      prePrayerEnabled: prePrayerEnabled ?? this.prePrayerEnabled,
      prePrayerMinutes: prePrayerMinutes ?? this.prePrayerMinutes,
      jummaEnabled: jummaEnabled ?? this.jummaEnabled,
      jummaHour: jummaHour ?? this.jummaHour,
      jummaMinute: jummaMinute ?? this.jummaMinute,
      kahfEnabled: kahfEnabled ?? this.kahfEnabled,
      kahfHour: kahfHour ?? this.kahfHour,
      kahfMinute: kahfMinute ?? this.kahfMinute,
      rahmanEnabled: rahmanEnabled ?? this.rahmanEnabled,
      rahmanMode: rahmanMode ?? this.rahmanMode,
      rahmanHour: rahmanHour ?? this.rahmanHour,
      rahmanMinute: rahmanMinute ?? this.rahmanMinute,
      rahmanMinutesAfterIsha:
          rahmanMinutesAfterIsha ?? this.rahmanMinutesAfterIsha,
    );
  }

  Map<String, dynamic> toMap() => {
        'azaanAlarmEnabled': azaanAlarmEnabled,
        'prePrayerEnabled': prePrayerEnabled,
        'prePrayerMinutes': prePrayerMinutes,
        'jummaEnabled': jummaEnabled,
        'jummaHour': jummaHour,
        'jummaMinute': jummaMinute,
        'kahfEnabled': kahfEnabled,
        'kahfHour': kahfHour,
        'kahfMinute': kahfMinute,
        'rahmanEnabled': rahmanEnabled,
        'rahmanMode': rahmanMode.name,
        'rahmanHour': rahmanHour,
        'rahmanMinute': rahmanMinute,
        'rahmanMinutesAfterIsha': rahmanMinutesAfterIsha,
      };

  factory ReminderSettings.fromMap(Map<String, dynamic> map) {
    const fallback = ReminderSettings();

    int readInt(String key, int orElse) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return orElse;
    }

    bool readBool(String key, bool orElse) {
      final value = map[key];
      return value is bool ? value : orElse;
    }

    return ReminderSettings(
      azaanAlarmEnabled:
          readBool('azaanAlarmEnabled', fallback.azaanAlarmEnabled),
      prePrayerEnabled:
          readBool('prePrayerEnabled', fallback.prePrayerEnabled),
      prePrayerMinutes:
          readInt('prePrayerMinutes', fallback.prePrayerMinutes),
      jummaEnabled: readBool('jummaEnabled', fallback.jummaEnabled),
      jummaHour: readInt('jummaHour', fallback.jummaHour),
      jummaMinute: readInt('jummaMinute', fallback.jummaMinute),
      kahfEnabled: readBool('kahfEnabled', fallback.kahfEnabled),
      kahfHour: readInt('kahfHour', fallback.kahfHour),
      kahfMinute: readInt('kahfMinute', fallback.kahfMinute),
      rahmanEnabled: readBool('rahmanEnabled', fallback.rahmanEnabled),
      rahmanMode: RahmanReminderMode.values.firstWhere(
        (mode) => mode.name == map['rahmanMode'],
        orElse: () => fallback.rahmanMode,
      ),
      rahmanHour: readInt('rahmanHour', fallback.rahmanHour),
      rahmanMinute: readInt('rahmanMinute', fallback.rahmanMinute),
      rahmanMinutesAfterIsha:
          readInt('rahmanMinutesAfterIsha', fallback.rahmanMinutesAfterIsha),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ReminderSettings.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return ReminderSettings.fromMap(decoded);
      }
    } catch (_) {
      // Kharab data mile to defaults par wapas — settings ki wajah se
      // app kabhi crash nahi honi chahiye.
    }
    return const ReminderSettings();
  }

  /// "22:00" jaisi shakl, UI aur notification ke matn dono ke liye.
  static String formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// "10:00 PM" jaisi shakl.
  static String formatTime12h(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }
}
