class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String date;
  final String hijriDate;

  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    required this.hijriDate,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    final timings = json['timings'];
    final dateData = json['date'];
    return PrayerTimes(
      fajr: timings['Fajr']?.substring(0, 5) ?? '--:--',
      sunrise: timings['Sunrise']?.substring(0, 5) ?? '--:--',
      dhuhr: timings['Dhuhr']?.substring(0, 5) ?? '--:--',
      asr: timings['Asr']?.substring(0, 5) ?? '--:--',
      maghrib: timings['Maghrib']?.substring(0, 5) ?? '--:--',
      isha: timings['Isha']?.substring(0, 5) ?? '--:--',
      date: dateData['readable'] ?? '',
      hijriDate: dateData['hijri']['date'] ?? '',
    );
  }
}

class PrayerRecord {
  final String date;
  bool fajr;
  bool dhuhr;
  bool asr;
  bool maghrib;
  bool isha;

  PrayerRecord({
    required this.date,
    this.fajr = false,
    this.dhuhr = false,
    this.asr = false,
    this.maghrib = false,
    this.isha = false,
  });

  Map<String, bool> toMap() {
    return {
      'fajr': fajr,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
    };
  }

  factory PrayerRecord.fromMap(Map<String, dynamic> map) {
    return PrayerRecord(
      date: map['date'] ?? '',
      fajr: map['fajr'] ?? false,
      dhuhr: map['dhuhr'] ?? false,
      asr: map['asr'] ?? false,
      maghrib: map['maghrib'] ?? false,
      isha: map['isha'] ?? false,
    );
  }
}
