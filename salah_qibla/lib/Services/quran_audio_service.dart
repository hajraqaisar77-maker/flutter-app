import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player ki maujooda halat — UI isi ko sun kar apne aap ko badalta hai.
class QuranAudioState {
  const QuranAudioState({
    this.surah,
    this.ayahIndex = 0,
    this.ayahCount = 0,
    this.playing = false,
    this.loading = false,
    this.error,
  });

  final int? surah;

  /// Kaun si aayat baj rahi hai (0 se shuru).
  final int ayahIndex;
  final int ayahCount;
  final bool playing;
  final bool loading;
  final String? error;

  /// Insaan ke parhne ke liye — "3 / 83".
  String get progressLabel =>
      ayahCount == 0 ? '--' : '${ayahIndex + 1} / $ayahCount';
}

/// Quran ki tilawat — **aayat ba aayat**.
///
/// Pehle poori surah ki ek hi MP3 stream hoti thi. `cdn.islamic.network`
/// par wo sirf 128 kbps mein maujood hai, jis se Yaseen **16.7 MB** ki
/// banti hai — dheeme connection par wo buffer hi nahi hoti aur tilawat
/// kabhi shuru nahi hoti. Emulator par yehi hote dekha gaya.
///
/// Ab har aayat alag file hai (64 kbps par ~280 KB), is liye tilawat ek
/// do second mein shuru ho jati hai. Ek aayat khatam hote hi agli khud
/// chal padti hai, to sunne mein farq mehsoos nahi hota.
class QuranAudioService {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal() {
    // Ek aayat khatam — agli chala do.
    _player.onPlayerComplete.listen((_) => _playNext());
  }

  static const String reciter = 'ar.alafasy';

  /// Aayat ki audio ka bitrate. 128 bhi maujood hai magar file dugni ho
  /// jati hai; tilawat 64 par bilkul saaf sunai deti hai.
  static const int bitrate = 64;

  static const int _cacheVersion = 1;

  final AudioPlayer _player = AudioPlayer();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.alquran.cloud/v1',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 45),
  ));

  final StreamController<QuranAudioState> _states =
      StreamController<QuranAudioState>.broadcast();

  /// UI isay sun kar apni halat badalti hai.
  Stream<QuranAudioState> get onState => _states.stream;

  List<String> _urls = const [];
  int _index = 0;
  int? _surah;
  bool _playing = false;
  bool _loading = false;
  String? _error;

  QuranAudioState get state => QuranAudioState(
        surah: _surah,
        ayahIndex: _index,
        ayahCount: _urls.length,
        playing: _playing,
        loading: _loading,
        error: _error,
      );

  int? get currentSurah => _surah;
  bool get isPlaying => _playing;

  void _emit() {
    if (!_states.isClosed) _states.add(state);
  }

  // ------------------------------------------------------------------
  // Chalana / rokna
  // ------------------------------------------------------------------

  /// Surah chalata hai. Wahi surah ruki hui ho to wahin se chal padti hai.
  Future<void> play(int surahNumber) async {
    if (_surah == surahNumber && _urls.isNotEmpty && !_playing) {
      _playing = true;
      _error = null;
      _emit();
      await _player.resume();
      return;
    }

    if (_surah == surahNumber && _playing) return;

    _surah = surahNumber;
    _index = 0;
    _urls = const [];
    _playing = false;
    _loading = true;
    _error = null;
    _emit();

    try {
      _urls = await _ayahUrls(surahNumber);
    } catch (e) {
      _loading = false;
      _error = 'Tilawat ki list nahi mil saki — internet check kijiye';
      _emit();
      return;
    }

    if (_urls.isEmpty) {
      _loading = false;
      _error = 'Is surah ki tilawat maujood nahi';
      _emit();
      return;
    }

    await _playCurrent();
  }

  Future<void> pause() async {
    _playing = false;
    _emit();
    await _player.pause();
  }

  Future<void> stop() async {
    _playing = false;
    _loading = false;
    _index = 0;
    _surah = null;
    _urls = const [];
    _error = null;
    _emit();
    await _player.stop();
  }

  /// Agli aayat par chhalang.
  Future<void> next() async {
    if (_urls.isEmpty || _index >= _urls.length - 1) return;
    _index++;
    await _playCurrent();
  }

  /// Pichhli aayat par wapas.
  Future<void> previous() async {
    if (_urls.isEmpty || _index == 0) return;
    _index--;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_index < 0 || _index >= _urls.length) return;

    _loading = true;
    _error = null;
    _emit();

    try {
      await _player.stop();
      await _player.play(UrlSource(_urls[_index]));
      _loading = false;
      _playing = true;
    } catch (e) {
      _loading = false;
      _playing = false;
      _error = 'Aayat ${_index + 1} nahi chal saki';
    }
    _emit();
  }

  /// Aayat khatam hone par khud chalta hai.
  Future<void> _playNext() async {
    if (!_playing || _urls.isEmpty) return;

    if (_index >= _urls.length - 1) {
      // Surah mukammal.
      _playing = false;
      _index = 0;
      _emit();
      return;
    }

    _index++;
    await _playCurrent();
  }

  // ------------------------------------------------------------------
  // Aayat ke URLs — API se, phir phone par mehfooz
  // ------------------------------------------------------------------

  Future<List<String>> _ayahUrls(int surahNumber) async {
    final cached = await _readCache(surahNumber);
    if (cached != null && cached.isNotEmpty) return cached;

    // Ye jawab sirf ~35 KB ka hota hai (matn nahi, sirf audio ke links).
    final response = await _dio.get('/surah/$surahNumber/$reciter');
    final ayahs = response.data?['data']?['ayahs'];
    if (ayahs is! List) {
      throw Exception('Tilawat ki list samajh nahi aayi');
    }

    final urls = <String>[];
    for (final a in ayahs) {
      if (a is Map && a['audio'] is String) {
        urls.add(_atBitrate(a['audio'] as String));
      }
    }

    await _writeCache(surahNumber, urls);
    return urls;
  }

  /// API 128 kbps ka link deta hai; usay chhote bitrate par le aate hain.
  /// Shakl badal jaye to link waise hi rehne dete hain.
  static String _atBitrate(String url) {
    const from = '/audio/128/';
    const to = '/audio/$bitrate/';
    return url.contains(from) ? url.replaceFirst(from, to) : url;
  }

  String _cacheKey(int surah) =>
      'quran_audio_${surah}_${reciter}_${bitrate}_v$_cacheVersion';

  Future<List<String>?> _readCache(int surah) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(surah));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(int surah, List<String> urls) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(surah), jsonEncode(urls));
    } catch (_) {
      // Cache na ho saka to koi harj nahi.
    }
  }
}
