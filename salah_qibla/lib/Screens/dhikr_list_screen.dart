import 'package:flutter/material.dart';
import 'dhikr_detail_screen.dart';

class DhikrListScreen extends StatelessWidget {
  const DhikrListScreen({super.key});

  final List<Map<String, String>> dhikrList = const [
    // ========== 1. SUBHANALLAH ==========
    {
      'id': '1',
      'arabic': 'سُبْحَانَ اللَّهِ',
      'urdu': 'اللہ پاک ہے۔',
      'count': '33'
    },
    // ========== 2. ALHAMDULILLAH ==========
    {
      'id': '2',
      'arabic': 'الْحَمْدُ لِلَّهِ',
      'urdu': 'تمام تعریفیں اللہ کے لیے ہیں۔',
      'count': '33'
    },
    // ========== 3. ALLAHU AKBAR ==========
    {
      'id': '3',
      'arabic': 'اللَّهُ أَكْبَرُ',
      'urdu': 'اللہ سب سے بڑا ہے۔',
      'count': '34'
    },
    // ========== 4. LA ILAHA ILLALLAH ==========
    {
      'id': '4',
      'arabic': 'لَا إِلَٰهَ إِلَّا اللَّهُ',
      'urdu': 'اللہ کے سوا کوئی معبود نہیں۔',
      'count': '10'
    },
    // ========== 5. ASTAGHFIRULLAH ==========
    {
      'id': '5',
      'arabic': 'أَسْتَغْفِرُ اللَّهَ',
      'urdu': 'میں اللہ سے بخشش مانگتا/مانگتی ہوں۔',
      'count': '33'
    },
    // ========== 6. SUBHANALLAH WA BIHAMDIHI ==========
    {
      'id': '6',
      'arabic': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      'urdu': 'اللہ پاک ہے اور اسی کی حمد ہے۔',
      'count': '100'
    },
    // ========== 7. LA HAWLA WA LA QUWWATA ==========
    {
      'id': '7',
      'arabic': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      'urdu': 'اللہ کے سوا کوئی طاقت اور قوت نہیں۔',
      'count': '10'
    },
    // ========== 8. DAROOD SHAREEF ==========
    {
      'id': '8',
      'arabic': 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ ﷺ',
      'urdu': 'نبی کریم ﷺ پر درود و سلام بھیجنا۔',
      'count': '10'
    },
    // ========== 9. DUA 1 (NEW) ==========
    {
      'id': '9',
      'arabic':
          'اللَّهُمَّ لَا سَهْلَ إِلَّا مَا جَعَلْتَهُ سَهْلًا، وَأَنْتَ تَجْعَلُ الْحَزْنَ إِذَا شِئْتَ سَهْلًا',
      'urdu':
          'اے اللہ! آسانی کے سوا کوئی آسان نہیں، اور تو جب چاہے مشکل کو آسان کر دیتا ہے۔',
      'count': '33'
    },
    // ========== 10. DUA 2 ==========
    {
      'id': '10',
      'arabic':
          'فَإِنَّ حَسْبَكَ اللَّهُ ۖ هُوَ الَّذِي أَيَّدَكَ بِنَصْرِهِ وَبِالْمُؤْمِنِينَ',
      'urdu':
          'پس تمہارے لیے اللہ کافی ہے، وہی ہے جس نے تمہیں اپنی مدد اور مومنین کے ذریعے تقویت دی۔',
      'count': '33'
    },
    // ========== 11. DUA 3 (AYAT) ==========
    {
      'id': '11',
      'arabic':
          'لَا إِلَٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
      'urdu':
          'تیرے سوا کوئی معبود نہیں، تو پاک ہے، بیشک میں ظالموں میں سے ہوں۔',
      'count': '33'
    },
    // ========== 12. DUA 4 ==========
    {
      'id': '12',
      'arabic': 'رَبِّ إِنِّي لِمَا أَنْزَلْتَ إِلَيَّ مِنْ خَيْرٍ فَقِيرٌ',
      'urdu':
          'اے میرے رب! جو بھی بھلائی تو نے میری طرف نازل کی، میں اس کا محتاج ہوں۔',
      'count': '33'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📿 Dhikr - Daily Remembrance'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: dhikrList.length,
        itemBuilder: (context, index) {
          final dhikr = dhikrList[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                    ),
                  ),
                ),
              ),
              title: Text(
                dhikr['arabic']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textDirection: TextDirection.rtl,
              ),
              subtitle: Text(
                '${dhikr['urdu']!}  •  ${dhikr['count']!} times',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
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
                    builder: (context) => DhikrDetailScreen(
                      dhikr: dhikr,
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
