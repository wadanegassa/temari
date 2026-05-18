import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text for dictation and voice notes.
class VoiceService {
  VoiceService() : _speech = SpeechToText();

  final SpeechToText _speech;
  bool _available = false;

  bool get isAvailable => _available;

  Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _available;
  }

  Future<void> startListening(void Function(String text) onUpdate) async {
    if (!_available) return;
    await _speech.listen(
      onResult: (res) => onUpdate(res.recognizedWords),
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      cancelOnError: true,
    );
  }

  Future<void> stop() async {
    await _speech.stop();
  }

  Future<void> cancel() async {
    await _speech.cancel();
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
