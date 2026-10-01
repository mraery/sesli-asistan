import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_asistan/services/turkish_nlp_parser.dart';

void main() {
  final refTime = DateTime(2026, 9, 17, 10, 0);

  test('Misrecognized "adam kur": 1dk sonrası için adam kur', () {
    final res = TurkishNlpParser.parse('1dk sonrası için adam kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.scheduledTime, DateTime(2026, 9, 17, 10, 1));
    expect(res.title.toLowerCase().contains('adam'), false); // "adam" should NOT be the title!
  });

  test('Misrecognized "alan kur": 5 dakika sonra alan kur', () {
    final res = TurkishNlpParser.parse('5 dakika sonra alan kur', referenceTime: refTime);
    expect(res.type, ParseActionType.reminder);
    expect(res.title.toLowerCase().contains('alan'), false);
  });
}
