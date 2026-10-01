import 'dart:convert';
import 'package:http/http.dart' as http;
import 'turkish_nlp_parser.dart';

class GeminiService {
  static const String _defaultModel = 'gemini-1.5-flash';

  static Future<ParseResult?> parseWithAi({
    required String rawText,
    required String apiKey,
    String? backendUrl,
    DateTime? referenceTime,
  }) async {
    final now = referenceTime ?? DateTime.now();

    // Eğer backend URL verilmişse doğrudan kendi sunucumuza sorarız
    if (backendUrl != null && backendUrl.trim().isNotEmpty) {
      return _queryCustomBackend(backendUrl, rawText, now);
    }

    if (apiKey.trim().isEmpty) {
      return null;
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_defaultModel:generateContent?key=$apiKey',
    );

    final systemInstruction = '''
Sen bir Türkçe sesli asistan beynisin. Kullanıcı sana sesli bir komut söyledi.
Şu anki tarih ve saat: ${now.toIso8601String()} (Yıl-Ay-Gün T Saat:Dakika:Saniye).

Görevin bu cümleyi analiz edip YALNIZCA şu JSON formatında yanıt vermektir:
{
  "type": "reminder" | "note",
  "title": "kullanıcının yapacağı asıl eylem (temizlenmiş başlık)",
  "target_time": "YYYY-MM-DDTHH:mm:ss" (eğer type=reminder ise ISO formatında gelecekteki tarih, note ise null),
  "content": "varsa ek detaylar veya orijinal metin",
  "explanation": "kullanıcıya Türkçe kısa onay mesajı (örn: Yarın 15:00 için hatırlatıcı kuruldu)"
}
JSON dışında hiçbir selamlama, markdown işareti veya ek metin üretme.
''';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '$systemInstruction\n\nKullanıcı komutu: "$rawText"'}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.1,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final contentText = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (contentText != null) {
          final jsonResult = jsonDecode(contentText.trim());
          final typeStr = jsonResult['type'] as String? ?? 'note';
          final title = jsonResult['title'] as String? ?? rawText;
          final targetTimeStr = jsonResult['target_time'] as String?;
          final explanation = jsonResult['explanation'] as String? ?? 'AI tarafından işlendi.';

          DateTime? scheduledTime;
          if (targetTimeStr != null && targetTimeStr.isNotEmpty) {
            scheduledTime = DateTime.tryParse(targetTimeStr);
          }

          return ParseResult(
            type: typeStr == 'reminder' ? ParseActionType.reminder : ParseActionType.note,
            title: title,
            content: rawText,
            scheduledTime: scheduledTime,
            needsFallback: false,
            rawText: rawText,
            explanation: explanation,
          );
        }
      }
    } catch (_) {
      // Hata durumunda null dönülür ve yerel parser sonucu kullanılır
    }

    return null;
  }

  static Future<ParseResult?> _queryCustomBackend(
    String backendUrl,
    String rawText,
    DateTime now,
  ) async {
    try {
      final url = Uri.parse(backendUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': rawText,
          'current_time': now.toIso8601String(),
        }),
      );
      if (response.statusCode == 200) {
        final jsonResult = jsonDecode(utf8.decode(response.bodyBytes));
        final typeStr = jsonResult['type'] as String? ?? 'note';
        final title = jsonResult['title'] as String? ?? rawText;
        final targetTimeStr = jsonResult['target_time'] as String?;
        final explanation = jsonResult['explanation'] as String? ?? 'Sunucu tarafından işlendi.';

        DateTime? scheduledTime;
        if (targetTimeStr != null && targetTimeStr.isNotEmpty) {
          scheduledTime = DateTime.tryParse(targetTimeStr);
        }

        return ParseResult(
          type: typeStr == 'reminder' ? ParseActionType.reminder : ParseActionType.note,
          title: title,
          content: rawText,
          scheduledTime: scheduledTime,
          needsFallback: false,
          rawText: rawText,
          explanation: explanation,
        );
      }
    } catch (_) {}
    return null;
  }
}
