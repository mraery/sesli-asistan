import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/reminder_item.dart';
import '../services/alarm_sound_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AlarmRingingScreen extends StatefulWidget {
  final ReminderItem reminder;
  final VoidCallback? onDismissed;

  const AlarmRingingScreen({
    super.key,
    required this.reminder,
    this.onDismissed,
  });

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  Timer? _clockTimer;
  Timer? _vibrateTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Tam ekran alarm sesini anında başlat
    AlarmSoundService().playAlarmSound();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    // Ritmik alarm titreşimi
    _vibrateTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _vibrateTimer?.cancel();
    _pulseController.dispose();
    AlarmSoundService().stopAlarmSound();
    super.dispose();
  }

  Future<void> _dismissAlarm() async {
    await AlarmSoundService().stopAlarmSound();

    // Hatırlatıcıyı tamamlandı olarak işaretle
    final reminders = await StorageService.loadReminders();
    final idx = reminders.indexWhere((r) => r.id == widget.reminder.id);
    if (idx != -1) {
      reminders[idx] = reminders[idx].copyWith(isCompleted: true);
      await StorageService.saveReminders(reminders);
    }
    await NotificationService().cancelReminder(widget.reminder.id);

    widget.onDismissed?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _snoozeAlarm() async {
    await AlarmSoundService().stopAlarmSound();

    // 5 dakika sonraya ertele
    final newTime = DateTime.now().add(const Duration(minutes: 5));
    final updated = widget.reminder.copyWith(
      scheduledTime: newTime,
      isCompleted: false,
    );

    final reminders = await StorageService.loadReminders();
    final idx = reminders.indexWhere((r) => r.id == widget.reminder.id);
    if (idx != -1) {
      reminders[idx] = updated;
      await StorageService.saveReminders(reminders);
    }
    await NotificationService().scheduleReminder(updated);

    widget.onDismissed?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');

    return PopScope(
      canPop: false, // Yanlışlıkla geri tuşuna basarak kapatılmasını önler
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0814),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.2,
              colors: [
                Color(0xFF831843), // Canlı kırmızı/mor parıltı
                Color(0xFF2E0827),
                Color(0xFF0F0814),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Üst başlık & tarih
                  Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ALARM ÇALIYOR!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dateFormat.format(_currentTime),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),

                  // Orta: Çalan Zil & Büyük Saat & Görev Adı
                  Column(
                    children: [
                      AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withValues(alpha: 0.6),
                                    blurRadius: 40,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.alarm_on_rounded,
                                size: 84,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 36),
                      Text(
                        timeFormat.format(_currentTime),
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          widget.reminder.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Alt: Büyük Kapat ve Ertele Butonları
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: _dismissAlarm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.redAccent.withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 28),
                          label: const Text(
                            'ALARMI KAPAT / DURDUR',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _snoozeAlarm,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.snooze_rounded, size: 22),
                          label: const Text(
                            '5 Dakika Ertele',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
