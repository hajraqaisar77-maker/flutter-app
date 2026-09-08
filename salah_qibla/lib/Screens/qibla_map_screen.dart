import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class QiblaMapScreen extends StatefulWidget {
  const QiblaMapScreen({super.key});

  @override
  State<QiblaMapScreen> createState() => _QiblaMapScreenState();
}

class _QiblaMapScreenState extends State<QiblaMapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(33.6844, 73.0479); // Default
  final LatLng _kaabaLocation = const LatLng(21.4225, 39.8262);
  bool _isLoading = true;
  String _error = '';

  // Custom marker icons
  final Marker _kaabaMarker = Marker(
    markerId: const MarkerId('kaaba'),
    position: const LatLng(21.4225, 39.8262),
    infoWindow: const InfoWindow(title: '🕋 Kaaba'),
    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permission denied.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permanently denied. Please enable from Settings.';
          _isLoading = false;
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  void _goToKaaba() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(
            target: LatLng(21.4225, 39.8262),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _goToMyLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation,
            zoom: 15,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.map, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Qibla Map',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _getCurrentLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // Google Map
                    GoogleMap(
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target: _currentLocation,
                        zoom: 12,
                      ),
                      markers: {
                        _kaabaMarker,
                        Marker(
                          markerId: const MarkerId('myLocation'),
                          position: _currentLocation,
                          infoWindow: const InfoWindow(title: '📍 My Location'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueBlue,
                          ),
                        ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),

                    // Custom Controls
                    Positioned(
                      bottom: 20,
                      right: 16,
                      child: Column(
                        children: [
                          // Zoom In
                          _buildControlButton(
                            icon: Icons.add,
                            onTap: () {
                              _mapController?.animateCamera(
                                CameraUpdate.zoomIn(),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // Zoom Out
                          _buildControlButton(
                            icon: Icons.remove,
                            onTap: () {
                              _mapController?.animateCamera(
                                CameraUpdate.zoomOut(),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // My Location
                          _buildControlButton(
                            icon: Icons.my_location,
                            onTap: _goToMyLocation,
                          ),
                          const SizedBox(height: 8),
                          // Kaaba
                          _buildControlButton(
                            icon: Icons.location_on,
                            onTap: _goToKaaba,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),

                    // Bottom Info Card
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 100,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.teal, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '🕋 Kaaba',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${_kaabaLocation.latitude.toStringAsFixed(4)}, ${_kaabaLocation.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Distance Info
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '📍 My Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.explore,
                                    color: Colors.teal, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${_calculateDistance().toStringAsFixed(0)} km',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  double _calculateDistance() {
    const R = 6371;
    final double lat1 = _currentLocation.latitude * pi / 180;
    final double lon1 = _currentLocation.longitude * pi / 180;
    final double lat2 = _kaabaLocation.latitude * pi / 180;
    final double lon2 = _kaabaLocation.longitude * pi / 180;

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: color ?? Colors.teal,
          size: 24,
        ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
