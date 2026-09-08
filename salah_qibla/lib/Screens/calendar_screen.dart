import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;
  int _selectedDay = DateTime.now().day;

  // ---------------------------------------------------------------------
  // OPTIONAL CALIBRATION OFFSET (in days).
  //
  // The conversion below uses the standard "tabular Islamic calendar"
  // (Kuwaiti algorithm), which is an astronomical/arithmetic approximation.
  // It already matches Pakistan's Ruet-e-Hilal announced date for many
  // months, but moon-sighting decisions can occasionally shift a real
  // month start by ±1 day compared to the arithmetic calendar.
  //
  // If you ever notice the app is 1 day ahead/behind the Ruet-e-Hilal
  // Committee's official announcement, adjust this value (+1 or -1) —
  // do NOT hardcode a Gregorian->Hijri month mapping, since that breaks
  // every year (Hijri months drift ~10-11 days earlier each Gregorian
  // year because it's a lunar calendar).
  // ---------------------------------------------------------------------
  static const int _hijriOffsetDays = 0;

  final List<String> _hijriMonthsUrdu = [
    'محرم',
    'صفر',
    'ربیع الاول',
    'ربیع الثانی',
    'جمادی الاول',
    'جمادی الثانی',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذی القعدہ',
    'ذی الحجہ'
  ];

  final List<String> _hijriMonthsEnglish = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhul Qidah',
    'Dhul Hijjah'
  ];

  final List<String> _gregorianMonthsEnglish = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  final List<String> _weekdaysUrdu = [
    'پیر',
    'منگل',
    'بدھ',
    'جمعرات',
    'جمعہ',
    'ہفتہ',
    'اتوار'
  ];
  final List<String> _weekdaysEnglish = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  // ---------------------------------------------------------------------
  // Key Islamic events, keyed by "hijriMonth-hijriDay" (month 1-12).
  // Add/adjust freely — these are the commonly observed South Asian dates;
  // exact day can shift ±1 depending on local moon sighting.
  // ---------------------------------------------------------------------
  static const Map<String, Map<String, String>> _islamicEvents = {
    '1-1': {'ur': 'اسلامی سال نو', 'en': 'Islamic New Year'},
    '1-10': {'ur': 'یوم عاشورہ', 'en': 'Day of Ashura'},
    '3-12': {'ur': 'عید میلاد النبی ﷺ', 'en': 'Mawlid al-Nabi (ﷺ)'},
    '7-27': {'ur': 'شب معراج', 'en': 'Isra and Mi\'raj'},
    '8-15': {'ur': 'شب برات', 'en': 'Shab-e-Barat'},
    '9-1': {'ur': 'رمضان کا آغاز', 'en': 'Ramadan Begins'},
    '9-27': {'ur': 'شب قدر (متوقع)', 'en': 'Laylat al-Qadr (est.)'},
    '10-1': {'ur': 'عید الفطر', 'en': 'Eid al-Fitr'},
    '12-9': {'ur': 'یوم عرفہ', 'en': 'Day of Arafah'},
    '12-10': {'ur': 'عید الاضحیٰ', 'en': 'Eid al-Adha'},
  };

  Map<String, String>? _eventFor(int hijriMonth, int hijriDay) {
    return _islamicEvents['$hijriMonth-$hijriDay'];
  }

  void _showEventInfo(Map<String, String> event, DateTime gregorianDate) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(Icons.mosque, color: Colors.orange.shade600, size: 32),
              const SizedBox(height: 12),
              Text(
                event['ur']!,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                event['en']!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                '${gregorianDate.day} ${_gregorianMonthsEnglish[gregorianDate.month - 1]} ${gregorianDate.year}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // REAL Gregorian -> Hijri conversion (tabular/Kuwaiti algorithm).
  // Returns [hijriYear, hijriMonth(1-12), hijriDay].
  // This replaces the old fixed "Aug always = Sha'ban" mapping.
  // ---------------------------------------------------------------------
  List<int> _gregorianToHijri(DateTime date) {
    final int jd = _gregorianToJulianDay(date.year, date.month, date.day) +
        _hijriOffsetDays;

    int l = jd - 1948440 + 10632;
    final int n = ((l - 1) / 10631).floor();
    l = l - 10631 * n + 354;
    final int j =
        (((10985 - l) / 5316).floor()) * (((50 * l) / 17719).floor()) +
            ((l / 5670).floor()) * (((43 * l) / 15238).floor());
    l = l -
        (((30 - j) / 15).floor()) * (((17719 * j) / 50).floor()) -
        ((j / 16).floor()) * (((15238 * j) / 43).floor()) +
        29;
    final int hMonth = ((24 * l) / 709).floor();
    final int hDay = l - ((709 * hMonth) / 24).floor();
    final int hYear = 30 * n + j - 30;

    return [hYear, hMonth, hDay];
  }

  int _gregorianToJulianDay(int year, int month, int day) {
    final int a = ((14 - month) / 12).floor();
    final int y = year + 4800 - a;
    final int m = month + 12 * a - 3;
    return day +
        ((153 * m + 2) / 5).floor() +
        365 * y +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;
  }

  List<DateTime> _getDaysInMonth(int month, int year) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final days = <DateTime>[];

    final int startOffset = firstDay.weekday - 1;

    for (int i = startOffset; i > 0; i--) {
      days.add(DateTime(year, month, -i + 1));
    }

    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(year, month, i));
    }

    final remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add(DateTime(year, month + 1, i));
    }

    return days;
  }

  void _previousMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
    });
  }

  String _toUrduNumber(String number) {
    const Map<String, String> urduNumerals = {
      '0': '۰',
      '1': '۱',
      '2': '۲',
      '3': '۳',
      '4': '۴',
      '5': '۵',
      '6': '۶',
      '7': '۷',
      '8': '۸',
      '9': '۹',
    };
    return number.split('').map((char) => urduNumerals[char] ?? char).join('');
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth(_currentMonth, _currentYear);
    final now = DateTime.now();

    // Hijri info for the header: use the middle of the displayed Gregorian
    // month as a representative date (a Gregorian month can straddle two
    // Hijri months, so this picks the one that covers most of the view).
    final headerHijri =
        _gregorianToHijri(DateTime(_currentYear, _currentMonth, 15));
    final headerHijriMonthIndex = headerHijri[1] - 1;

    // Hijri info for the actually selected day (always exact).
    final selectedDate = DateTime(_currentYear, _currentMonth, _selectedDay);
    final selectedHijri = _gregorianToHijri(selectedDate);
    final selectedHijriMonthIndex = selectedHijri[1] - 1;

    // Ramadan is Hijri month 9 — used to give the header a distinct look.
    final bool isRamadanView = headerHijri[1] == 9;
    final MaterialColor themeColor =
        isRamadanView ? Colors.green : Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Islamic Calendar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Month Navigation
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Container(
                  key: ValueKey('$_currentYear-$_currentMonth'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isRamadanView
                        ? LinearGradient(
                            colors: [
                              Colors.green.shade50,
                              Colors.green.shade100
                            ],
                          )
                        : null,
                    color: isRamadanView ? null : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: themeColor.shade300, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _previousMonth,
                        icon: Icon(Icons.arrow_back_ios, color: themeColor),
                        iconSize: 20,
                      ),
                      Column(
                        children: [
                          if (isRamadanView)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'رمضان مبارک',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Text(
                            _hijriMonthsUrdu[headerHijriMonthIndex],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_gregorianMonthsEnglish[_currentMonth - 1]} $_currentYear',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: Icon(Icons.arrow_forward_ios, color: themeColor),
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Weekday Headers (Friday / Jummah gets a distinct highlight)
              Row(
                children: List.generate(7, (index) {
                  final bool isJummah = index == 4; // Fri
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isJummah
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: isJummah
                            ? Border.all(color: Colors.green.shade200)
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _weekdaysUrdu[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isJummah
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _weekdaysEnglish[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isJummah
                                  ? Colors.green.shade600
                                  : Colors.orange.shade600,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),

              // Calendar Grid
              Column(
                children: List.generate(6, (rowIndex) {
                  return Row(
                    children: List.generate(7, (colIndex) {
                      final index = rowIndex * 7 + colIndex;
                      if (index >= days.length) {
                        return Expanded(
                          child: Container(
                            height: 45,
                            margin: const EdgeInsets.all(2),
                          ),
                        );
                      }
                      final date = days[index];
                      final isCurrentMonth = date.month == _currentMonth;
                      final isToday = date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;
                      final isSelected = date.day == _selectedDay &&
                          date.month == _currentMonth &&
                          date.year == _currentYear;

                      // Real Hijri day number for this specific cell.
                      final cellHijri = _gregorianToHijri(date);
                      final cellHijriDay = cellHijri[2];
                      final cellHijriMonth = cellHijri[1];
                      final bool isJummah = date.weekday == DateTime.friday;
                      final event = _eventFor(cellHijriMonth, cellHijriDay);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isCurrentMonth) {
                              setState(() {
                                _selectedDay = date.day;
                              });
                              if (event != null) {
                                _showEventInfo(event, date);
                              }
                            }
                          },
                          child: Container(
                            height: 45,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.orange
                                  : isToday
                                      ? Colors.orange.shade100
                                      : (isJummah && isCurrentMonth)
                                          ? Colors.green.shade50
                                          : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: isToday && !isSelected
                                  ? Border.all(color: Colors.orange, width: 2)
                                  : (event != null &&
                                          isCurrentMonth &&
                                          !isSelected)
                                      ? Border.all(
                                          color: Colors.green.shade400,
                                          width: 1.2)
                                      : null,
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        date.day.toString(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isCurrentMonth
                                              ? isSelected
                                                  ? Colors.white
                                                  : Colors.black87
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                      Text(
                                        // FIXED: real Hijri day, not the
                                        // Gregorian day re-drawn in Urdu digits.
                                        _toUrduNumber(cellHijriDay.toString()),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isSelected
                                              ? Colors.white70
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (event != null && isCurrentMonth)
                                  Positioned(
                                    top: 3,
                                    right: 3,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.green.shade600,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Selected Date Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Date',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_selectedDay ${_gregorianMonthsEnglish[_currentMonth - 1]} $_currentYear',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Hijri Date',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // FIXED: uses real conversion for the exact
                          // selected date, not the header's month index.
                          '${_toUrduNumber(selectedHijri[2].toString())} ${_hijriMonthsUrdu[selectedHijriMonthIndex]} ${_toUrduNumber(selectedHijri[0].toString())} ھ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // If the selected day matches a known Islamic event, show it.
              Builder(builder: (context) {
                final selectedEvent =
                    _eventFor(selectedHijri[1], selectedHijri[2]);
                if (selectedEvent == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mosque,
                          color: Colors.green.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedEvent['ur']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              selectedEvent['en']!,
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
