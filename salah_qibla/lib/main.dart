import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'Screens/home_screen.dart';
import 'Screens/prayer_screen.dart';
import 'Screens/explore_screen.dart';
import 'Screens/messages_screen.dart'; // contains class MessagesPage
import 'Screens/me_screen.dart';
import 'Services/azaan_alarm_service.dart';
import 'Services/notification_service.dart';
import 'Services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone database aur notification channels app shuru hone se pehle
  // tayyar hone chahiyen, warna tz.local LateInitializationError deta hai.
  await NotificationService.initialize();

  // Azaan ka background alarm nizam. Ye AndroidAlarmManager ko boot karta
  // hai — iske baghair namaz ke waqt koi azaan nahi bajti. Pehle ye kabhi
  // bulaya hi nahi jata tha.
  await AzaanAlarmService().init();

  // Jumma, Surah Al-Kahf aur Surah Ar-Rahman ke reminders namaz ke auqaat
  // ka intezar nahi karte, is liye yahin set kar dete hain. Namaz se
  // pehle wale reminders home screen se lagte hain — jab asal auqaat
  // API se aa jate hain.
  final settings = await StorageService().getReminderSettings();
  await NotificationService.rescheduleAll(settings: settings);

  runApp(
    const ProviderScope(
      child: SalahNowApp(),
    ),
  );
}

class SalahNowApp extends StatelessWidget {
  const SalahNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SalaH Now',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Order matches bottom nav bar: Home, Prayer, Explore, Messages, Me
  final List<Widget> _screens = [
    const HomeScreen(),
    const PrayerScreen(),
    const ExploreScreen(),
    const MessagesPage(),
    const MeScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each screen's state alive when switching tabs
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0D3B26),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mosque),
            label: 'Prayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}