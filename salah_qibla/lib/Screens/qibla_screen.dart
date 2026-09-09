import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

// ---------------------------------------------------------------------
//  QIBLA SCREEN
//  Upper half  : live Qibla compass (rotating dial + needle + Kaaba badge)
//  Lower half  : tappable map preview of the user's own city
//  Tap the map : opens the full interactive map (QiblaMapScreen)
//
//  Install with:
//    flutter pub add flutter_compass geolocator flutter_map latlong2 http
//
//  Any geolocator version from 11 upwards works — this file deliberately
//  calls getCurrentPosition() with no arguments, because the accuracy
//  parameter was renamed between majors.
//
//  Android — android/app/src/main/AndroidManifest.xml, inside <manifest>:
//    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//    <uses-permission android:name="android.permission.INTERNET"/>
//
//  iOS — ios/Runner/Info.plist:
//    <key>NSLocationWhenInUseUsageDescription</key>
//    <string>Qibla direction aur aap ki city ka map dikhane ke liye.</string>
//
//  Maps are OpenStreetMap: free, no API key, no billing account. See the
//  note on `_kTileUserAgent` below — it is the one value you must change.
// ---------------------------------------------------------------------

/// Kaaba, Masjid al-Haram, Makkah.
const double _kKaabaLat = 21.4224779;
const double _kKaabaLng = 39.8251832;

const String _kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Sent to OpenStreetMap as `User-Agent: flutter_map (<this>)`.
///
/// CHANGE THIS to your real application id — the `applicationId` in
/// android/app/build.gradle. OpenStreetMap serves a "403 Access blocked"
/// image instead of a map to apps identifying as `unknown` or
/// `com.example.app`, and the whole `com.example.*` space is the first
/// thing they tighten when they clamp down. A real id keeps the map safe.
const String _kTileUserAgent = 'pk.mhash.islamicapp';

/// How long the dial/needle take to settle on a new heading.
const Duration _kSpin = Duration(milliseconds: 320);

/// Facing counts as "on Qibla" within this many degrees.
const double _kAlignToleranceDeg = 6;

/// App palette — one place to restyle the whole screen.
class _QC {
  static const primary = Color(0xFF0E9E8B);
  static const primaryDark = Color(0xFF07695E);
  static const gold = Color(0xFFD9A441);
  static const success = Color(0xFF19A463);
  static const bg = Color(0xFFF3FAF8);
  static const ink = Color(0xFF0E2B27);
  static const inkSoft = Color(0xFF6C8B87);
  static const line = Color(0xFFDCEAE7);
}

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _sensorTimeout;

  Position? _position;
  double? _heading; // live device heading, degrees from true north
  double? _qiblaBearing; // bearing user -> Kaaba, degrees from true north
  double? _distanceKm;

  String? _cityLabel; // "Lahore"
  String? _regionLabel; // "Punjab, Pakistan"

  bool _loading = true;
  String? _error;

  /// No magnetometer reading available (web, desktop, sensor-less device).
  /// Bearing and distance stay correct; only the live rotation is lost.
  bool _noSensor = false;
  bool _wasAligned = false;

  // Continuous (un-wrapped) rotation targets, in turns. Keeping them
  // un-wrapped is what makes 359° -> 1° animate 2° forward instead of
  // spinning the long way around.
  double _dialTurns = 0;
  double _needleTurns = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _sensorTimeout?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------- setup

  Future<void> _init() async {
    try {
      final denial = await _locationBlockedReason();
      if (denial != null) {
        if (!mounted) return;
        setState(() {
          _error = denial;
          _loading = false;
        });
        return;
      }

      // No arguments on purpose: geolocator renamed this method's accuracy
      // parameter between majors (`desiredAccuracy:` -> `locationSettings:`),
      // so passing either one pins this file to one version range.
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _position = position;
        _qiblaBearing = _bearingToKaaba(position.latitude, position.longitude);
        _distanceKm = _distanceToKaabaKm(position.latitude, position.longitude);
        _loading = false;
      });

      _startCompass();
      _resolveCity(position); // fire and forget — map works without it
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Location nahi mil saki. Dobara koshish karein.\n\n$e';
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
      _noSensor = false;
      _heading = null;
    });
    _compassSub?.cancel();
    _sensorTimeout?.cancel();
    _init();
  }

  /// Returns a user-facing reason when location can't be used, else null.
  Future<String?> _locationBlockedReason() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Phone ki Location (GPS) band hai. '
          'Settings mein jaa kar location on karein.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Qibla direction nikalne ke liye location ki ijazat chahiye.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission hamesha ke liye block hai. '
          'App Settings mein jaa kar ise allow karein.';
    }
    return null;
  }

  void _startCompass() {
    // Web has no magnetometer plugin support at all — don't even listen.
    final events = kIsWeb ? null : FlutterCompass.events;
    if (events == null) {
      setState(() {
        _noSensor = true;
        _applyHeading(null);
      });
      return;
    }

    _compassSub = events.listen(
      (event) {
        final h = event.heading;
        if (h == null || !mounted) return;
        _sensorTimeout?.cancel();

        // The sensor fires ~50x a second; ignore sub-degree jitter so we
        // aren't rebuilding (and restarting the animation) on noise.
        if (_heading != null && _shortestDeltaDeg(_heading!, h).abs() < 0.8) {
          return;
        }
        setState(() {
          _noSensor = false;
          _applyHeading(h);
        });
      },
      onError: (Object _) {
        if (!mounted) return;
        setState(() {
          _noSensor = true;
          _applyHeading(null);
        });
      },
    );

    // Some devices expose the stream but never emit. Give up after a few
    // seconds and show the static bearing instead of an empty dial.
    _sensorTimeout = Timer(const Duration(seconds: 4), () {
      if (!mounted || _heading != null) return;
      setState(() {
        _noSensor = true;
        _applyHeading(null);
      });
    });
  }

  /// Asks OpenStreetMap's Nominatim which city these coordinates fall in.
  ///
  /// Deliberately not the `geocoding` plugin: its API changed shape between
  /// majors (top-level function -> instance method), so a file using it only
  /// compiles against one version range. A plain HTTPS call has no such
  /// problem, works on Android, iOS and web alike, and when it fails the
  /// screen simply shows coordinates instead of a name.
  Future<void> _resolveCity(Position p) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '${p.latitude}',
        'lon': '${p.longitude}',
        'zoom': '10', // city level
        'accept-language': 'en',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': _kTileUserAgent
      }).timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return;
      final address = decoded['address'];
      if (address is! Map) return;

      String? field(String key) {
        final v = address[key];
        return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
      }

      // Nominatim is not consistent about which key holds the city, so walk
      // down the administrative chain until something turns up.
      String? city;
      for (final key in const [
        'city',
        'town',
        'municipality',
        'city_district',
        'district',
        'county',
        'state_district',
        'subdistrict',
        'village',
        'suburb',
      ]) {
        city = field(key);
        if (city != null) break;
      }
      city = _trimAdminSuffix(city);

      final region = <String>{};
      final state = _trimAdminSuffix(field('state'));
      final country = field('country');
      if (state != null) region.add(state);
      if (country != null) region.add(country);
      region.remove(city);

      if (!mounted) return;
      setState(() {
        _cityLabel = city;
        _regionLabel = region.isEmpty ? null : region.join(', ');
      });
    } catch (_) {
      // Offline, rate limited, or an unfamiliar response shape. The compass
      // and map are unaffected; the caption falls back to coordinates.
    }
  }

  // ------------------------------------------------------------ heading

  /// Feeds a new heading into both rotations, taking the short way round.
  void _applyHeading(double? headingDeg) {
    _heading = headingDeg;
    final h = headingDeg ?? 0;

    // Dial spins against the device so North keeps pointing at real north.
    _dialTurns = _shortestTurns(_dialTurns, -h / 360);
    if (_qiblaBearing != null) {
      _needleTurns = _shortestTurns(_needleTurns, (_qiblaBearing! - h) / 360);
    }

    final aligned = _isAligned;
    if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
    _wasAligned = aligned;
  }

  bool get _isAligned {
    if (_noSensor || _heading == null || _qiblaBearing == null) return false;
    return _shortestDeltaDeg(_heading!, _qiblaBearing!).abs() <=
        _kAlignToleranceDeg;
  }

  // --------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _QC.bg,
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _retry)
              : Column(
                  children: [
                    Expanded(flex: 55, child: _compassHalf()),
                    Expanded(flex: 45, child: _mapHalf()),
                  ],
                ),
    );
  }

  Widget _compassHalf() {
    return Container(
      width: double.infinity,
      // antiAlias so the dial's glow is trimmed by the panel's rounded
      // corners instead of bleeding onto the map below.
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_QC.primaryDark, _QC.primary],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  // Leave a margin so the glow around the dial has somewhere
                  // to fall instead of being cut off at the panel edge.
                  final d = math.min(c.maxWidth - 72, c.maxHeight - 44);
                  // FittedBox keeps the dial from overflowing on very short
                  // screens (landscape, split-screen) instead of throwing.
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _dial(math.max(d, 140)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _statsBar(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final aligned = _isAligned;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            const BackButton(color: Colors.white)
          else
            const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Qibla Direction',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          _statusChip(aligned),
        ],
      ),
    );
  }

  Widget _statusChip(bool aligned) {
    final (Color dot, String label) = _noSensor
        ? (_QC.gold, 'No sensor')
        : aligned
            ? (const Color(0xFF7DF3B8), 'On Qibla')
            : (const Color(0xFF9BE7DC), 'Live');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dial(double d) {
    final aligned = _isAligned;
    final hasBearing = _qiblaBearing != null;

    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        // The glow and the facing marker both sit outside the d x d box.
        clipBehavior: Clip.none,
        children: [
          // Soft halo, brighter the moment you line up with the Qibla.
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (aligned ? _QC.success : Colors.black)
                      .withValues(alpha: aligned ? 0.42 : 0.18),
                  blurRadius: aligned ? 26 : 16,
                ),
              ],
            ),
          ),

          // The dial itself, counter-rotating against the device heading.
          AnimatedRotation(
            turns: _dialTurns,
            duration: _kSpin,
            curve: Curves.easeOut,
            child: CustomPaint(
              size: Size.square(d),
              painter: const _DialPainter(),
            ),
          ),

          // Needle: points at the Qibla relative to where you're facing.
          if (hasBearing)
            AnimatedRotation(
              turns: _needleTurns,
              duration: _kSpin,
              curve: Curves.easeOut,
              child: CustomPaint(
                size: Size.square(d),
                painter: _NeedlePainter(
                  color: aligned ? _QC.success : _QC.primary,
                ),
              ),
            ),

          // Kaaba badge riding the rim at the same angle as the needle.
          // The inner AnimatedRotation cancels the outer one so the icon
          // stays upright for the whole animation, not just at the end.
          if (hasBearing)
            AnimatedRotation(
              turns: _needleTurns,
              duration: _kSpin,
              curve: Curves.easeOut,
              child: SizedBox(
                width: d,
                height: d,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedRotation(
                    turns: -_needleTurns,
                    duration: _kSpin,
                    curve: Curves.easeOut,
                    child: _kaabaBadge(aligned, d),
                  ),
                ),
              ),
            ),

          _centerHub(d),

          // Fixed reference mark — "this is where the phone is pointing".
          Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -d * 0.035),
              child: _facingMarker(aligned, d),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kaabaBadge(bool aligned, double d) {
    final color = aligned ? _QC.success : _QC.primaryDark;
    final s = (d * 0.155).clamp(28.0, 42.0);
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: s * 0.055),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.mosque, size: s * 0.52, color: color),
    );
  }

  Widget _facingMarker(bool aligned, double d) {
    final w = (d * 0.06).clamp(13.0, 20.0);
    return CustomPaint(
      size: Size(w, w * 0.66),
      painter: _TrianglePainter(
        color: aligned ? const Color(0xFF7DF3B8) : Colors.white,
      ),
    );
  }

  Widget _centerHub(double d) {
    final h = _heading;
    final s = (d * 0.30).clamp(58.0, 92.0);
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            h == null ? '--°' : '${h.round() % 360}°',
            style: TextStyle(
              fontSize: (s * 0.27).clamp(15.0, 26.0),
              fontWeight: FontWeight.w700,
              color: _QC.ink,
              height: 1.1,
            ),
          ),
          SizedBox(height: s * 0.02),
          Text(
            h == null ? 'NO SENSOR' : _compassPoint(h),
            style: TextStyle(
              fontSize: (s * 0.105).clamp(7.0, 10.5),
              fontWeight: FontWeight.w700,
              color: _QC.inkSoft,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsBar() {
    final acc = _position?.accuracy;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _stat(
              Icons.explore_outlined,
              'Qibla',
              _qiblaBearing == null
                  ? '--'
                  : '${_qiblaBearing!.toStringAsFixed(1)}°',
            ),
          ),
          _statDivider(),
          Expanded(
            child: _stat(
              Icons.straighten_rounded,
              'Makkah',
              _distanceKm == null ? '--' : _formatKm(_distanceKm!),
            ),
          ),
          _statDivider(),
          Expanded(
            child: _stat(
              Icons.gps_fixed_rounded,
              'GPS',
              acc == null ? '--' : '±${acc.round()} m',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 30,
        color: Colors.white.withValues(alpha: 0.20),
      );

  Widget _stat(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- map half

  Widget _mapHalf() {
    final pos = _position;
    if (pos == null) return const SizedBox.shrink();
    final me = LatLng(pos.latitude, pos.longitude);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Static preview: interaction is off so the tap below always
            // wins instead of being eaten by a pan gesture.
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: me,
                  initialZoom: 12.5,
                  // Shown while tiles load, and if the phone is offline —
                  // reads as "map" rather than as a broken grey box.
                  backgroundColor: const Color(0xFFE8F1EF),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _kTileUrl,
                    userAgentPackageName: _kTileUserAgent,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: me,
                        width: 46,
                        height: 46,
                        child: const _MeMarker(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrim so the label stays readable over any map tile.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.06),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0.35, 0.6, 1],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: IgnorePointer(child: _mapCaption()),
            ),

            // Whole card is the tap target.
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openFullMap,
                  splashColor: Colors.white.withValues(alpha: 0.18),
                  highlightColor: Colors.white.withValues(alpha: 0.06),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapCaption() {
    final pos = _position!;
    final title = _cityLabel ??
        '${pos.latitude.toStringAsFixed(3)}, '
            '${pos.longitude.toStringAsFixed(3)}';
    final subtitle = _cityLabel == null
        ? 'Aap ki maujooda location'
        : (_regionLabel ?? 'Aap ki maujooda location');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.place, color: Colors.white, size: 17),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.5,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 15, color: _QC.primaryDark),
              SizedBox(width: 5),
              Text(
                'Map kholein',
                style: TextStyle(
                  color: _QC.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openFullMap() {
    final pos = _position;
    if (pos == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QiblaMapScreen(
          me: LatLng(pos.latitude, pos.longitude),
          cityLabel: _cityLabel,
          regionLabel: _regionLabel,
          qiblaBearing: _qiblaBearing ?? 0,
          distanceKm: _distanceKm ?? 0,
        ),
      ),
    );
  }
}

// =====================================================================
//  FULL SCREEN MAP
// =====================================================================

class QiblaMapScreen extends StatefulWidget {
  const QiblaMapScreen({
    super.key,
    required this.me,
    required this.qiblaBearing,
    required this.distanceKm,
    this.cityLabel,
    this.regionLabel,
  });

  final LatLng me;
  final double qiblaBearing;
  final double distanceKm;
  final String? cityLabel;
  final String? regionLabel;

  @override
  State<QiblaMapScreen> createState() => _QiblaMapScreenState();
}

class _QiblaMapScreenState extends State<QiblaMapScreen> {
  final _map = MapController();
  static const _kaaba = LatLng(_kKaabaLat, _kKaabaLng);

  bool _showQiblaLine = true;

  void _centerOnMe() => _map.move(widget.me, 14);

  void _fitBoth() {
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([widget.me, _kaaba]),
        padding: const EdgeInsets.fromLTRB(48, 90, 48, 190),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.cityLabel ?? 'Aap ki Location';

    return Scaffold(
      backgroundColor: _QC.bg,
      appBar: AppBar(
        backgroundColor: _QC.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (widget.regionLabel != null)
              Text(
                widget.regionLabel!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showQiblaLine
                ? 'Qibla line chupayein'
                : 'Qibla line dikhayein',
            icon: Icon(
              _showQiblaLine ? Icons.timeline : Icons.timeline_outlined,
              color: _showQiblaLine ? const Color(0xFF7DF3B8) : Colors.white,
            ),
            onPressed: () => setState(() => _showQiblaLine = !_showQiblaLine),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.me,
              initialZoom: 13,
              minZoom: 2,
              maxZoom: 18,
              backgroundColor: const Color(0xFFE8F1EF),
            ),
            children: [
              TileLayer(
                urlTemplate: _kTileUrl,
                userAgentPackageName: _kTileUserAgent,
              ),
              if (_showQiblaLine)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _greatCircle(widget.me, _kaaba),
                      color: _QC.primary,
                      strokeWidth: 3.5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.me,
                    width: 54,
                    height: 54,
                    child: const _MeMarker(),
                  ),
                  const Marker(
                    point: _kaaba,
                    width: 92,
                    height: 62,
                    alignment: Alignment.topCenter,
                    child: _KaabaMarker(),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // Floating controls
          Positioned(
            right: 14,
            bottom: 168,
            child: Column(
              children: [
                _mapButton(
                  icon: Icons.my_location,
                  tooltip: 'Meri location',
                  onTap: _centerOnMe,
                ),
                const SizedBox(height: 10),
                _mapButton(
                  icon: Icons.zoom_out_map,
                  tooltip: 'Makkah tak poora rasta',
                  onTap: _fitBoth,
                ),
              ],
            ),
          ),

          Positioned(left: 0, right: 0, bottom: 0, child: _infoSheet()),
        ],
      ),
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: _QC.primaryDark, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _infoSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 18, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _QC.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _tile(
                    Icons.place_outlined,
                    'City',
                    widget.cityLabel ?? '--',
                  ),
                ),
                Expanded(
                  child: _tile(
                    Icons.explore_outlined,
                    'Qibla',
                    '${widget.qiblaBearing.toStringAsFixed(1)}°',
                  ),
                ),
                Expanded(
                  child: _tile(
                    Icons.straighten_rounded,
                    'Makkah',
                    _formatKm(widget.distanceKm),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _QC.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _QC.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop_outlined,
                      size: 16, color: _QC.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.me.latitude.toStringAsFixed(5)},  '
                      '${widget.me.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _QC.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: _QC.primary),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _QC.ink,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: _QC.inkSoft),
        ),
      ],
    );
  }
}

// =====================================================================
//  SMALL PIECES
// =====================================================================

class _MeMarker extends StatelessWidget {
  const _MeMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: _QC.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: _QC.primary.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _KaabaMarker extends StatelessWidget {
  const _KaabaMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _QC.ink,
            shape: BoxShape.circle,
            border: Border.all(color: _QC.gold, width: 2),
          ),
          child: const Icon(Icons.mosque, color: _QC.gold, size: 19),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: _QC.ink,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Kaaba',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child:
                CircularProgressIndicator(strokeWidth: 3, color: _QC.primary),
          ),
          SizedBox(height: 18),
          Text(
            'Location li jaa rahi hai…',
            style: TextStyle(
              color: _QC.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Behtar natije ke liye khuli jagah par khare hon',
            style: TextStyle(color: _QC.inkSoft, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F5F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_outlined,
                    size: 34, color: _QC.primary),
              ),
              const SizedBox(height: 18),
              const Text(
                'Location nahi mil saki',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _QC.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _QC.inkSoft,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Dobara Try Karein'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _QC.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: Geolocator.openAppSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _QC.primaryDark,
                      side: const BorderSide(color: _QC.line),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  PAINTERS
// =====================================================================

class _DialPainter extends CustomPainter {
  const _DialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Everything below is expressed as a fraction of the radius so the dial
    // stays balanced from a 140px watch-sized face up to a tablet.

    // Face
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r * 0.988,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, r * 0.024)
        ..color = const Color(0xFFE3F0EE),
    );
    canvas.drawCircle(
      c,
      r * 0.56,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFEDF5F4),
    );

    // Ticks every 5°, longer every 15° and 45°.
    final tickStart = r * 0.94;
    for (var deg = 0; deg < 360; deg += 5) {
      final major = deg % 45 == 0;
      final medium = deg % 15 == 0;
      final len = r * (major ? 0.115 : (medium ? 0.070 : 0.038));
      final a = _rad(deg - 90);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * tickStart,
        c + dir * (tickStart - len),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(
            1,
            r * (major ? 0.021 : (medium ? 0.013 : 0.009)),
          )
          ..color = major
              ? const Color(0xFF7FA8A2)
              : (medium ? const Color(0xFFA9C6C2) : const Color(0xFFD3E4E1)),
      );
    }

    // N / E / S / W plus small degree numbers every 30°.
    final cardinalSize = (r * 0.135).clamp(10.0, 18.0);
    final degreeSize = (r * 0.085).clamp(7.0, 11.0);
    for (var deg = 0; deg < 360; deg += 30) {
      final isCardinal = deg % 90 == 0;
      final label = isCardinal
          ? const {0: 'N', 90: 'E', 180: 'S', 270: 'W'}[deg]!
          : '$deg';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: isCardinal ? cardinalSize : degreeSize,
            fontWeight: isCardinal ? FontWeight.w800 : FontWeight.w500,
            color: deg == 0 ? _QC.gold : (isCardinal ? _QC.ink : _QC.inkSoft),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final a = _rad(deg - 90);
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * 0.72);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) => false;
}

class _NeedlePainter extends CustomPainter {
  const _NeedlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // The needle starts under the centre hub (0.30r) and stops just short
    // of the Kaaba badge riding the rim, so the two read as one pointer.
    final inner = r * 0.26;
    final outer = r * 0.70;
    final halfW = (r * 0.072).clamp(4.0, 11.0);

    final head = Path()
      ..moveTo(c.dx, c.dy - outer)
      ..lineTo(c.dx - halfW, c.dy - inner)
      ..lineTo(c.dx + halfW, c.dy - inner)
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.7)],
        ).createShader(
          Rect.fromLTRB(
            c.dx - halfW,
            c.dy - outer,
            c.dx + halfW,
            c.dy - inner,
          ),
        ),
    );

    // Counterweight tail — makes it read as a real compass needle.
    final tailHalf = halfW * 0.72;
    final tail = Path()
      ..moveTo(c.dx, c.dy + r * 0.56)
      ..lineTo(c.dx - tailHalf, c.dy + inner)
      ..lineTo(c.dx + tailHalf, c.dy + inner)
      ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFFC8DAD7));
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

// =====================================================================
//  MATH
// =====================================================================

double _rad(num deg) => deg * math.pi / 180;
double _deg(num rad) => rad * 180 / math.pi;

/// Great-circle initial bearing from a point to the Kaaba, in degrees
/// clockwise from true north.
double _bearingToKaaba(double lat, double lng) {
  final phi1 = _rad(lat);
  final phi2 = _rad(_kKaabaLat);
  final dLambda = _rad(_kKaabaLng - lng);

  final y = math.sin(dLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);

  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Haversine distance to the Kaaba in kilometres.
double _distanceToKaabaKm(double lat, double lng) {
  const earthRadiusKm = 6371.0088;
  final phi1 = _rad(lat);
  final phi2 = _rad(_kKaabaLat);
  final dPhi = _rad(_kKaabaLat - lat);
  final dLambda = _rad(_kKaabaLng - lng);

  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Signed smallest angle from [fromDeg] to [toDeg], in (-180, 180].
double _shortestDeltaDeg(double fromDeg, double toDeg) {
  var d = (toDeg - fromDeg) % 360;
  if (d > 180) d -= 360;
  return d;
}

/// Returns the value equivalent to [targetTurns] that is nearest to
/// [currentTurns], so a rotation animates the short way round.
double _shortestTurns(double currentTurns, double targetTurns) {
  var delta = (targetTurns - currentTurns) % 1.0;
  if (delta > 0.5) delta -= 1.0;
  return currentTurns + delta;
}

/// "Lahore District" -> "Lahore". Nominatim answers with administrative
/// names where a person would just say the city.
String? _trimAdminSuffix(String? name) {
  if (name == null) return null;
  var out = name;
  for (final suffix in const [
    ' District',
    ' Division',
    ' Tehsil',
    ' Taluka',
    ' Municipality',
    ' Metropolitan Area',
  ]) {
    if (out.toLowerCase().endsWith(suffix.toLowerCase())) {
      out = out.substring(0, out.length - suffix.length).trim();
      break;
    }
  }
  return out.isEmpty ? null : out;
}

/// "8,742 km" — thousands separated, no decimals.
String _formatKm(double km) {
  final digits = km.round().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '$grouped km';
}

/// 16-point compass label for a heading.
String _compassPoint(double deg) {
  const points = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];
  return points[((deg % 360) / 22.5).round() % 16];
}

/// Samples the great-circle path between two points, so the line drawn on
/// the map is the true shortest path rather than a straight Mercator line.
List<LatLng> _greatCircle(LatLng a, LatLng b, {int segments = 96}) {
  final lat1 = _rad(a.latitude), lon1 = _rad(a.longitude);
  final lat2 = _rad(b.latitude), lon2 = _rad(b.longitude);

  final sinHalfLat = math.sin((lat2 - lat1) / 2);
  final sinHalfLon = math.sin((lon2 - lon1) / 2);
  final h = sinHalfLat * sinHalfLat +
      math.cos(lat1) * math.cos(lat2) * sinHalfLon * sinHalfLon;
  final d = 2 * math.asin(math.min(1, math.sqrt(h)));
  if (d == 0) return [a, b];

  final points = <LatLng>[];
  for (var i = 0; i <= segments; i++) {
    final f = i / segments;
    final A = math.sin((1 - f) * d) / math.sin(d);
    final B = math.sin(f * d) / math.sin(d);
    final x = A * math.cos(lat1) * math.cos(lon1) +
        B * math.cos(lat2) * math.cos(lon2);
    final y = A * math.cos(lat1) * math.sin(lon1) +
        B * math.cos(lat2) * math.sin(lon2);
    final z = A * math.sin(lat1) + B * math.sin(lat2);
    points.add(
      LatLng(
        _deg(math.atan2(z, math.sqrt(x * x + y * y))),
        _deg(math.atan2(y, x)),
      ),
    );
  }
  return points;
}
