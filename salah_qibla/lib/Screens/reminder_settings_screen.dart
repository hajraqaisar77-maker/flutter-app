import 'package:flutter/material.dart';

import '../models/reminder_settings.dart';
import '../services/azaan_alarm_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

const Color _brandGreen = Color(0xFF1B5E20);

/// Tamam reminders ki settings — namaz se pehle ki yaad-dihani, Jumma,
/// Surah Al-Kahf, aur Surah Ar-Rahman ka rozana waqt.
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final StorageService _storage = StorageService();

  ReminderSettings _settings = const ReminderSettings();
  String? _lastIsha;
  bool _loading = true;
  bool _saving = false;
  bool _testPlaying = false;

  @override
  void dispose() {
    // Screen chhorte waqt test azaan chalti na reh jaye.
    if (_testPlaying) AzaanAlarmService().stopAzaan();
    super.dispose();
  }

  /// Test azaan — agli namaz ka intezar kiye baghair awaz ki tasdeeq.
  Future<void> _toggleTestAzaan() async {
    final azaan = AzaanAlarmService();
    if (_testPlaying) {
      await azaan.stopAzaan();
    } else {
      await azaan.playAzaan();
    }
    if (!mounted) return;
    setState(() => _testPlaying = !_testPlaying);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _storage.getReminderSettings();
    final isha = await _storage.getLastIshaTime();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _lastIsha = isha;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    await _storage.saveReminderSettings(_settings);
    await NotificationService.rescheduleAll(
      settings: _settings,
      // Prayer times yahan maujood nahi, magar Isha ka aakhri maloom waqt
      // kaafi hai — "Isha ke baad" wala reminder isi se lagta hai.
      times: null,
    );
    await NotificationService.scheduleSurahRahmanReminder(
      _settings,
      ishaTime: _lastIsha,
    );

    // Azaan band ki gayi to aaj ke alarms abhi mita dete hain. Chalu ki
    // gayi ho to Home screen agle refresh par khud laga degi.
    if (!_settings.azaanAlarmEnabled) {
      await AzaanAlarmService().cancelAllAlarms();
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminders mehfooz ho gaye'),
        backgroundColor: _brandGreen,
      ),
    );
  }

  Future<void> _pickTime({
    required int hour,
    required int minute,
    required void Function(int hour, int minute) onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked != null) {
      setState(() => onPicked(picked.hour, picked.minute));
    }
  }

  /// "Isha ke baad" mode mein reminder asal mein kis waqt bajega.
  String get _rahmanPreview {
    if (_settings.rahmanMode == RahmanReminderMode.customTime) {
      return ReminderSettings.formatTime12h(
          _settings.rahmanHour, _settings.rahmanMinute);
    }

    final isha = _lastIsha;
    if (isha == null) {
      return 'Isha ka waqt maloom hote hi tay ho jayega';
    }

    final parts = isha.split(':');
    final h = int.tryParse(parts.first);
    final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (h == null || m == null) {
      return 'Isha ka waqt maloom hote hi tay ho jayega';
    }

    final total =
        (h * 60 + m + _settings.rahmanMinutesAfterIsha) % (24 * 60);
    return '${ReminderSettings.formatTime12h(total ~/ 60, total % 60)}'
        '   (Isha $isha ke baad)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Reminder Settings'),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAzaanCard(),
                const SizedBox(height: 16),
                _buildPrePrayerCard(),
                const SizedBox(height: 16),
                _buildJummaCard(),
                const SizedBox(height: 16),
                _buildRahmanCard(),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Mehfooz ho raha hai...' : 'Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  // ------------------------------------------------------------------
  // Azaan alarm
  // ------------------------------------------------------------------
  Widget _buildAzaanCard() {
    return _card(
      icon: Icons.volume_up,
      title: 'Azaan Alarm',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _brandGreen,
          title: const Text('Namaz ke waqt azaan bajao'),
          subtitle: const Text(
            'Poori azaan alarm ki tarah bajegi — app band ho ya phone locked, '
            'tab bhi. Notification par "Stop" ka button hoga.',
          ),
          value: _settings.azaanAlarmEnabled,
          onChanged: (v) => setState(
              () => _settings = _settings.copyWith(azaanAlarmEnabled: v)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _toggleTestAzaan,
            icon: Icon(_testPlaying ? Icons.stop : Icons.play_arrow),
            label: Text(_testPlaying ? 'Band karo' : 'Azaan sun kar dekho'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brandGreen,
              side: const BorderSide(color: _brandGreen),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Agli namaz ka intezar kiye baghair yahin awaz check kar lijiye.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Namaz se pehle
  // ------------------------------------------------------------------
  Widget _buildPrePrayerCard() {
    return _card(
      icon: Icons.notifications_active,
      title: 'Namaz se pehle yaad-dihani',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _brandGreen,
          title: const Text('Har namaz se pehle itlaa'),
          subtitle: Text(
            '${_settings.prePrayerMinutes} minute pehle — Fajr, Dhuhr, Asr, Maghrib, Isha',
          ),
          value: _settings.prePrayerEnabled,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(prePrayerEnabled: v)),
        ),
        if (_settings.prePrayerEnabled)
          Row(
            children: [
              const Text('Kitne minute pehle'),
              const Spacer(),
              DropdownButton<int>(
                value: _settings.prePrayerMinutes,
                items: const [5, 10, 15, 20, 30, 45]
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text('$m minute')))
                    .toList(),
                onChanged: (v) => setState(() =>
                    _settings = _settings.copyWith(prePrayerMinutes: v)),
              ),
            ],
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Jumma
  // ------------------------------------------------------------------
  Widget _buildJummaCard() {
    return _card(
      icon: Icons.mosque,
      title: 'Jumma',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _brandGreen,
          title: const Text('Jumma Mubarak paigham'),
          subtitle: Text(
            'Har Jumma  ${ReminderSettings.formatTime12h(_settings.jummaHour, _settings.jummaMinute)}',
          ),
          value: _settings.jummaEnabled,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(jummaEnabled: v)),
        ),
        if (_settings.jummaEnabled)
          _timeRow(
            label: 'Jumma paigham ka waqt',
            hour: _settings.jummaHour,
            minute: _settings.jummaMinute,
            onPicked: (h, m) => _settings =
                _settings.copyWith(jummaHour: h, jummaMinute: m),
          ),
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _brandGreen,
          title: const Text('Surah Al-Kahf ki yaad-dihani'),
          subtitle: Text(
            'Har Jumma  ${ReminderSettings.formatTime12h(_settings.kahfHour, _settings.kahfMinute)}',
          ),
          value: _settings.kahfEnabled,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(kahfEnabled: v)),
        ),
        if (_settings.kahfEnabled)
          _timeRow(
            label: 'Surah Al-Kahf ka waqt',
            hour: _settings.kahfHour,
            minute: _settings.kahfMinute,
            onPicked: (h, m) =>
                _settings = _settings.copyWith(kahfHour: h, kahfMinute: m),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Surah Ar-Rahman
  // ------------------------------------------------------------------
  Widget _buildRahmanCard() {
    final custom = _settings.rahmanMode == RahmanReminderMode.customTime;

    return _card(
      icon: Icons.menu_book,
      title: 'Surah Ar-Rahman',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _brandGreen,
          title: const Text('Rozana sunne ki yaad-dihani'),
          subtitle: Text(_settings.rahmanEnabled ? _rahmanPreview : 'Band hai'),
          value: _settings.rahmanEnabled,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(rahmanEnabled: v)),
        ),
        if (_settings.rahmanEnabled) ...[
          const SizedBox(height: 8),
          SegmentedButton<RahmanReminderMode>(
            segments: const [
              ButtonSegment(
                value: RahmanReminderMode.customTime,
                icon: Icon(Icons.schedule),
                label: Text('Apna waqt'),
              ),
              ButtonSegment(
                value: RahmanReminderMode.afterIsha,
                icon: Icon(Icons.nights_stay),
                label: Text('Isha ke baad'),
              ),
            ],
            selected: {_settings.rahmanMode},
            onSelectionChanged: (s) => setState(
                () => _settings = _settings.copyWith(rahmanMode: s.first)),
          ),
          const SizedBox(height: 8),
          if (custom)
            _timeRow(
              label: 'Rozana is waqt',
              hour: _settings.rahmanHour,
              minute: _settings.rahmanMinute,
              onPicked: (h, m) =>
                  _settings = _settings.copyWith(rahmanHour: h, rahmanMinute: m),
            )
          else
            Row(
              children: [
                const Expanded(child: Text('Isha ke kitne minute baad')),
                DropdownButton<int>(
                  value: _settings.rahmanMinutesAfterIsha,
                  items: const [0, 15, 30, 45, 60, 90, 120]
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text(m == 0 ? 'Foran' : '$m minute')))
                      .toList(),
                  onChanged: (v) => setState(() => _settings =
                      _settings.copyWith(rahmanMinutesAfterIsha: v)),
                ),
              ],
            ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------
  // Chhote hisse
  // ------------------------------------------------------------------
  Widget _timeRow({
    required String label,
    required int hour,
    required int minute,
    required void Function(int hour, int minute) onPicked,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          OutlinedButton.icon(
            onPressed: () =>
                _pickTime(hour: hour, minute: minute, onPicked: onPicked),
            icon: const Icon(Icons.access_time, size: 18),
            label: Text(ReminderSettings.formatTime12h(hour, minute)),
            style: OutlinedButton.styleFrom(foregroundColor: _brandGreen),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _brandGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _brandGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}
