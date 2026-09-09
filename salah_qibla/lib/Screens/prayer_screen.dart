import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/prayer_provider.dart';
import '../services/storage_service.dart';

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  String _selectedView = 'Weekly';
  Map<String, bool>? _todayRecord;
  String _todayDate = '';
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _todayDate = DateTime.now().toString().substring(0, 10);
    _loadTodayRecord();
  }

  Future<void> _loadTodayRecord() async {
    final record = await _storage.getTodayRecord(_todayDate);
    setState(() {
      _todayRecord = record ??
          {
            'fajr': false,
            'dhuhr': false,
            'asr': false,
            'maghrib': false,
            'isha': false,
          };
    });
    if (record == null && _todayRecord != null) {
      await _storage.savePrayerRecord(_todayDate, _todayRecord!);
    }
  }

  Future<void> _togglePrayer(String prayerName) async {
    if (_todayRecord == null) return;

    setState(() {
      _todayRecord![prayerName] = !_todayRecord![prayerName]!;
    });

    await _storage.savePrayerRecord(_todayDate, _todayRecord!);
  }

  @override
  Widget build(BuildContext context) {
    final weeklyPrayer = ref.watch(weeklyPrayerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedView,
                underline: const SizedBox(),
                onChanged: (value) {
                  setState(() => _selectedView = value!);
                },
                items: const [
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'Detailed', child: Text('Detailed')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _selectedView == 'Weekly'
          ? weeklyPrayer.when(
              data: (prayers) => _buildWeeklyView(prayers),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            )
          : _buildDetailedView(),
    );
  }

  Widget _buildWeeklyView(List prayers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prayers.length,
      itemBuilder: (context, index) {
        final prayer = prayers[index];
        final date = DateTime.now().add(Duration(days: index));
        final dayName =
            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color:
                  index == 0 ? const Color(0xFF0A2E29).withValues(alpha: 0.05) : null,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A2E29).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          date.day.toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2E29),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A2E29),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniPrayer('Fajr', prayer.fajr),
                    _buildMiniPrayer('Dhuhr', prayer.dhuhr),
                    _buildMiniPrayer('Asr', prayer.asr),
                    _buildMiniPrayer('Maghrib', prayer.maghrib),
                    _buildMiniPrayer('Isha', prayer.isha),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniPrayer(String name, String time) {
    return Expanded(
      child: Column(
        children: [
          Text(name,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDetailedView() {
    if (_todayRecord == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final prayers = {
      'Fajr': _todayRecord!['fajr'] ?? false,
      'Dhuhr': _todayRecord!['dhuhr'] ?? false,
      'Asr': _todayRecord!['asr'] ?? false,
      'Maghrib': _todayRecord!['maghrib'] ?? false,
      'Isha': _todayRecord!['isha'] ?? false,
    };

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A2E29), Color(0xFF1A5F2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _todayDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.check_circle, color: Colors.white, size: 32),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Record Your Prayers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: prayers.entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      entry.value
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: entry.value ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _togglePrayer(entry.key.toLowerCase()),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
