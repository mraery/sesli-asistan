import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder_item.dart';
import '../models/note_item.dart';
import '../services/speech_service.dart';
import '../services/turkish_nlp_parser.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/voice_wave_button.dart';
import '../widgets/reminder_card.dart';
import '../widgets/note_card.dart';
import 'reminders_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'alarm_ringing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  final NotificationService _notificationService = NotificationService();

  bool _isListening = false;
  String _currentSpokenText = '';
  String _lastFeedback = '';
  bool _isProcessing = false; // Mutex kilidi: Tek bir konuşmanın birden fazla kez kaydedilmesini %100 engeller
  String _selectedMode = 'auto'; // 'auto', 'reminder', 'note'
  String _reminderFilter = 'active'; // 'active' (Bekleyenler), 'completed' (Bitenler)

  Timer? _silenceTimer;
  Timer? _alarmTicker;
  bool _isAlarmScreenOpen = false;
  List<ReminderItem> _reminders = [];
  List<NoteItem> _notes = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initApp();

    // Süresi gelen alarmları anında yakalayıp tam ekran açan saat sayacı
    _alarmTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAlarmsDue();
    });

    NotificationService.onNotificationTapped = (payload) {
      if (!mounted) return;
      _openAlarmScreenById(payload);
    };
  }

  void _checkAlarmsDue() {
    if (_isAlarmScreenOpen || !mounted) return;
    final now = DateTime.now();
    for (final r in _reminders) {
      if (!r.isCompleted &&
          now.isAfter(r.scheduledTime) &&
          now.difference(r.scheduledTime).inSeconds < 90) {
        _triggerAlarmScreen(r);
        break;
      }
    }
  }

  void _openAlarmScreenById(String? id) {
    if (_isAlarmScreenOpen || id == null || !mounted) return;
    final r = _reminders.where((e) => e.id == id).firstOrNull;
    if (r != null) {
      _triggerAlarmScreen(r);
    }
  }

  void _triggerAlarmScreen(ReminderItem reminder) {
    if (_isAlarmScreenOpen || !mounted) return;
    _isAlarmScreenOpen = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmRingingScreen(
          reminder: reminder,
          onDismissed: () {
            _isAlarmScreenOpen = false;
            _loadData();
          },
        ),
      ),
    ).then((_) {
      _isAlarmScreenOpen = false;
      _loadData();
    });
  }

  Future<void> _initApp() async {
    await _notificationService.init();
    await _speechService.init();

    // Durum dinleyicisi sadece görsel dinleme durumunu günceller, ASLA kayıt tetiklemez
    _speechService.onStatusChanged = (status) {
      if (!mounted) return;
      if (status == 'listening') {
        if (!_isListening) setState(() => _isListening = true);
      } else if (status == 'notListening' || status == 'done') {
        if (_isListening) {
          setState(() => _isListening = false);
        }
      }
    };

    _speechService.onErrorOccurred = (error) {
      if (!mounted) return;
      if (error.contains('no_match') || error.contains('timeout')) {
        if (_isListening) {
          setState(() {
            _isListening = false;
            if (_lastFeedback == 'İşleniyor...') {
              _lastFeedback = '';
            }
          });
        }
        return;
      }
      setState(() {
        _isListening = false;
        _lastFeedback = '⚠️ Ses algılanamadı, lütfen tekrar deneyin.';
      });
    };

    _selectedMode = await StorageService.getPreferredMode();
    await _loadData();

    // Uygulamaya girildiğinde süresi geçmiş eski alarmları iptal et (böylece açılışta gereksiz ötmez)
    final now = DateTime.now();
    for (final r in _reminders) {
      if (r.scheduledTime.isBefore(now)) {
        await _notificationService.cancelReminder(r.id);
      }
    }
  }

  Future<void> _loadData() async {
    final r = await StorageService.loadReminders();
    final n = await StorageService.loadNotes();
    if (mounted) {
      setState(() {
        _reminders = r;
        _notes = n;
      });
    }
  }

  Future<void> _handleMicTap() async {
    HapticFeedback.mediumImpact();

    if (_isListening) {
      await _finishListeningAndProcess();
      return;
    }

    if (_isProcessing) return;

    final isAvailable = await _speechService.init();
    if (!isAvailable) {
      setState(() {
        _lastFeedback = '⚠️ Mikrofon izni gerekiyor. Lütfen ayarlardan izin verin.';
      });
      return;
    }

    setState(() {
      _currentSpokenText = '';
      _lastFeedback = '';
      _isListening = true;
    });

    final started = await _speechService.startListening(
      onResult: (words, isFinal) {
        if (!mounted || _isProcessing) return;

        setState(() {
          _currentSpokenText = words;
        });

        _silenceTimer?.cancel();

        if (isFinal && words.isNotEmpty) {
          _finishListeningAndProcess();
        } else if (words.isNotEmpty) {
          // Cümle bitince 1.3 saniye sessizlik olursa otomatik kaydet
          _silenceTimer = Timer(const Duration(milliseconds: 1300), () {
            if (_isListening && _currentSpokenText.isNotEmpty && !_isProcessing) {
              _finishListeningAndProcess();
            }
          });
        }
      },
    );

    if (!started) {
      setState(() {
        _isListening = false;
        _lastFeedback = '⚠️ Mikrofon başlatılamadı.';
      });
    }
  }

  Future<void> _finishListeningAndProcess() async {
    if (_isProcessing) return; // Zaten işleniyorsa çift kaydı kesinlikle engelle
    _silenceTimer?.cancel();

    final text = _currentSpokenText.trim();
    if (text.isEmpty) {
      await _speechService.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    // Metni al ve anında temizle ki tekrar tetiklenmesin
    _isProcessing = true;
    _currentSpokenText = '';
    await _speechService.stopListening();

    if (mounted) {
      setState(() {
        _isListening = false;
        _lastFeedback = 'İşleniyor...';
      });
    }

    try {
      await _processCommand(text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastFeedback = '⚠️ Komut işlenirken bir hata oluştu.';
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processCommand(String text) async {
    if (text.trim().isEmpty) return;

    ParseResult result;

    if (_selectedMode == 'note') {
      result = ParseResult(
        type: ParseActionType.note,
        title: TurkishNlpParser.parse(text).title,
        content: text,
        rawText: text,
        explanation: 'Not olarak kaydedildi.',
      );
    } else {
      result = TurkishNlpParser.parse(text);

      if (result.needsFallback) {
        final apiKey = await StorageService.getApiKey();
        final backendUrl = await StorageService.getBackendUrl();
        if (apiKey.isNotEmpty || backendUrl.isNotEmpty) {
          final aiResult = await GeminiService.parseWithAi(
            rawText: text,
            apiKey: apiKey,
            backendUrl: backendUrl,
          );
          if (aiResult != null) {
            result = aiResult;
          }
        }
      }
    }

    if (result.type == ParseActionType.reminder) {
      final scheduled = result.scheduledTime ?? DateTime.now().add(const Duration(minutes: 5));

      // Mükerrer kayıt koruması: Son 10 saniye içinde aynı isimde ve saatte kayıt varsa tekrar ekleme!
      final isDuplicate = _reminders.any((r) =>
          r.title.toLowerCase() == result.title.toLowerCase() &&
          r.scheduledTime.difference(scheduled).inSeconds.abs() < 60 &&
          DateTime.now().difference(r.createdAt).inSeconds < 10);

      if (isDuplicate) {
        if (mounted) {
          setState(() {
            _lastFeedback = '✓ Zaten listede ekli: "${result.title}"';
          });
        }
        return;
      }

      final newReminder = ReminderItem(
        id: const Uuid().v4(),
        title: result.title,
        scheduledTime: scheduled,
      );

      _reminders.add(newReminder);
      _reminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      await StorageService.saveReminders(_reminders);
      await _notificationService.scheduleReminder(newReminder);
      HapticFeedback.heavyImpact();

      if (mounted) {
        setState(() {
          _lastFeedback = '⏰ ${result.explanation}\n"${result.title}"';
          _reminderFilter = 'active';
          _tabController.animateTo(0);
        });
      }
    } else {
      // Mükerrer not koruması
      final isDuplicate = _notes.any((n) =>
          n.title.toLowerCase() == result.title.toLowerCase() &&
          DateTime.now().difference(n.createdAt).inSeconds < 10);

      if (isDuplicate) {
        if (mounted) {
          setState(() {
            _lastFeedback = '✓ Zaten notlarda var: "${result.title}"';
          });
        }
        return;
      }

      final newNote = NoteItem(
        id: const Uuid().v4(),
        title: result.title,
        content: text,
      );

      _notes.insert(0, newNote);
      await StorageService.saveNotes(_notes);
      HapticFeedback.heavyImpact();

      if (mounted) {
        setState(() {
          _lastFeedback = '📝 Not kaydedildi: "${result.title}"';
          _tabController.animateTo(1);
        });
      }
    }

    await _loadData();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _alarmTicker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeReminders = _reminders.where((r) => !r.isCompleted).toList();
    final completedReminders = _reminders.where((r) => r.isCompleted).toList();
    final displayedReminders = _reminderFilter == 'completed'
        ? completedReminders
        : activeReminders;
    final recentNotes = _notes.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.record_voice_over_rounded,
                  color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sesli Asistan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadData()),
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Mod Seçim Çipleri
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('⚡ Otomatik Akıllı'),
                    selected: _selectedMode == 'auto',
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _selectedMode = 'auto');
                        StorageService.setPreferredMode('auto');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('⏰ Sadece Hatırlat'),
                    selected: _selectedMode == 'reminder',
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _selectedMode = 'reminder');
                        StorageService.setPreferredMode('reminder');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('📝 Sadece Not'),
                    selected: _selectedMode == 'note',
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _selectedMode = 'note');
                        StorageService.setPreferredMode('note');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Ana Ses Alanı (Hero)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                VoiceWaveButton(
                  isListening: _isListening,
                  onTap: _handleMicTap,
                ),
                const SizedBox(height: 12),
                Text(
                  _isListening
                      ? 'Dinleniyor... (Konuşmanız bittiğinde otomatik ekler)'
                      : (_isProcessing
                          ? 'İşleniyor...'
                          : 'Mikrofona Dokun ve Konuş'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isListening
                        ? Colors.redAccent
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currentSpokenText.isNotEmpty
                      ? '"$_currentSpokenText"'
                      : 'Örn: "1 dakika sonrası için alarm kur" veya "Not al..."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _currentSpokenText.isNotEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontStyle: _currentSpokenText.isNotEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: _currentSpokenText.isNotEmpty
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),

                // Konuşurken anında tamamlama butonu
                if (_isListening && _currentSpokenText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: _finishListeningAndProcess,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Şimdi Kaydet (Bitti)'),
                  ),
                ],

                if (_lastFeedback.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _lastFeedback,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Alt Liste Başlık ve Sekmeler
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.alarm_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Hatırlatıcılar (${activeReminders.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notes_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Son Notlar (${recentNotes.length})'),
                  ],
                ),
              ),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Hatırlatıcılar sekmesi
                Column(
                  children: [
                    // Bekleyenler / Bitenler Filtre Çipleri
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          FilterChip(
                            selected: _reminderFilter == 'active',
                            avatar: Icon(
                              Icons.alarm_rounded,
                              size: 16,
                              color: _reminderFilter == 'active'
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            label: Text(
                                'Bekleyenler (${activeReminders.length})'),
                            onSelected: (_) =>
                                setState(() => _reminderFilter = 'active'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: _reminderFilter == 'completed',
                            selectedColor: Colors.green.withValues(alpha: 0.2),
                            checkmarkColor: Colors.green,
                            avatar: Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: _reminderFilter == 'completed'
                                  ? Colors.green
                                  : null,
                            ),
                            label: Text(
                              'Bitenler (${completedReminders.length})',
                              style: TextStyle(
                                color: _reminderFilter == 'completed'
                                    ? Colors.green.shade700
                                    : null,
                                fontWeight: _reminderFilter == 'completed'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onSelected: (_) =>
                                setState(() => _reminderFilter = 'completed'),
                          ),
                          const Spacer(),
                          if (_reminderFilter == 'completed' &&
                              completedReminders.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Bitenleri Temizle'),
                                    content: const Text(
                                        'Tamamlanan tüm hatırlatıcılar silinsin mi?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Vazgeç'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Temizle'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _reminders.removeWhere((r) => r.isCompleted);
                                  await StorageService.saveReminders(
                                      _reminders);
                                  _loadData();
                                }
                              },
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: theme.colorScheme.error,
                              ),
                              child: const Text('Temizle',
                                  style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),

                    // Hatırlatıcı Listesi
                    Expanded(
                      child: displayedReminders.isEmpty
                          ? Center(
                              child: Text(
                                _reminderFilter == 'completed'
                                    ? 'Henüz tamamlanan hatırlatıcı yok.'
                                    : 'Bekleyen hatırlatıcı yok.',
                                style:
                                    TextStyle(color: theme.colorScheme.outline),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              itemCount: displayedReminders.length + 1,
                              itemBuilder: (context, idx) {
                                if (idx == displayedReminders.length) {
                                  return Center(
                                    child: TextButton.icon(
                                      icon: const Icon(
                                          Icons.arrow_forward_rounded),
                                      label:
                                          const Text('Tüm Hatırlatıcıları Gör'),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RemindersScreen(
                                            onDataChanged: _loadData,
                                          ),
                                        ),
                                      ).then((_) => _loadData()),
                                    ),
                                  );
                                }
                                final r = displayedReminders[idx];
                                return ReminderCard(
                                  reminder: r,
                                  onToggleComplete: (val) async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final isDone = val ?? false;
                                    final updated =
                                        r.copyWith(isCompleted: isDone);
                                    final itemIdx = _reminders
                                        .indexWhere((e) => e.id == r.id);
                                    if (itemIdx != -1) {
                                      _reminders[itemIdx] = updated;
                                      await StorageService.saveReminders(
                                          _reminders);
                                      if (updated.isCompleted) {
                                        await _notificationService
                                            .cancelReminder(r.id);
                                        HapticFeedback.lightImpact();
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '✓ "${r.title}" Bitenler bölümüne taşındı.'),
                                              duration:
                                                  const Duration(seconds: 2),
                                              backgroundColor:
                                                  Colors.green.shade800,
                                            ),
                                          );
                                        }
                                      } else {
                                        if (updated.scheduledTime
                                            .isAfter(DateTime.now())) {
                                          await _notificationService
                                              .scheduleReminder(updated);
                                        }
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '"${r.title}" Bekleyenlere geri alındı.'),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                      _loadData();
                                    }
                                  },
                                  onDelete: () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    _reminders.removeWhere((e) => e.id == r.id);
                                    await StorageService.saveReminders(
                                        _reminders);
                                    await _notificationService
                                        .cancelReminder(r.id);
                                    _loadData();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Hatırlatıcı silindi.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // Notlar sekmesi
                recentNotes.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz not alınmamış.',
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: recentNotes.length + 1,
                        itemBuilder: (context, idx) {
                          if (idx == recentNotes.length) {
                            return Center(
                              child: TextButton.icon(
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Tüm Notları Gör'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NotesScreen(
                                      onDataChanged: _loadData,
                                    ),
                                  ),
                                ).then((_) => _loadData()),
                              ),
                            );
                          }
                          final n = recentNotes[idx];
                          return NoteCard(
                            note: n,
                            onDelete: () async {
                              _notes.removeWhere((e) => e.id == n.id);
                              await StorageService.saveNotes(_notes);
                              _loadData();
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
