import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quran ka matn alquran.cloud se laata hai.
///
/// Lambi surahein app ke andar likhi hui nahi hain. Quran ka matn hamesha
/// kisi mustanad source se aana chahiye — ek harf ka farq bhi qabool nahi.
/// Pehli dafa internet se aata hai, phir phone par mehfooz ho jata hai, is
/// liye baad mein offline bhi khulta hai.
///
/// Urdu tarjuma `ur.jalandhry` (Fateh Muhammad Jalandhry) hai — wahi jo
/// app ki pehle se maujood surahon mein istemal hua hai.
class QuranApiService {
  static const String arabicEdition = 'quran-uthmani';
  static const String urduEdition = 'ur.jalandhry';

  /// Cache ki shakl badle to ye number barha dena — purana cache khud
  /// nazar-andaz ho jayega.
  static const int _cacheVersion = 1;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.alquran.cloud/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
  ));

  /// Surah ki aayaat `{'arabic': ..., 'urdu': ...}` ki shakl mein — wahi
  /// shakl jo `SurahDetailScreen` pehle se samajhti hai.
  ///
  /// [forceRefresh] `true` ho to cache nazar-andaz karke naya matn laata hai.
  Future<List<Map<String, String>>> getSurah(
    int surahNumber, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _readCache(surahNumber);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final verses = await _fetch(surahNumber);
    await _writeCache(surahNumber, verses);
    return verses;
  }

  /// Kya ye surah pehle se phone par mehfooz hai.
  Future<bool> isCached(int surahNumber) async {
    final cached = await _readCache(surahNumber);
    return cached != null && cached.isNotEmpty;
  }

  // ------------------------------------------------------------------
  // Network
  // ------------------------------------------------------------------

  Future<List<Map<String, String>>> _fetch(int surahNumber) async {
    final Response response;
    try {
      response = await _dio.get('/surah/$surahNumber/editions/'
          '$arabicEdition,$urduEdition');
    } on DioException catch (e) {
      throw Exception(
        'Quran ka matn download nahi ho saka. Internet check kijiye. (${e.type.name})',
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Quran server ne jawab nahi diya (${response.statusCode}).');
    }

    final data = response.data is Map ? response.data['data'] : null;
    if (data is! List || data.length < 2) {
      throw Exception('Quran server se adhoora jawab mila.');
    }

    final arabicAyahs = _ayahsOf(data, arabicEdition);
    final urduAyahs = _ayahsOf(data, urduEdition);

    if (arabicAyahs.isEmpty) {
      throw Exception('Quran server se koi aayat nahi mili.');
    }

    final verses = <Map<String, String>>[];
    for (var i = 0; i < arabicAyahs.length; i++) {
      verses.add({
        'arabic': arabicAyahs[i],
        'urdu': i < urduAyahs.length ? urduAyahs[i] : '',
      });
    }
    return verses;
  }

  /// Response mein editions ki tarteeb tay nahi hoti, is liye identifier
  /// se dhoondte hain — na mile to tarteeb par bharosa kar lete hain.
  List<String> _ayahsOf(List<dynamic> editions, String identifier) {
    Map<String, dynamic>? match;

    for (final e in editions) {
      if (e is Map<String, dynamic> &&
          e['edition'] is Map &&
          e['edition']['identifier'] == identifier) {
        match = e;
        break;
      }
    }

    match ??= identifier == arabicEdition
        ? (editions.first as Map<String, dynamic>?)
        : (editions.last as Map<String, dynamic>?);

    final ayahs = match?['ayahs'];
    if (ayahs is! List) return const [];

    return ayahs
        .map((a) => (a is Map && a['text'] is String) ? a['text'] as String : '')
        .toList();
  }

  // ------------------------------------------------------------------
  // Cache
  // ------------------------------------------------------------------

  String _cacheKey(int surahNumber) => 'quran_surah_${surahNumber}_v$_cacheVersion';

  Future<List<Map<String, String>>?> _readCache(int surahNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(surahNumber));
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      return decoded
          .whereType<Map>()
          .map((m) => {
                'arabic': (m['arabic'] ?? '').toString(),
                'urdu': (m['urdu'] ?? '').toString(),
              })
          .toList();
    } catch (_) {
      // Kharab cache ko chup-chaap nazar-andaz — network se dobara aa jayega.
      return null;
    }
  }

  Future<void> _writeCache(
      int surahNumber, List<Map<String, String>> verses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(surahNumber), jsonEncode(verses));
    } catch (_) {
      // Cache na ho saka to koi baat nahi — matn phir bhi dikh raha hai.
    }
  }
}
