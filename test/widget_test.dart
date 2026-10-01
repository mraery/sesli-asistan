import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sesli_asistan/models/note_item.dart';
import 'package:sesli_asistan/models/reminder_item.dart';
import 'package:sesli_asistan/widgets/note_card.dart';
import 'package:sesli_asistan/widgets/reminder_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  testWidgets('NoteCard widget test', (WidgetTester tester) async {
    final note = NoteItem(
      id: '1',
      title: 'Toplantı Notu',
      content: 'Proje teslim tarihi konuşuldu.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            note: note,
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Toplantı Notu'), findsOneWidget);
    expect(find.text('Proje teslim tarihi konuşuldu.'), findsOneWidget);
  });

  testWidgets('ReminderCard widget test', (WidgetTester tester) async {
    final reminder = ReminderItem(
      id: '2',
      title: 'Fırını Kapat',
      scheduledTime: DateTime(2026, 9, 17, 15, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReminderCard(
            reminder: reminder,
            onToggleComplete: (_) {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Fırını Kapat'), findsOneWidget);
  });
}
