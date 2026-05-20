import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text for dictation and voice notes.
class VoiceService {
  VoiceService() : _speech = SpeechToText();

  final SpeechToText _speech;
  bool _available = false;

  final List<void Function(String status)> _listeners = [];

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  void addStatusListener(void Function(String status) listener) {
    _listeners.add(listener);
  }

  void removeStatusListener(void Function(String status) listener) {
    _listeners.remove(listener);
  }

  Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (_) {},
      onStatus: (status) {
        for (final listener in _listeners) {
          listener(status);
        }
      },
    );
    return _available;
  }

  Future<void> startListening(void Function(String text) onUpdate) async {
    if (!_available) return;
    await _speech.listen(
      onResult: (res) => onUpdate(res.recognizedWords),
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
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
