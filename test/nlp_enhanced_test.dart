import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_asistan/services/turkish_nlp_parser.dart';

void main() {
  final refTime = DateTime(2026, 9, 17, 10, 0); // 10:00

  test('User case: 1dk sonrası için alarm kur', () {
    final res = TurkishNlpParser.parse('1dk sonrası için alarm kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 10, 1));
  });

  test('User case: 1 dk sonrasına alarm kur', () {
    final res = TurkishNlpParser.parse('1 dk sonrasına alarm kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 10, 1));
  });

  test('User case: 1 dakika sonraya alarm', () {
    final res = TurkishNlpParser.parse('1 dakika sonraya alarm', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 10, 1));
  });

  test('User case: bir dakika sonra fırını kapat', () {
    final res = TurkishNlpParser.parse('bir dakika sonra fırını kapat', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 10, 1));
  });

  test('User case: 10 dk sonrası için', () {
    final res = TurkishNlpParser.parse('10 dk sonrası için', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 10, 10));
  });

  test('Specific hour target: saat 2ye alarm kur', () {
    final res = TurkishNlpParser.parse('saat 2ye alarm kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 14, 0));
  });

  test('Specific hour target: saat 2 için alarm kur', () {
    final res = TurkishNlpParser.parse('saat 2 için alarm kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 14, 0));
  });

  test('User case: yarına alarm kurcam', () {
    final res = TurkishNlpParser.parse('yarına alarm kurcam', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    // Should be tomorrow at 09:00 AM!
    expect(res.scheduledTime, DateTime(2026, 9, 18, 9, 0));
    expect(res.explanation, contains('Yarın'));
  });

  test('User case: yarına alarm kur', () {
    final res = TurkishNlpParser.parse('yarına alarm kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 18, 9, 0));
  });

  test('User case: yarın 8de kaldır', () {
    final res = TurkishNlpParser.parse('yarın 8de kaldır', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 18, 8, 0));
  });

  test('User case: yarın 8 buçukta toplantı', () {
    final res = TurkishNlpParser.parse('yarın 8 buçukta toplantı', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 18, 8, 30));
  });

  test('User case: akşama alarm kur', () {
    final res = TurkishNlpParser.parse('akşama alarm kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 20, 0));
  });

  test('User case: sabaha alarm kur (passed morning -> tomorrow)', () {
    // refTime is 10:00, so morning 09:00 has passed -> tomorrow 09:00
    final res = TurkishNlpParser.parse('sabaha alarm kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 18, 9, 0));
  });

  test('User case: 8de kaldır', () {
    // refTime is 10:00. 8:00 AM has passed, so "8de kaldır" schedules for next morning 08:00!
    final res = TurkishNlpParser.parse('8de kaldır', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 18, 8, 0));
  });

  test('User case: akşam 8de ara', () {
    // refTime is 10:00. "akşam 8de" schedules for today 20:00!
    final res = TurkishNlpParser.parse('akşam 8de ara', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 20, 0));
  });
}
