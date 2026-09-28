import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // 타임존 초기화
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // Android 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('[Notification] 알림 클릭: ${response.payload}');
      },
    );

    _initialized = true;
    print('[Notification] 초기화 완료');
  }

  // 알림 권한 요청
  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  // 매일 반복 알림 스케줄링
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 이미 지난 시간이면 다음 날로 설정
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_reminder',
          '식사 알림',
          channelDescription: '식사 시간 알림',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
      payload: 'meal_$id',
    );

    print('[Notification] 알림 스케줄: ID=$id, $hour:$minute');
  }

  // 알림 취소
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    print('[Notification] 알림 취소: ID=$id');
  }

  // 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('[Notification] 모든 알림 취소');
  }

  // 저장된 설정으로 알림 스케줄링
  Future<void> scheduleFromSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final mealReminder = prefs.getBool('mealReminder') ?? true;
    if (!mealReminder) {
      await cancelAllNotifications();
      return;
    }

    // 아침 알림
    final breakfastEnabled = prefs.getBool('breakfastReminder') ?? true;
    if (breakfastEnabled) {
      final hour = prefs.getInt('breakfastHour') ?? 8;
      final minute = prefs.getInt('breakfastMinute') ?? 0;
      await scheduleDailyNotification(
        id: 1,
        title: '아침 식사 시간',
        body: '건강한 아침 식사로 하루를 시작하세요!',
        hour: hour,
        minute: minute,
      );
    } else {
      await cancelNotification(1);
    }

    // 점심 알림
    final lunchEnabled = prefs.getBool('lunchReminder') ?? true;
    if (lunchEnabled) {
      final hour = prefs.getInt('lunchHour') ?? 12;
      final minute = prefs.getInt('lunchMinute') ?? 0;
      await scheduleDailyNotification(
        id: 2,
        title: '점심 식사 시간',
        body: '맛있는 점심 드셨나요? 식사 기록을 남겨보세요!',
        hour: hour,
        minute: minute,
      );
    } else {
      await cancelNotification(2);
    }

    // 저녁 알림
    final dinnerEnabled = prefs.getBool('dinnerReminder') ?? true;
    if (dinnerEnabled) {
      final hour = prefs.getInt('dinnerHour') ?? 18;
      final minute = prefs.getInt('dinnerMinute') ?? 30;
      await scheduleDailyNotification(
        id: 3,
        title: '저녁 식사 시간',
        body: '오늘 하루 식단은 어땠나요? 저녁 기록도 잊지 마세요!',
        hour: hour,
        minute: minute,
      );
    } else {
      await cancelNotification(3);
    }
  }

  // 즉시 테스트 알림
  Future<void> showTestNotification() async {
    await _notifications.show(
      0,
      '테스트 알림',
      '알림이 정상적으로 작동합니다!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          '테스트',
          channelDescription: '테스트 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
