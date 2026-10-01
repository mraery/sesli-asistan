import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder_item.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/reminder_card.dart';

class RemindersScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const RemindersScreen({super.key, required this.onDataChanged});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<ReminderItem> _reminders = [];
  bool _isLoading = true;
  String _filter = 'upcoming'; // 'upcoming', 'completed', 'all'

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final list = await StorageService.loadReminders();
    setState(() {
      _reminders = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleComplete(ReminderItem item, bool? isCompleted) async {
    final updated = item.copyWith(isCompleted: isCompleted ?? false);
    final idx = _reminders.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      setState(() {
        _reminders[idx] = updated;
      });
      await StorageService.saveReminders(_reminders);
      if (updated.isCompleted) {
        await NotificationService().cancelReminder(item.id);
      } else {
        await NotificationService().scheduleReminder(updated);
      }
      widget.onDataChanged();
    }
  }

  Future<void> _deleteReminder(ReminderItem item) async {
    setState(() {
      _reminders.removeWhere((e) => e.id == item.id);
    });
    await StorageService.saveReminders(_reminders);
    await NotificationService().cancelReminder(item.id);
    widget.onDataChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hatırlatma silindi.')),
    );
  }

  Future<void> _showAddManualDialog() async {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_alarm_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Yeni Hatırlatma'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Hatırlatılacak Şey',
                    hintText: 'Örn: Dişçiyi ara',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                  trailing: const Text('Tarih Seç', style: TextStyle(color: Colors.indigo)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_rounded),
                  title: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                  trailing: const Text('Saat Seç', style: TextStyle(color: Colors.indigo)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedTime = picked;
                        selectedDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                final text = titleController.text.trim();
                if (text.isEmpty) return;

                final targetDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final newReminder = ReminderItem(
                  id: const Uuid().v4(),
                  title: text,
                  scheduledTime: targetDateTime,
                );

                setState(() {
                  _reminders.add(newReminder);
                  _reminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
                });

                await StorageService.saveReminders(_reminders);
                await NotificationService().scheduleReminder(newReminder);
                widget.onDataChanged();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = _reminders.where((r) {
      if (_filter == 'upcoming') {
        return !r.isCompleted;
      } else if (_filter == 'completed') {
        return r.isCompleted;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüm Hatırlatıcılar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alarm_rounded),
            onPressed: _showAddManualDialog,
            tooltip: 'Elle Ekle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'upcoming', label: Text('Yaklaşan')),
                      ButtonSegment(value: 'all', label: Text('Tümü')),
                      ButtonSegment(value: 'completed', label: Text('Tamamlanan')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (set) {
                      setState(() {
                        _filter = set.first;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.alarm_off_rounded,
                                  size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 12),
                              Text(
                                'Henüz hatırlatma yok',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mikrofon tuşuna basıp konuşarak ekleyebilirsiniz',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final r = filtered[idx];
                            return ReminderCard(
                              reminder: r,
                              onToggleComplete: (val) => _toggleComplete(r, val),
                              onDelete: () => _deleteReminder(r),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Elle Ekle'),
      ),
    );
  }
}
