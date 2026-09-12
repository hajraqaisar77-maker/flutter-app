import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;

  // Get current position
  Future<Position> getCurrentPosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    }

    // Haal hi ka mehfooz location mil jaye to usi par kaam chala lete hain.
    // Namaz ke auqaat shehar ki satah par tay hote hain — chand sau meter
    // ka farq sirf seconds ka farq daalta hai. Is se app foran chal padti
    // hai, GPS ke intezar mein atakti nahi.
    final cached = await Geolocator.getLastKnownPosition();
    if (cached != null && _isFresh(cached)) {
      _currentPosition = cached;
      return cached;
    }

    try {
      // geolocator 14 mein `desiredAccuracy`/`timeLimit` alag alag deni band
      // ho gayi hain — ab dono `locationSettings` mein jati hain.
      //
      // Accuracy `best` se `medium` ki gayi: `best` satellite lock ka intezar
      // karta hai jo ghar ke andar mushkil se milta hai, jabke `medium`
      // wifi/network se foran mil jata hai aur auqaat ke liye kaafi hai.
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 30),
        ),
      );
      return _currentPosition!;
    } catch (e) {
      // Naya fix na mile to purana hi chalega — koi bhi location na hone se
      // behtar hai, warna prayer times aate hi nahi aur azaan set nahi hoti.
      if (cached != null) {
        _currentPosition = cached;
        return cached;
      }
      return Future.error('Could not determine location: $e');
    }
  }

  /// Ek ghante se naya location "taza" samjha jata hai.
  bool _isFresh(Position p) {
    final age = DateTime.now().difference(p.timestamp);
    return age.inMinutes.abs() <= 60;
  }
}