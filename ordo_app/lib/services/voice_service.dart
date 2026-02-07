import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Native Android Speech Recognition implementation using MethodChannel
class VoiceService {
  static const MethodChannel _channel = MethodChannel('com.ordo.app/speech');
  static const EventChannel _eventChannel = EventChannel('com.ordo.app/speech_events');
  
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        print('❌ Microphone permission denied');
        return false;
      }

      // Check if speech recognition is available
      final available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
      if (!available) {
        print('❌ Speech recognition not available on this device');
        return false;
      }

      _isInitialized = true;
      print('✅ Voice service initialized (native Android)');
      return _isInitialized;
    } catch (e) {
      print('❌ Failed to initialize voice service: $e');
      return false;
    }
  }

  /// Start listening for voice input
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw Exception('Failed to initialize voice service');
      }
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;
      print('🎤 Started listening...');

      // Listen to speech events
      _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final type = event['type'] as String?;
            final text = event['text'] as String?;

            if (type == 'partial' && text != null && onPartialResult != null) {
              print('🎤 Partial: $text');
              onPartialResult(text);
            } else if (type == 'final' && text != null) {
              print('🎤 Final: $text');
              _isListening = false;
              onResult(text);
            } else if (type == 'error') {
              print('❌ Speech error: ${event['error']}');
              _isListening = false;
            }
          }
        },
        onError: (error) {
          print('❌ Stream error: $error');
          _isListening = false;
        },
        cancelOnError: false,
      );

      // Start recognition
      await _channel.invokeMethod('startListening');
    } catch (e) {
      print('❌ Failed to start listening: $e');
      _isListening = false;
      rethrow;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _channel.invokeMethod('stopListening');
        _isListening = false;
        print('🎤 Stopped listening');
      } catch (e) {
        print('❌ Failed to stop listening: $e');
      }
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    if (_isListening) {
      try {
        await _channel.invokeMethod('cancelListening');
        _isListening = false;
        print('🎤 Cancelled listening');
      } catch (e) {
        print('❌ Failed to cancel listening: $e');
      }
    }
  }

  /// Check if speech recognition is available
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (e) {
      print('❌ Failed to check availability: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    cancelListening();
    _isInitialized = false;
    _isListening = false;
  }
}
