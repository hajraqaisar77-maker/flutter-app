import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/prayer_api_service.dart';
import '../services/location_service.dart';
import '../services/azaan_alarm_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../models/prayer_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerTimes? _prayerTimes;
  bool _isLoading = true;
  String _error = '';
  String _nextPrayer = '';
  String _nextPrayerTime = '';
  Duration _timeUntilNext = Duration.zero;
  String _locationName = 'Loading location...';
  double _latitude = 0;
  double _longitude = 0;

  @override
  void initState() {
    super.initState();
    _initLocationAndPrayer();
  }

  Future<void> _initLocationAndPrayer() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Get location
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationName = '📍 Your Location';
      });

      // Load prayer times
      await _loadPrayerTimes();
    } catch (e) {
      setState(() {
        _error = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPrayerTimes() async {
    try {
      final api = PrayerApiService();
      final times = await api.fetchPrayerTimes(
        latitude: _latitude,
        longitude: _longitude,
      );
      setState(() {
        _prayerTimes = times;
        _isLoading = false;
        _calculateNextPrayer();
      });

      // Naye auqaat aate hi tamam reminders dobara set karte hain — azaan,
      // har namaz se pehle ki yaad-dihani, aur Isha ke baad wala Surah
      // Ar-Rahman reminder (agar user ne wo tareeqa chuna ho).
      final storage = StorageService();
      await storage.saveLastIshaTime(times.isha);
      final settings = await storage.getReminderSettings();
      await NotificationService.rescheduleAll(times: times, settings: settings);

      // Aaj ki 5 azaanein — asal audio ke saath, app band hone par bhi.
      // User settings se isay band bhi kar sakti hai.
      final azaan = AzaanAlarmService();
      if (settings.azaanAlarmEnabled) {
        await azaan.scheduleTodayAlarms(times);
      } else {
        await azaan.cancelAllAlarms();
      }

      // ✅ Timer start karein (next prayer update ke liye)
      _startTimer();
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _calculateNextPrayer() {
    if (_prayerTimes == null) return;

    final now = DateTime.now().toLocal();
    final prayers = {
      'Fajr': _parseTime(_prayerTimes!.fajr),
      'Dhuhr': _parseTime(_prayerTimes!.dhuhr),
      'Asr': _parseTime(_prayerTimes!.asr),
      'Maghrib': _parseTime(_prayerTimes!.maghrib),
      'Isha': _parseTime(_prayerTimes!.isha),
    };

    DateTime? next;
    String? nextName;

    for (var entry in prayers.entries) {
      if (entry.value.isAfter(now)) {
        if (next == null || entry.value.isBefore(next)) {
          next = entry.value;
          nextName = entry.key;
        }
      }
    }

    if (next == null) {
      final first = prayers.entries.first;
      next = first.value.add(const Duration(days: 1));
      nextName = first.key;
    }

    setState(() {
      _nextPrayer = nextName ?? '';
      _nextPrayerTime = DateFormat('HH:mm').format(next!);
      _timeUntilNext = next.difference(now);
    });
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now().toLocal();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  void _startTimer() {
    // ✅ Har minute update karein
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        _calculateNextPrayer();
        _startTimer();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String hours = twoDigits(duration.inHours.remainder(24));
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('SalaH Now'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initLocationAndPrayer,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      ElevatedButton(
                        onPressed: _initLocationAndPrayer,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location & Date
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A5F2A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: Color(0xFF1A5F2A)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _locationName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _prayerTimes?.date ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Live',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Current Prayer Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A5F2A), Color(0xFF2E7D32)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _nextPrayer.isEmpty ? '--' : _nextPrayer,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Agli namaz ka apna waqt. Pehle yahan hamesha
                              // Maghrib ka waqt lagta tha, chahe agli namaz
                              // koi bhi ho.
                              Text(
                                _nextPrayerTime.isEmpty
                                    ? '--:--'
                                    : _nextPrayerTime,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Next prayer in ${_formatDuration(_timeUntilNext)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  // Navigate to prayer screen
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Tap to view more prayer times',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // All Prayers List
                        const Text(
                          "Today's Prayers",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView(
                            children: [
                              _buildPrayerRow('Fajr',
                                  _prayerTimes?.fajr ?? '--:--', Icons.wb_sunny),
                              _buildPrayerRow(
                                  'Sunrise',
                                  _prayerTimes?.sunrise ?? '--:--',
                                  Icons.wb_sunny_outlined),
                              _buildPrayerRow('Dhuhr',
                                  _prayerTimes?.dhuhr ?? '--:--', Icons.sunny),
                              _buildPrayerRow('Asr',
                                  _prayerTimes?.asr ?? '--:--', Icons.cloud),
                              _buildPrayerRow(
                                  'Maghrib',
                                  _prayerTimes?.maghrib ?? '--:--',
                                  Icons.nightlight_round),
                              _buildPrayerRow(
                                  'Isha',
                                  _prayerTimes?.isha ?? '--:--',
                                  Icons.nights_stay),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPrayerRow(String name, String time, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A5F2A)),
          const SizedBox(width: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            time,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}