import 'dart:async';

import 'package:flutter/material.dart';

import '../services/quran_audio_service.dart';

const Color _brandGreen = Color(0xFF1B5E20);

/// Surah ki tilawat ka player — screen ke neeche lagta hai.
///
/// Tilawat aayat ba aayat chalti hai (dekhiye [QuranAudioService]), is liye
/// ek do second mein shuru ho jati hai. Har aayat khatam hote hi agli khud
/// chal padti hai.
class SurahAudioBar extends StatefulWidget {
  const SurahAudioBar({super.key, required this.surahNumber});

  final int surahNumber;

  @override
  State<SurahAudioBar> createState() => _SurahAudioBarState();
}

class _SurahAudioBarState extends State<SurahAudioBar> {
  final QuranAudioService _audio = QuranAudioService();

  StreamSubscription<QuranAudioState>? _sub;
  QuranAudioState _state = const QuranAudioState();

  @override
  void initState() {
    super.initState();
    _state = _audio.state;
    _sub = _audio.onState.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    // Screen chhorte hi tilawat band — warna peechhe bajti rehti hai.
    _audio.stop();
    super.dispose();
  }

  /// Kya is screen ki surah hi baj rahi hai.
  bool get _isMine => _state.surah == widget.surahNumber;

  Future<void> _toggle() async {
    if (_isMine && _state.playing) {
      await _audio.pause();
    } else {
      await _audio.play(widget.surahNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _isMine && _state.loading;
    final playing = _isMine && _state.playing;
    final error = _isMine ? _state.error : null;
    final count = _isMine ? _state.ayahCount : 0;
    final index = _isMine ? _state.ayahIndex : 0;
    final progress = count > 0 ? (index + 1) / count : 0.0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            Row(
              children: [
                // Play / pause / loading
                SizedBox(
                  width: 46,
                  height: 46,
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: _brandGreen),
                        )
                      : IconButton(
                          onPressed: _toggle,
                          iconSize: 34,
                          padding: EdgeInsets.zero,
                          color: _brandGreen,
                          icon: Icon(playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill),
                        ),
                ),

                // Pichhli aayat
                IconButton(
                  onPressed: (count > 0 && index > 0) ? _audio.previous : null,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34),
                  icon: const Icon(Icons.skip_previous),
                  color: Colors.grey.shade700,
                  tooltip: 'Pichhli aayat',
                ),

                // Agli aayat
                IconButton(
                  onPressed:
                      (count > 0 && index < count - 1) ? _audio.next : null,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34),
                  icon: const Icon(Icons.skip_next),
                  color: Colors.grey.shade700,
                  tooltip: 'Agli aayat',
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loading
                            ? 'Tilawat load ho rahi hai...'
                            : 'Tilawat — Mishary Alafasy',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.grey.shade300,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_brandGreen),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count > 0 ? 'Aayat ${index + 1} / $count' : 'Aayat --',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                if (count > 0)
                  IconButton(
                    onPressed: _audio.stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    color: Colors.grey.shade600,
                    tooltip: 'Band karo',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
