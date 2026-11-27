import 'dart:async';

import 'package:flutter/services.dart';

/// A dedicated bidirectional channel between the app and its overlay engine.
class OverlayMessageBridge {
  static const _channel = BasicMessageChannel<Object?>(
    'dynavoice/overlay_bridge',
    JSONMessageCodec(),
  );
  static final _messages = StreamController<dynamic>.broadcast();

  static Stream<dynamic> get messages {
    _channel.setMessageHandler((message) async {
      _messages.add(message);
      return true;
    });
    return _messages.stream;
  }

  static void send(Map<String, Object?> message) {
    unawaited(
      _channel
          .send(message)
          .timeout(const Duration(seconds: 3))
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    );
  }
}
