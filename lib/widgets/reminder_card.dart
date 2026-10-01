import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder_item.dart';

class ReminderCard extends StatelessWidget {
  final ReminderItem reminder;
  final ValueChanged<bool?> onToggleComplete;
  final VoidCallback onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onToggleComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = reminder.isCompleted;
    final scheduled = reminder.scheduledTime;
    final now = DateTime.now();
    final isPast = scheduled.isBefore(now) && !isDone;

    final dateFormat = DateFormat('d MMMM, HH:mm', 'tr_TR');
    final timeStr = dateFormat.format(scheduled);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDone
              ? Colors.green.withValues(alpha: 0.5)
              : (isPast
                  ? Colors.redAccent.withValues(alpha: 0.4)
                  : theme.colorScheme.primary.withValues(alpha: 0.3)),
          width: 1.2,
        ),
      ),
      color: isDone
          ? Colors.green.withValues(alpha: 0.07)
          : theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: reminder.isCompleted,
              activeColor: Colors.green,
              checkColor: Colors.white,
              onChanged: onToggleComplete,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.green,
                      color: isDone
                          ? Colors.green.shade600
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : Icons.access_time_rounded,
                        size: 14,
                        color: isDone
                            ? Colors.green
                            : (isPast
                                ? Colors.redAccent
                                : theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDone
                              ? Colors.green.shade600
                              : (isPast
                                  ? Colors.redAccent
                                  : theme.colorScheme.primary),
                        ),
                      ),
                      if (isDone) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '✓ Bitti',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (isPast) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Süresi Geçti',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: theme.colorScheme.error,
              onPressed: onDelete,
              tooltip: 'Sil',
            ),
          ],
        ),
      ),
    );
  }
}
