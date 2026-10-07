import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SidecarService {
  WebSocketChannel? _channel;
  Function(double)? onThreatScoreUpdate;
  Function(Map<String, dynamic>)? onRiskStateUpdate;
  Function(Map<String, dynamic>)? onIntercept;
  Function(String, String)? onTranscriptUpdate;
  Function(Map<String, dynamic>)? onCallReport;
  Function(String, bool)? onSpeech; // text, isEvelyn

  void connect(String wsUrl) {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      final event = data['event'] as String?;

      if (event == 'THREAT_SCORE_UPDATE') {
        onThreatScoreUpdate?.call(data['score']?.toDouble() ?? 0.0);

      } else if (event == 'RISK_STATE_UPDATE') {
        onRiskStateUpdate?.call(data);

      } else if (event == 'INTERCEPT_CALL') {
        onIntercept?.call(data);

      } else if (event == 'TRANSCRIPT_UPDATE') {
        onTranscriptUpdate?.call(data['speaker'], data['text']);

      } else if (event == 'CALL_REPORT') {
        onCallReport?.call(Map<String, dynamic>.from(data));

      } else if (event == 'SCAMMER_SPEECH') {
        // Speak scammer's text through browser TTS (low-pitched voice)
        onSpeech?.call(data['text'], false);

      } else if (event == 'EVELYN_SPEECH') {
        // Speak Evelyn's text through browser TTS (higher-pitched, female)
        onSpeech?.call(data['text'], true);
      }
    }, onError: (error) {
      print('WebSocket Error: $error');
    }, onDone: () {
      print('WebSocket closed');
    });
  }

  void sendHandshake(String callerId, String calleeId) {
    _channel?.sink.add(jsonEncode({
      'type': 'call_start',
      'caller': callerId,
      'callee': calleeId,
    }));
  }

  void sendAudioChunk(List<int> chunk) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'audio',
        'data': base64Encode(chunk),
      }));
    }
  }

  void sendUserSpeech(String text) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'event': 'USER_SPEECH',
        'text': text,
      }));
    }
  }

  void sendEvelynTtsEnd() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'event': 'EVELYN_TTS_END',
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
