import 'package:speech_to_text/speech_to_text.dart';

class STTService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  Future<bool> init() async {
    _isAvailable = await _speech.initialize();
    return _isAvailable;
  }

  void startListening(Function(String) onResult) {
    if (_isAvailable) {
      _speech.listen(onDevice: true, onResult: (val) => onResult(val.recognizedWords));
    }
  }

  void stopListening() => _speech.stop();
}