import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder_item.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Yeni kanal ID: Android'in eski sessiz kanal önbelleğini geçersiz kılıp sesli alarmı zorunlu kılar
  static const String channelId = 'sesli_asistan_loud_alarm_v4';
  static const String channelName = 'Sesli Alarmlar & Hatırlatıcılar';
  static const String channelDescription =
      'Sesli Asistan yüksek sesli alarm ve uyarı bildirimleri';

  static Function(String? payload)? onNotificationTapped;

  Future<void> init() async {
    tz.initializeTimeZones();

    final now = DateTime.now();
    try {
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.timeZone(now.millisecondsSinceEpoch).offset == now.timeZoneOffset) {
          tz.setLocalLocation(loc);
          break;
        }
      }
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {}
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        onNotificationTapped?.call(details.payload);
      },
    );

    // Gerçek Android ALARM ses akışı (alarm_alert) ve güçlü titreşim deseni
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1500]);
    const alarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');

    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      sound: alarmSound,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      enableLights: true,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(channel);

    await requestPermissions();

    // Uygulama kapalıyken bildirime veya tam ekran alarma basılarak açıldıysa yakala
    try {
      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            onNotificationTapped?.call(payload);
          });
        }
      }
    } catch (_) {}
  }

  Future<bool> requestPermissions() async {
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted =
          await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
      await androidImplementation.requestFullScreenIntentPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<void> scheduleReminder(ReminderItem reminder) async {
    final scheduledDate = reminder.scheduledTime;
    final now = DateTime.now();
    // Eğer süre zaten geçmişse kesinlikle alarm kurma!
    if (scheduledDate.isBefore(now)) {
      return;
    }

    final int notificationId = reminder.id.hashCode & 0x7FFFFFFF;

    final tz.TZDateTime tzScheduledTime =
        tz.TZDateTime.from(scheduledDate, tz.local);

    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1500]);
    const alarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: alarmSound,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      enableLights: true,
      ticker: '⏰ Sesli Alarm!',
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      // Android'in en yüksek öncelikli AlarmManager.setAlarmClock API'si:
      // Ekran kapalıyken, telefon uykudayken (Doze Mode) sistemi uyandırıp tam ekran alarmı açar!
      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: '⏰ Alarm Çalıyor!',
        body: reminder.title,
        scheduledDate: tzScheduledTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: reminder.id,
      );
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id: notificationId,
          title: '⏰ Alarm Çalıyor!',
          body: reminder.title,
          scheduledDate: tzScheduledTime,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: reminder.id,
        );
      } catch (_) {
        await _notificationsPlugin.zonedSchedule(
          id: notificationId,
          title: '⏰ Alarm Çalıyor!',
          body: reminder.title,
          scheduledDate: tzScheduledTime,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminder.id,
        );
      }
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    final int notificationId = reminderId.hashCode & 0x7FFFFFFF;
    await _notificationsPlugin.cancel(id: notificationId);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000]);
    const alarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: alarmSound,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.alarm,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}
