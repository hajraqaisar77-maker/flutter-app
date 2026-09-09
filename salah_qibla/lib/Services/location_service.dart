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

    try {
      // geolocator 14 mein `desiredAccuracy`/`timeLimit` alag alag deni
      // band ho gayi hain — ab dono `locationSettings` mein jati hain.
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _currentPosition!;
    } catch (e) {
      // Fresh GPS fix failed — fall back to last known position
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _currentPosition = lastKnown;
        return lastKnown;
      }
      return Future.error('Could not determine location: $e');
    }
  }
}