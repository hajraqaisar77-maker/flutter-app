import 'package:flutter/material.dart';
import 'surah_detail_screen.dart';
import 'hadith_list_screen.dart';
import 'dhikr_list_screen.dart';
import 'calendar_screen.dart';
import 'qibla_screen.dart'; // ← YEH LINE IMPORTANT HAI

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            context,
            '📖 Quran',
            'Read the Holy Quran',
            Icons.menu_book,
            Colors.green,
            'quran',
          ),
          _buildCard(
            context,
            '🕌 Hadith',
            'Sayings of Prophet Muhammad (PBUH)',
            Icons.format_quote,
            Colors.blue,
            'hadith',
          ),
          _buildCard(
            context,
            '📿 Dhikr',
            'Daily remembrance of Allah',
            Icons.favorite,
            Colors.purple,
            'dhikr',
          ),
          _buildCard(
            context,
            '📅 Islamic Calendar',
            'Hijri dates and important events',
            Icons.calendar_month,
            Colors.orange,
            'calendar',
          ),
          _buildCard(
            context,
            '🧭 Qibla',
            'Find the direction of Kaaba',
            Icons.explore,
            Colors.teal,
            'qibla',
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String route,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          if (route == 'quran') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QuranScreen(),
              ),
            );
          } else if (route == 'hadith') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HadithListScreen(),
              ),
            );
          } else if (route == 'dhikr') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DhikrListScreen(),
              ),
            );
          } else if (route == 'calendar') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CalendarScreen(),
              ),
            );
          } else if (route == 'qibla') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QiblaScreen(),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title section coming soon!'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ QURAN SCREEN ============

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  /// `number` Quran mein surah ka asal number hai — list ki position nahi.
  /// Pehle `index + 1` dikhaya jata tha, jis se Ar-Rahman "7" nazar aati
  /// thi jabke wo 55 hai.
  final List<Map<String, String>> surahs = const [
    {'number': '1', 'name': 'Al-Fatihah', 'meaning': 'The Opening', 'verses': '7'},
    {'number': '2', 'name': 'Al-Baqarah', 'meaning': 'The Cow', 'verses': '286'},
    {'number': '18', 'name': 'Al-Kahf', 'meaning': 'The Cave', 'verses': '110'},
    {'number': '24', 'name': 'An-Noor', 'meaning': 'The Light', 'verses': '64'},
    {'number': '36', 'name': 'Yaseen', 'meaning': 'Ya Sin', 'verses': '83'},
    {'number': '48', 'name': 'Al-Fath', 'meaning': 'The Victory', 'verses': '29'},
    {'number': '55', 'name': 'Ar-Rahman', 'meaning': 'The Most Gracious', 'verses': '78'},
    {'number': '67', 'name': 'Al-Mulk', 'meaning': 'The Dominion', 'verses': '30'},
    {'number': '106', 'name': 'Quraysh', 'meaning': 'Quraysh', 'verses': '4'},
    {'number': '108', 'name': 'Al-Kawthar', 'meaning': 'The Abundance', 'verses': '3'},
    {'number': '112', 'name': 'Al-Ikhlas', 'meaning': 'The Sincerity', 'verses': '4'},
    {'number': '113', 'name': 'Al-Falaq', 'meaning': 'The Dawn', 'verses': '5'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran - Surahs'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: surahs.length,
        itemBuilder: (context, index) {
          final surah = surahs[index];
          final number = surah['number']!;
          final isKahf = surah['name'] == 'Al-Kahf';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
              title: Text(
                surah['name']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                isKahf
                    ? '${surah['meaning']!} • ${surah['verses']!} verses • Jumma ko parhein'
                    : '${surah['meaning']!} • ${surah['verses']!} verses',
                style: TextStyle(
                  fontSize: 14,
                  color: isKahf ? Colors.green.shade700 : Colors.grey.shade600,
                  fontWeight: isKahf ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SurahDetailScreen(
                      surahName: surah['name']!,
                      surahNumber: number,
                      verses: surah['verses']!,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
