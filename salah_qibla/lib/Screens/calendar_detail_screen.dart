import 'package:flutter/material.dart';

class CalendarDetailScreen extends StatelessWidget {
  final String monthName;
  final String arabicName;
  final String events;

  const CalendarDetailScreen({
    super.key,
    required this.monthName,
    required this.arabicName,
    required this.events,
  });

  // Extra details for each event
  String _getEventDescription(String event) {
    switch (event) {
      case 'Islamic New Year':
        return 'The Islamic New Year marks the beginning of the Hijri calendar. It commemorates the migration (Hijra) of Prophet Muhammad ﷺ from Mecca to Medina.';
      case 'Birth of Prophet Muhammad ﷺ':
        return 'The birth of Prophet Muhammad ﷺ, also known as Mawlid al-Nabi, is celebrated in Rabi al-Awwal. He was born in Mecca in 570 CE.';
      case 'Isra and Mi\'raj':
        return 'Isra and Mi\'raj is the miraculous night journey of Prophet Muhammad ﷺ from Mecca to Jerusalem and then to the heavens.';
      case 'Shab-e-Barat':
        return 'Shab-e-Barat is the night of forgiveness. It is believed that Allah forgives the sins of believers on this night.';
      case 'Month of Fasting':
        return 'Ramadan is the ninth month of the Islamic calendar. Muslims fast from dawn to sunset and increase in worship and charity.';
      case 'Eid al-Fitr':
        return 'Eid al-Fitr marks the end of Ramadan. It is a day of celebration, prayer, and giving charity (Zakat al-Fitr).';
      case 'Eid al-Adha, Hajj':
        return 'Eid al-Adha commemorates the willingness of Prophet Ibrahim to sacrifice his son. It marks the end of Hajj pilgrimage.';
      default:
        return 'A special event in the Islamic calendar.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📅 $monthName'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Arabic Name
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                arabicName,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 16),

            // Month Name
            Text(
              monthName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),

            // Event Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    '🌟 Special Event',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    events,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.orange.shade200),
                  const SizedBox(height: 12),
                  Text(
                    _getEventDescription(events),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Go Back Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
