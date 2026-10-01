enum ParseActionType { reminder, note }

class ParseResult {
  final ParseActionType type;
  final String title;
  final String content;
  final DateTime? scheduledTime;
  final bool needsFallback;
  final String rawText;
  final String explanation;

  ParseResult({
    required this.type,
    required this.title,
    this.content = '',
    this.scheduledTime,
    this.needsFallback = false,
    required this.rawText,
    required this.explanation,
  });
}

class TurkishNlpParser {
  static const Map<String, int> _wordNumbers = {
    'bir': 1,
    'iki': 2,
    'üç': 3,
    'uc': 3,
    'dört': 4,
    'dort': 4,
    'beş': 5,
    'bes': 5,
    'altı': 6,
    'alti': 6,
    'yedi': 7,
    'sekiz': 8,
    'dokuz': 9,
    'on': 10,
    'on bir': 11,
    'on iki': 12,
    'yirmi': 20,
    'otuz': 30,
    'kırk': 40,
    'kirk': 40,
    'elli': 50,
  };

  static const Map<String, int> _weekdays = {
    'pazartesi': DateTime.monday,
    'salı': DateTime.tuesday,
    'sali': DateTime.tuesday,
    'çarşamba': DateTime.wednesday,
    'carsamba': DateTime.wednesday,
    'perşembe': DateTime.thursday,
    'persembe': DateTime.thursday,
    'cuma': DateTime.friday,
    'cumartesi': DateTime.saturday,
    'pazar': DateTime.sunday,
  };

  static ParseResult parse(String input, {DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final rawText = input.trim();
    if (rawText.isEmpty) {
      return ParseResult(
        type: ParseActionType.note,
        title: 'Boş Not',
        content: '',
        needsFallback: false,
        rawText: rawText,
        explanation: 'İçerik belirtilmedi.',
      );
    }

    // Fonetik STT düzeltmesi: Google Speech 'alarm kur' yerine bazen 'adam kur', 'alan kur' algılar
    String normalized = _normalize(rawText);
    normalized = normalized
        .replaceAll(RegExp(r'\b(?:adam|alan|adım)\s*kur', caseSensitive: false), 'alarm kur')
        .replaceAll(RegExp(r'\b(?:adam|alan|adım)\s*için', caseSensitive: false), 'alarm için')
        .replaceAll(RegExp(r'\b(?:adam|alan|adım)\b', caseSensitive: false), 'alarm');

    final isExplicitNote = _isExplicitNote(normalized);
    final hasReminderKeywords = _hasReminderKeywords(normalized);

    // Açıkça not denmişse ve hatırlatma anahtar kelimesi/zaman yoksa direkt not al
    if (isExplicitNote && !hasReminderKeywords) {
      final noteTitle = _cleanNoteTitle(rawText);
      return ParseResult(
        type: ParseActionType.note,
        title: noteTitle,
        content: rawText,
        needsFallback: false,
        rawText: rawText,
        explanation: 'Not olarak kaydedildi.',
      );
    }

    // 2. Zaman Çözümlemesi
    final scheduledTime = _extractDateTime(normalized, now);

    if (scheduledTime != null) {
      String reminderTitle = _cleanReminderTitle(normalized);
      final invalidTitles = ['adam', 'alan', 'alarm', 'kur', 'hatirlat', 'hatirlatma', 'icin', ''];

      if (invalidTitles.contains(reminderTitle.toLowerCase())) {
        final diffMin = scheduledTime.difference(now).inMinutes;
        if (diffMin > 0 && diffMin < 60) {
          reminderTitle = '$diffMin Dakikalık Alarm';
        } else {
          reminderTitle = 'Sesli Alarm';
        }
      }

      final diff = scheduledTime.difference(now);
      String exp;
      if (diff.inSeconds <= 90) {
        exp = '1 dakika sonrası için alarm kuruldu.';
      } else if (scheduledTime.day != now.day) {
        final tomorrow = now.add(const Duration(days: 1));
        if (scheduledTime.year == tomorrow.year &&
            scheduledTime.month == tomorrow.month &&
            scheduledTime.day == tomorrow.day) {
          exp = 'Yarın saat ${_pad(scheduledTime.hour)}:${_pad(scheduledTime.minute)} için alarm kuruldu.';
        } else {
          exp = '${scheduledTime.day}.${scheduledTime.month} saat ${_pad(scheduledTime.hour)}:${_pad(scheduledTime.minute)} için alarm kuruldu.';
        }
      } else {
        exp = 'Bugün saat ${_pad(scheduledTime.hour)}:${_pad(scheduledTime.minute)} için kuruldu.';
      }

      return ParseResult(
        type: ParseActionType.reminder,
        title: reminderTitle,
        content: rawText,
        scheduledTime: scheduledTime,
        needsFallback: false,
        rawText: rawText,
        explanation: exp,
      );
    }

    // Zaman bulunamadı, ama hatırlatma denmişse
    if (hasReminderKeywords) {
      return ParseResult(
        type: ParseActionType.reminder,
        title: _cleanReminderTitle(normalized),
        content: rawText,
        needsFallback: true,
        rawText: rawText,
        explanation: 'Zaman tam anlaşılamadı, akıllı analiz deneniyor...',
      );
    }

    // Varsayılan: Not olarak kaydet
    return ParseResult(
      type: ParseActionType.note,
      title: _cleanNoteTitle(rawText),
      content: rawText,
      needsFallback: false,
      rawText: rawText,
      explanation: 'Hızlı not olarak kaydedildi.',
    );
  }

  static bool _isExplicitNote(String text) {
    final notePatterns = [
      r'\bnot\s*(?:al|et|yaz|kaydet|al\w*|ed\w*)',
      r'\bnotum\s*şu',
      r'\bbunu\s*not\s*(?:al|et)',
    ];
    for (final p in notePatterns) {
      if (RegExp(p).hasMatch(text)) return true;
    }
    return false;
  }

  static bool _hasReminderKeywords(String text) {
    final reminderPatterns = [
      r'\bhatırlat',
      r'\bhatirlat',
      r'\balarm',
      r'\brandevu',
      r'\bsaat',
      r'\bdakika',
      r'\bdk',
      r'\byarın',
      r'\byarin',
      r'\bbugün',
      r'\bbugun',
      r'\bsonra',
      r'\bkur\b',
      r'\bkurcam\b',
      r'\bkuracağım\b',
      r'\bkuracagim\b',
      r'\buyan\b',
      r'\bkaldır\b',
      r'\bkaldir\b',
    ];
    for (final p in reminderPatterns) {
      if (RegExp(p).hasMatch(text)) return true;
    }
    return false;
  }

  static DateTime? _extractDateTime(String text, DateTime now) {
    final numWordsPattern = _wordNumbers.keys.join('|');

    // 1. Göreceli dakikalar: "15 dakika sonra", "10 dk sonrası için", "1dk", vb.
    final relativeMinuteRegex = RegExp(
      r'(?:(\d+)|(' + numWordsPattern + r'))\s*(?:dakika|dk)\s*(?:sonra\w*|sonras\w*|için\w*|icin\w*|içerisinde)?',
      caseSensitive: false,
    );
    final matchRelMin = relativeMinuteRegex.firstMatch(text);
    if (matchRelMin != null) {
      final numStr = matchRelMin.group(1) ?? matchRelMin.group(2);
      final mins = _parseNumber(numStr ?? '1') ?? 1;
      return now.add(Duration(minutes: mins));
    }

    final directDkRegex = RegExp(r'(\d+)\s*dk\b');
    final matchDirectDk = directDkRegex.firstMatch(text);
    if (matchDirectDk != null) {
      final mins = int.parse(matchDirectDk.group(1)!);
      return now.add(Duration(minutes: mins));
    }

    if (text.contains('yarım saat sonra') || text.contains('yarim saat sonra') || text.contains('yarım saat sonrası')) {
      return now.add(const Duration(minutes: 30));
    }

    if (text.contains('çeyrek saat sonra') || text.contains('ceyrek saat sonra')) {
      return now.add(const Duration(minutes: 15));
    }

    // 2. Göreceli saatler: "1 saat sonra", "2 saat sonrasına"
    final relativeHourRegex = RegExp(
      r'(?:(\d+)|(' + numWordsPattern + r'))\s*(?:saat|st)\s*(?:sonra\w*|sonras\w*|için\w*|icin\w*)?',
      caseSensitive: false,
    );
    final matchRelHour = relativeHourRegex.firstMatch(text);
    if (matchRelHour != null) {
      final numStr = matchRelHour.group(1) ?? matchRelHour.group(2);
      final hours = _parseNumber(numStr ?? '1') ?? 1;
      return now.add(Duration(hours: hours));
    }

    // 3. Göreceli günler: "2 gün sonra"
    final relativeDayRegex = RegExp(
      r'(?:(\d+)|(' + numWordsPattern + r'))\s*gün\s*(?:sonra\w*|sonras\w*)?',
      caseSensitive: false,
    );
    final matchRelDay = relativeDayRegex.firstMatch(text);
    if (matchRelDay != null) {
      final numStr = matchRelDay.group(1) ?? matchRelDay.group(2);
      final days = _parseNumber(numStr ?? '1') ?? 1;
      return now.add(Duration(days: days));
    }

    // 4. Gün belirleme (Bugün, Yarın, Haftanın Günleri, vb.)
    int dayOffset = 0;
    bool daySpecified = false;

    if (text.contains('yarından sonra') || text.contains('öbür gün') || text.contains('obur gun') || text.contains('öbür güne')) {
      dayOffset = 2;
      daySpecified = true;
    } else if (text.contains('yarın') || text.contains('yarin') || text.contains('yarına') || text.contains('yarina')) {
      dayOffset = 1;
      daySpecified = true;
    } else if (text.contains('bugün') || text.contains('bugun') || text.contains('bugüne') || text.contains('bugune')) {
      dayOffset = 0;
      daySpecified = true;
    }

    for (final entry in _weekdays.entries) {
      if (text.contains(entry.key)) {
        int diff = entry.value - now.weekday;
        if (diff <= 0) diff += 7;
        dayOffset = diff;
        daySpecified = true;
        break;
      }
    }

    // 5. Saat belirleme
    int? targetHour;
    int targetMinute = 0;

    // A) Dijital format: 14:30, 8.15
    final digitalRegex = RegExp(r'(?:saat\s*)?(\d{1,2})[:.](\d{2})');
    final matchDigital = digitalRegex.firstMatch(text);
    if (matchDigital != null) {
      targetHour = int.parse(matchDigital.group(1)!);
      targetMinute = int.parse(matchDigital.group(2)!);
    }

    // B) Buçuk: "8 buçukta", "saat 8 buçuk", "sekiz buçuk"
    if (targetHour == null) {
      final bucukRegex = RegExp(r'(?:saat\s*)?(\d{1,2}|' + numWordsPattern + r')\s*(?:buçuk|bucuk)\w*');
      final matchBucuk = bucukRegex.firstMatch(text);
      if (matchBucuk != null) {
        targetHour = _parseNumber(matchBucuk.group(1)!);
        targetMinute = 30;
      }
    }

    // C) Çeyrek: "8 çeyrek", "saat 9 çeyrekte"
    if (targetHour == null) {
      final ceyrekRegex = RegExp(r'(?:saat\s*)?(\d{1,2}|' + numWordsPattern + r')\s*(?:çeyrek|ceyrek)\w*');
      final matchCeyrek = ceyrekRegex.firstMatch(text);
      if (matchCeyrek != null) {
        targetHour = _parseNumber(matchCeyrek.group(1)!);
        targetMinute = 15;
      }
    }

    // D) Saat kelimesi ile: "saat 8'de", "saat 2 için", "saat sekizde"
    if (targetHour == null) {
      final hourWithSaatRegex = RegExp(
        r"(?:saat\s*)(\d{1,2}|" + numWordsPattern + r")(?:\b|['’]?(?:de|da|te|ta|ye|ya|e|a)\b|\s*(?:için|icin)\b)",
        caseSensitive: false,
      );
      final matchHourWithSaat = hourWithSaatRegex.firstMatch(text);
      if (matchHourWithSaat != null) {
        targetHour = _parseNumber(matchHourWithSaat.group(1)!);
        targetMinute = 0;
      }
    }

    // E) "saat" kelimesi olmadan saat + ek: "8'de", "8de", "sekizde", "dokuzda", "8'e", "8e", "8 için"
    if (targetHour == null) {
      final directHourRegex = RegExp(
        r"\b(\d{1,2}|" + numWordsPattern + r")(?:['’]?(?:de|da|te|ta|ye|ya|e|a)\b|\s*(?:için|icin)\b)",
        caseSensitive: false,
      );
      final matchDirectHour = directHourRegex.firstMatch(text);
      if (matchDirectHour != null) {
        final parsed = _parseNumber(matchDirectHour.group(1)!);
        if (parsed != null && parsed >= 1 && parsed <= 24) {
          targetHour = parsed;
          targetMinute = 0;
        }
      }
    }

    // F) Vakit kelimeleri
    if (targetHour == null) {
      if (text.contains('sabah') || text.contains('sabaha')) {
        targetHour = 9;
      } else if (text.contains('öğlen') || text.contains('oglen') || text.contains('öğlene') || text.contains('öğle')) {
        targetHour = 13;
      } else if (text.contains('akşam') || text.contains('aksam') || text.contains('akşama') || text.contains('aksama')) {
        targetHour = 20;
      } else if (text.contains('gece') || text.contains('geceye')) {
        targetHour = 22;
      }
    }

    // G) Gün belirtilmiş (örn: "yarına alarm kur", "yarın hatırlat", "pazartesiye kur") ama SAAT BELİRTİLMEMİŞSE:
    // Doğal varsayılan sabah 09:00'dur!
    if (targetHour == null && daySpecified) {
      targetHour = 9;
      targetMinute = 0;
    }

    if (targetHour != null) {
      final isEvening = text.contains('akşam') || text.contains('aksam') || text.contains('gece') || text.contains('akşama');
      final isAfternoon = text.contains('öğleden sonra') || text.contains('ogleden sonra');

      if ((isEvening || isAfternoon) && targetHour < 12) {
        targetHour += 12;
      } else if (targetHour < 12 && !text.contains('sabah') && !text.contains('sabaha')) {
        if (targetHour >= 1 && targetHour <= 7) {
          if (dayOffset == 0 && now.hour >= targetHour) {
            targetHour += 12;
          }
        }
      }

      var targetDate = DateTime(
        now.year,
        now.month,
        now.day + dayOffset,
        targetHour,
        targetMinute,
      );

      if (dayOffset == 0 && targetDate.isBefore(now)) {
        targetDate = targetDate.add(const Duration(days: 1));
      }

      return targetDate;
    }

    return null;
  }

  static int? _parseNumber(String input) {
    final clean = input.trim().toLowerCase();
    final parsed = int.tryParse(clean);
    if (parsed != null) return parsed;
    return _wordNumbers[clean];
  }

  static String _cleanReminderTitle(String raw) {
    String res = raw;
    final removals = [
      r'\b(?:bana|lütfen|lutfen)\b',
      r'\b(?:hatırlat(?:ır mısın|ır mısınız|)|hatirlat(?:ir misin|)?)\b',
      r"\b(?:saat\s*\d{1,2}(?:[:.]\d{2})?(?:\s*(?:buçuk|bucuk|çeyrek|ceyrek))?(?:['’]?(?:de|da|te|ta|ye|ya|e|a))?)\b",
      r"\b(?:\d{1,2}(?:[:.]\d{2})?(?:\s*(?:buçuk|bucuk|çeyrek|ceyrek))?(?:['’]?(?:de|da|te|ta|ye|ya|e|a)))\b",
      r'\b(?:\d+\s*(?:dakika|dk|saat|st|gün)\s*(?:sonra\w*|sonras\w*|için\w*|icin\w*)?)\b',
      r'\b(?:(?:bir|iki|üç|dört|beş|on)\s*(?:dakika|dk|saat|st|gün)\s*(?:sonra\w*|sonras\w*|için\w*|icin\w*)?)\b',
      r'\b(?:yarım|yarim|çeyrek|ceyrek|bir)\s*saat\s*(?:sonra\w*|sonras\w*)?\b',
      r'\b(?:yarın\w*|yarin\w*|bugün\w*|bugun\w*|öbür gün\w*|obur gun\w*)\b',
      r'\b(?:sabah\w*|öğlen\w*|oglen\w*|akşam\w*|aksam\w*|gece\w*|öğleden sonra\w*|ogleden sonra\w*)\b',
      r'\b(?:pazartesi\w*|salı\w*|sali\w*|çarşamba\w*|carsamba\w*|perşembe\w*|persembe\w*|cuma\w*|cumartesi\w*|pazar\w*)\b',
      r'\b(?:alarm(?:\s*kur\w*|\s*kurur musun|\s*kurabilir misin|\s*ı kur)?)\b',
      r'\b(?:adam(?:\s*kur\w*|\s*kurur musun|\s*kurabilir misin|\s*ı kur)?)\b',
      r'\b(?:alan(?:\s*kur\w*|\s*kurur musun|\s*kurabilir misin|\s*ı kur)?)\b',
      r'\b(?:kurcam|kuracağım|kuracagim|kurmak istiyorum|istiyorum|kaldır|kaldir|uyandır|uyandir)\b',
      r'\b(?:hatırlatıcı ekle|hatirlatici ekle)\b',
      r'\b(?:için|icin)\b',
      r'\b(?:kur|ayarla)\b',
    ];

    for (final pattern in removals) {
      res = res.replaceAll(RegExp(pattern, caseSensitive: false), ' ');
    }

    res = res.replaceAll(RegExp(r'\s+'), ' ').trim();
    res = res.replaceAll(RegExp(r'\b(?:etmeyi|yapmayı|aramayı)\b'), 'et');
    if (res.isEmpty) return 'Sesli Alarm';
    return res[0].toUpperCase() + res.substring(1);
  }

  static String _cleanNoteTitle(String raw) {
    String res = raw;
    final removals = [
      r'\b(?:not\s*(?:al|et|yaz|kaydet|al\w*|ed\w*))\b',
      r'\b(?:bunu\s*not\s*(?:al|et))\b',
      r'\b(?:notum\s*şu:?)\b',
      r'\b(?:lütfen|lutfen)\b',
    ];
    for (final pattern in removals) {
      res = res.replaceAll(RegExp(pattern, caseSensitive: false), ' ');
    }
    res = res.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (res.isEmpty) return 'Hızlı Not';
    return res[0].toUpperCase() + res.substring(1);
  }

  static String _normalize(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .trim();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
