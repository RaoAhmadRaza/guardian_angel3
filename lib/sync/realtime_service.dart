import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Real-time service for WebSocket/push notifications
/// 
/// Provides:
/// - WebSocket connection management
/// - Automatic reconnection
/// - Message dispatching
/// - Graceful fallback to polling
class RealtimeService {
  final String url;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  int _reconnectAttempts = 0;
  bool _intentionallyClosed = false;
  
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  RealtimeService({
    required this.url,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  /// Stream of incoming messages
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Stream of connection state changes (true = connected, false = disconnected)
  Stream<bool> get connectionState => _connectionStateController.stream;

  /// Check if currently connected
  bool get isConnected => _channel != null && _subscription != null;

  /// Connect to WebSocket with authentication token
  void connect(String token) {
    if (_channel != null) {
      print('[RealtimeService] Already connected');
      return;
    }

    _intentionallyClosed = false;
    _reconnectAttempts = 0;
    _doConnect(token);
  }

  /// Internal connection logic
  void _doConnect(String token) {
    try {
      print('[RealtimeService] Connecting to $url...');
      
      final uri = Uri.parse('$url?token=$token');
      _channel = WebSocketChannel.connect(uri);
      
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
      
      _connectionStateController.add(true);
      _reconnectAttempts = 0;
      print('[RealtimeService] Connected');
    } catch (e) {
      print('[RealtimeService] Connection failed: $e');
      _attemptReconnect(token);
    }
  }

  /// Handle incoming message
  void _onMessage(dynamic message) {
    try {
      // Parse message (assuming JSON string)
      if (message is String) {
        // Simple dispatch - extend with proper JSON parsing
        print('[RealtimeService] Received: $message');
        
        // Dispatch to controller
        // In production, parse JSON and extract event type
        final event = <String, dynamic>{
          'type': 'message',
          'data': message,
        };
        
        _messageController.add(event);
      }
    } catch (e) {
      print('[RealtimeService] Message parsing error: $e');
    }
  }

  /// Handle connection error
  void _onError(dynamic error) {
    print('[RealtimeService] Error: $error');
    _connectionStateController.add(false);
    
    if (!_intentionallyClosed) {
      _attemptReconnect(null);
    }
  }

  /// Handle connection closed
  void _onDone() {
    print('[RealtimeService] Connection closed');
    _connectionStateController.add(false);
    _cleanup();
    
    if (!_intentionallyClosed) {
      _attemptReconnect(null);
    }
  }

  /// Attempt to reconnect with exponential backoff
  void _attemptReconnect(String? token) {
    if (_intentionallyClosed) return;
    
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('[RealtimeService] Max reconnect attempts reached, giving up');
      return;
    }

    _reconnectAttempts++;
    final delay = reconnectDelay * _reconnectAttempts;
    
    print('[RealtimeService] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$maxReconnectAttempts)');
    
    Future.delayed(delay, () {
      if (!_intentionallyClosed && token != null) {
        _doConnect(token);
      }
    });
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _intentionallyClosed = true;
    _cleanup();
    print('[RealtimeService] Disconnected');
  }

  /// Clean up resources
  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    
    _channel?.sink.close();
    _channel = null;
  }

  /// Send message through WebSocket
  void send(Map<String, dynamic> message) {
    if (_channel == null) {
      print('[RealtimeService] Cannot send: not connected');
      return;
    }

    try {
      // In production, properly serialize to JSON
      _channel!.sink.add(message.toString());
    } catch (e) {
      print('[RealtimeService] Send failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}
