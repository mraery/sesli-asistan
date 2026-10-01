import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  String? _targetLocale;
  String _lastError = '';

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;
  String get lastError => _lastError;

  Function(String status)? onStatusChanged;
  Function(String error)? onErrorOccurred;

  Future<bool> init() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) {
          _lastError = val.errorMsg;
          if (onErrorOccurred != null) {
            onErrorOccurred!(val.errorMsg);
          }
        },
        onStatus: (status) {
          if (onStatusChanged != null) {
            onStatusChanged!(status);
          }
        },
        debugLogging: true,
      );

      if (_isInitialized) {
        final locales = await _speech.locales();
        for (final loc in locales) {
          // Hem tr_TR hem tr-TR formatlarını destekle
          if (loc.localeId.toLowerCase().startsWith('tr')) {
            _targetLocale = loc.localeId;
            break;
          }
        }
      }
    } catch (e) {
      _lastError = e.toString();
      _isInitialized = false;
    }
    return _isInitialized;
  }

  Future<bool> startListening({
    required Function(String words, bool isFinal) onResult,
    Function(double soundLevel)? onSoundLevelChange,
  }) async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) return false;
    }

    // Halihazırda dinliyorsa durdur ve yeniden başla
    if (_speech.isListening) {
      await _speech.stop();
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevelChange,
        listenOptions: stt.SpeechListenOptions(
          localeId: _targetLocale, // Eğer null ise cihazın varsayılan dilini (Türkçe) kullanır
          listenMode: stt.ListenMode.dictation, // Cümleleri kesmeden dinlemek için dictation
          pauseFor: const Duration(seconds: 3), // Erken kesmeyi önler
          listenFor: const Duration(seconds: 30),
          partialResults: true,
          cancelOnError: false,
        ),
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
  }

  Future<void> cancelListening() async {
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (_) {}
  }
}
