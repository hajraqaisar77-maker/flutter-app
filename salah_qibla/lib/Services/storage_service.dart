import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_settings.dart';

class StorageService {
  static const String _duaCountKey = 'dua_count';
  static const String _cityKey = 'selected_city';
  static const String _reminderSettingsKey = 'reminder_settings';
  static const String _lastIshaKey = 'last_isha_time';

  // ========== LAST KNOWN ISHA ==========
  /// Aakhri maloom Isha ka waqt ("HH:mm").
  ///
  /// Settings screen ko "Isha ke baad" wale reminder ka waqt dikhane ke
  /// liye chahiye hota hai, jab prayer times abhi load na hue hon.
  Future<void> saveLastIshaTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastIshaKey, time);
  }

  Future<String?> getLastIshaTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastIshaKey);
  }

  // ========== REMINDER SETTINGS ==========
  Future<ReminderSettings> getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderSettingsKey);
    if (raw == null) return const ReminderSettings();
    return ReminderSettings.fromJson(raw);
  }

  Future<void> saveReminderSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderSettingsKey, settings.toJson());
  }

  // ========== DUA COUNTER ==========
  Future<int> getDuaCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_duaCountKey) ?? 0;
  }

  Future<void> incrementDuaCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_duaCountKey) ?? 0;
    await prefs.setInt(_duaCountKey, current + 1);
  }

  Future<void> resetDuaCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_duaCountKey);
  }

  // ========== CITY ==========
  Future<void> saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
  }

  Future<String?> getCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityKey);
  }

  // ========== PRAYER RECORDS (JSON Version) ==========
  Future<void> savePrayerRecord(String date, Map<String, bool> prayers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(prayers);
    await prefs.setString('prayer_$date', jsonString);
  }

  Future<Map<String, bool>?> getTodayRecord(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('prayer_$date');
    if (jsonString == null) return null;

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((key, value) => MapEntry(key, value as bool));
    } catch (e) {
      return null;
    }
  }

  Future<void> updatePrayerStatus(String date, String prayerName, bool isRead) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'prayer_$date';
    final existing = prefs.getString(key);
    
    Map<String, bool> prayers = {};
    
    if (existing != null) {
      try {
        prayers = Map<String, bool>.from(jsonDecode(existing));
      } catch (e) {
        prayers = {};
      }
    }
    
    prayers[prayerName] = isRead;
    await prefs.setString(key, jsonEncode(prayers));
  }

  Future<Map<String, Map<String, bool>>> getMonthlyRecords(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, bool>> result = {};
    
    final daysInMonth = DateTime(year, month + 1, 0).day;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final key = 'prayer_$date';
      final jsonString = prefs.getString(key);
      
      if (jsonString != null) {
        try {
          final prayers = Map<String, bool>.from(jsonDecode(jsonString));
          result[date] = prayers;
        } catch (e) {
          // Skip invalid data
        }
      }
    }
    
    return result;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}