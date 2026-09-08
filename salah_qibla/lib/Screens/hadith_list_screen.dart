import 'package:flutter/material.dart';
import 'hadith_detail_screen.dart';

class HadithListScreen extends StatelessWidget {
  const HadithListScreen({super.key});

  final List<Map<String, String>> hadiths = const [
    {
      'id': '1',
      'arabic': 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
      'urdu': 'اعمال کا دارومدار نیتوں پر ہے۔',
      'reference': 'صحیح البخاری، حدیث 1'
    },
    {
      'id': '2',
      'arabic':
          'لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ',
      'urdu':
          'تم میں سے کوئی شخص کامل ایمان والا نہیں ہوتا جب تک اپنے بھائی کے لیے وہی پسند نہ کرے جو اپنے لیے پسند کرتا ہے۔',
      'reference': 'صحیح البخاری، حدیث 13؛ صحیح مسلم، حدیث 45'
    },
    {
      'id': '3',
      'arabic': 'لَا تَغْضَبْ',
      'urdu': 'غصہ نہ کرو۔',
      'reference': 'صحیح البخاری، حدیث 6116'
    },
    {
      'id': '4',
      'arabic':
          'الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ',
      'urdu': 'مسلمان وہ ہے جس کی زبان اور ہاتھ سے دوسرے مسلمان محفوظ رہیں۔',
      'reference': 'صحیح البخاری، حدیث 10'
    },
    {
      'id': '5',
      'arabic': 'فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ',
      'urdu': 'اچھی بات کہے یا خاموش رہے۔',
      'reference': 'صحیح مسلم، حدیث 47a'
    },
    {
      'id': '6',
      'arabic': 'فَلْيُكْرِمْ جَارَهُ',
      'urdu': 'وہ اپنے پڑوسی کی عزت کرے۔',
      'reference': 'صحیح مسلم، حدیث 47a'
    },
    {
      'id': '7',
      'arabic': 'الطُّهُورُ شَطْرُ الإِيمَانِ',
      'urdu': 'پاکیزگی نصف ایمان ہے۔',
      'reference': 'صحیح مسلم، حدیث 223'
    },
    {
      'id': '8',
      'arabic': 'فَلْيُكْرِمْ ضَيْفَهُ',
      'urdu': 'وہ اپنے مہمان کی عزت کرے۔',
      'reference': 'صحیح مسلم، حدیث 47a'
    },
    {
      'id': '9',
      'arabic': 'الدِّينُ النَّصِيحَةُ',
      'urdu': 'دین خیرخواہی کا نام ہے۔',
      'reference': 'صحیح مسلم، حدیث 55b'
    },
    {
      'id': '10',
      'arabic': 'خِيَارُكُمْ أَحَاسِنُكُمْ أَخْلَاقًا',
      'urdu': 'تم میں سب سے بہترین وہ ہیں جن کے اخلاق سب سے اچھے ہیں۔',
      'reference': 'صحیح البخاری، حدیث 6035'
    },
    {
      'id': '11',
      'arabic': 'مَنْ لَا يَرْحَمْ لَا يُرْحَمْ',
      'urdu': 'جو رحم نہیں کرتا، اس پر رحم نہیں کیا جاتا۔',
      'reference': 'صحیح البخاری، حدیث 5997'
    },
    {
      'id': '12',
      'arabic': 'مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ',
      'urdu':
          'بہترین مسلمان وہ ہے جس کی زبان اور ہاتھ سے دوسرے مسلمان محفوظ رہیں۔',
      'reference': 'صحیح البخاری، حدیث 11'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📜 Hadith Collection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: hadiths.length,
        itemBuilder: (context, index) {
          final hadith = hadiths[index];
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
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ),
              title: Text(
                hadith['urdu']!.length > 50
                    ? '${hadith['urdu']!.substring(0, 50)}...'
                    : hadith['urdu']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                hadith['reference']!,
                style: TextStyle(
                  fontSize: 12,
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
                    builder: (context) => HadithDetailScreen(
                      hadith: hadith,
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
