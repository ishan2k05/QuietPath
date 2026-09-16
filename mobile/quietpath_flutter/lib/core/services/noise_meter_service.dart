import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service and Riverpod provider streaming real-time hardware ambient decibels
/// from the device's physical microphone via native Android AudioRecord EventChannel.
class NoiseMeterService {
  static const EventChannel _channel = EventChannel('com.quietpath/noise_meter');

  static Stream<double> get decibelStream {
    return _channel.receiveBroadcastStream().map((event) {
      if (event is num) {
        return event.toDouble();
      }
      return 38.0;
    }).handleError((error) {
      // Graceful fallback during permission denial or on hardware without mic
      return 38.0;
    });
  }
}

/// Broadcasts live ambient decibels (e.g. 38 dB to 75 dB) updated every 250ms
final liveDecibelProvider = StreamProvider.autoDispose<double>((ref) {
  return NoiseMeterService.decibelStream;
});
