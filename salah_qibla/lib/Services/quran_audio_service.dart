import 'package:audioplayers/audioplayers.dart';

/// Quran ki tilawat online stream karta hai.
///
/// Tilawat ki files app ke andar nahi rakhi gayin — ek surah 20-40 MB ki
/// hoti hai, sab daal dete to app bhaari ho jata. Iske bajaye
/// `cdn.islamic.network` se stream hoti hai (wahi khandan jahan se matn
/// aata hai), qari **Mishary Rashid Alafasy**.
///
/// Poore app mein ek hi player chalta hai, is liye do surahein ek saath
/// nahi baj saktin.
class QuranAudioService {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  /// Qari ki pehchan — `cdn.islamic.network` ke edition ids.
  static const String reciter = 'ar.alafasy';
  static const int _bitrate = 128;

  int? _currentSurah;

  /// Is waqt kaun si surah lagi hui hai (chal rahi ho ya ruki hui).
  int? get currentSurah => _currentSurah;

  bool get isPlaying => _player.state == PlayerState.playing;

  Stream<PlayerState> get onStateChanged => _player.onPlayerStateChanged;
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  static String urlFor(int surahNumber) =>
      'https://cdn.islamic.network/quran/audio-surah/$_bitrate/$reciter/$surahNumber.mp3';

  /// Surah bajata hai. Wahi surah dobara maangi jaye jo ruki hui thi to
  /// wahin se chal padti hai, shuru se nahi.
  Future<void> play(int surahNumber) async {
    if (_currentSurah == surahNumber && _player.state == PlayerState.paused) {
      await _player.resume();
      return;
    }

    await _player.stop();
    _currentSurah = surahNumber;
    await _player.play(UrlSource(urlFor(surahNumber)));
  }

  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    await _player.stop();
    _currentSurah = null;
  }

  Future<void> seek(Duration position) => _player.seek(position);

  /// mm:ss ki shakl — player ke neeche waqt dikhane ke liye.
  static String formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
