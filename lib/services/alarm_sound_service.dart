import 'package:audioplayers/audioplayers.dart';

class AlarmSoundService {
  static final AlarmSoundService _instance = AlarmSoundService._internal();
  factory AlarmSoundService() => _instance;
  AlarmSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> playAlarmSound() async {
    if (_isPlaying) return;

    try {
      // Alarm ses akışını (USAGE_ALARM) kullanarak telefon sessizde bile olsa yüksek sesle çal
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
        ),
      );

      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('audio/alarm.wav'));
      _isPlaying = true;
    } catch (_) {
      _isPlaying = false;
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      await _player.stop();
    } catch (_) {}
    _isPlaying = false;
  }
}
