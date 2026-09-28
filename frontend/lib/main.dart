import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  DatabaseService.initialize();

  // 알림 서비스 초기화 (지원하지 않는 플랫폼에서 실패해도 앱은 실행)
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.requestPermission();
    await notificationService.scheduleFromSettings();
  } catch (e) {
    print('[Notification] 초기화 건너뜀: $e');
  }

  // API 설정 정보 출력 (디버깅용)
  ApiConfig.printConfig();

  runApp(const JjikBapApp());
}

class JjikBapApp extends StatelessWidget {
  const JjikBapApp({super.key});

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');

    if (userId != null) {
      final databaseService = DatabaseService();
      final user = await databaseService.getUserById(userId);
      if (user != null) {
        return const HomeScreen();
      }
    }

    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '찍밥',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF81C784),
          tertiary: const Color(0xFFA5D6A7),
          surface: Colors.white,
          background: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Paperlogy',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w700),
          displayMedium: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w700),
          displaySmall: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w600),
          headlineLarge: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w600),
          labelMedium: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w500),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          titleTextStyle: TextStyle(
            fontFamily: 'Paperlogy',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black.withOpacity(0.1),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Paperlogy',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4CAF50),
                ),
              ),
            );
          }
          return snapshot.data ?? const LoginScreen();
        },
      ),
    );
  }
}
