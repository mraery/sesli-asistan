import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_asistan/services/turkish_nlp_parser.dart';

void main() {
  final refTime = DateTime(2026, 9, 17, 10, 0); // 10:00

  test('Relative minutes: 15 dakika sonra fırını kapat', () {
    final res = TurkishNlpParser.parse('15 dakika sonra fırını kapat', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 10, 15));
    expect(res.title.toLowerCase().contains('fırın'), true);
  });

  test('Specific afternoon hour: saat 2\'de Ahmet\'i ara', () {
    final res = TurkishNlpParser.parse("saat 2'de Ahmet'i ara", referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 14, 0));
    expect(res.title.toLowerCase().contains('ahmet'), true);
  });

  test('Tomorrow morning: yarın sabah 9\'da fatura öde', () {
    final res = TurkishNlpParser.parse("yarın sabah 9'da fatura öde", referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 18, 9, 0));
    expect(res.title.toLowerCase().contains('fatura'), true);
  });

  test('Yarım saat sonra ilacını al', () {
    final res = TurkishNlpParser.parse('yarım saat sonra ilacını al', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 10, 30));
  });

  test('Explicit note test: not al proje için yeni fikirler', () {
    final res = TurkishNlpParser.parse('not al proje için yeni fikirler', referenceTime: refTime);
    expect(res.type, ParseActionType.note);
    expect(res.title.toLowerCase().contains('proje'), true);
  });
}
