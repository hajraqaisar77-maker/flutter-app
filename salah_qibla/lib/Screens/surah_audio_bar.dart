import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:flutter/material.dart';

import '../services/quran_audio_service.dart';

const Color _brandGreen = Color(0xFF1B5E20);

/// Surah ki tilawat ka chhota player — screen ke neeche lagta hai.
///
/// Tilawat online stream hoti hai, is liye pehli dafa chalne mein do-teen
/// second lagte hain. Internet na ho to saaf paigham dikhata hai.
class SurahAudioBar extends StatefulWidget {
  const SurahAudioBar({super.key, required this.surahNumber});

  final int surahNumber;

  @override
  State<SurahAudioBar> createState() => _SurahAudioBarState();
}

class _SurahAudioBarState extends State<SurahAudioBar> {
  final QuranAudioService _audio = QuranAudioService();

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _stateSub = _audio.onStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state == PlayerState.playing;
        if (state == PlayerState.playing) _loading = false;
        if (state == PlayerState.completed) _position = Duration.zero;
      });
    });

    _posSub = _audio.onPositionChanged.listen((d) {
      if (mounted) setState(() => _position = d);
    });

    _durSub = _audio.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    // Screen chhorte hi tilawat band — warna peechhe bajti rehti hai.
    _audio.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    setState(() => _error = null);
    try {
      if (_playing) {
        await _audio.pause();
      } else {
        setState(() => _loading = true);
        await _audio.play(widget.surahNumber);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Tilawat nahi chal saki — internet check kijiye';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds;
    final progress =
        total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: _brandGreen),
                        )
                      : IconButton(
                          onPressed: _toggle,
                          iconSize: 34,
                          color: _brandGreen,
                          icon: Icon(_playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill),
                        ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loading
                            ? 'Tilawat load ho rahi hai...'
                            : 'Tilawat — Mishary Alafasy',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
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
                        '${QuranAudioService.formatDuration(_position)}'
                        '  /  '
                        '${total > 0 ? QuranAudioService.formatDuration(_duration) : "--:--"}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (_playing || _position > Duration.zero)
                  IconButton(
                    onPressed: () async {
                      await _audio.stop();
                      if (mounted) {
                        setState(() {
                          _playing = false;
                          _position = Duration.zero;
                        });
                      }
                    },
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
