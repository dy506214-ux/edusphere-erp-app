import 'dart:developer' as dev;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:edusphere/config/api_config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  socket_io.Socket? _socket;
  String? _userId;
  String? _role;
  bool _isConnected = false;
  
  // Custom callbacks list
  final Map<String, List<Function(dynamic)>> _listeners = {};

  bool get isConnected => _isConnected;
  String? get socketId => _socket?.id;

  /// Gets the default server URL based on the running platform/config
  String get defaultServerUrl => ApiConfig.serverBaseUrl;

  /// Initialize and connect to the Socket.io server
  void connect({required String userId, required String role, String? customUrl}) {
    _userId = userId;
    _role = role;
    
    final url = customUrl ?? defaultServerUrl;
    
    if (_socket != null) {
      dev.log('🔌 Socket already initialized, reconnecting with new configs...', name: 'SocketService');
      disconnect();
    }

    dev.log('🔌 Initializing socket connection to: $url', name: 'SocketService');

    try {
      _socket = socket_io.io(url, socket_io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableAutoConnect()
        .enableForceNew()
        .setReconnectionDelay(2000)
        .setReconnectionAttempts(30) // 30 attempts * 2s delay = 60s window (handles Render cold start)
        .build()
      );

      _setupBasicListeners();
      _socket!.connect();
    } catch (e, stack) {
      dev.log('❌ Error initializing socket client: $e', error: e, stackTrace: stack, name: 'SocketService');
    }
  }

  /// Set up basic connection lifecycle listeners
  void _setupBasicListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _isConnected = true;
      dev.log('✅ Connected to WebSocket Server! Socket ID: ${_socket!.id}', name: 'SocketService');
      
      // Join targeted user room
      if (_userId != null) {
        _socket!.emit('join_user', _userId);
        dev.log('👥 Joined room user_$_userId', name: 'SocketService');
      }

      // Join role-based dashboard room
      if (_role != null) {
        final uppercaseRole = _role!.toUpperCase();
        _socket!.emit('join_dashboard', uppercaseRole);
        dev.log('👥 Joined room dashboard_$uppercaseRole', name: 'SocketService');
      }

      // Trigger any registered custom connect listeners
      _triggerLocalListeners('connect', null);
    });

    _socket!.onDisconnect((data) {
      _isConnected = false;
      dev.log('🔌 Disconnected from WebSocket Server: $data', name: 'SocketService');
      _triggerLocalListeners('disconnect', data);
    });

    _socket!.onConnectError((data) {
      dev.log('❌ Connection error: $data', name: 'SocketService');
      _triggerLocalListeners('connect_error', data);
    });

    _socket!.onError((data) {
      dev.log('⚠️ General Socket Error: $data', name: 'SocketService');
    });

    // Dynamic listener dispatcher for general events
    _socket!.onAny((event, data) {
      if (kDebugMode) {
        dev.log('⚡ Received WebSocket Event: [$event] -> $data', name: 'SocketService');
      }
      _triggerLocalListeners(event, data);
    });
  }

  /// Register a callback to listen to a specific socket event
  void on(String event, Function(dynamic) callback) {
    if (!_listeners.containsKey(event)) {
      _listeners[event] = [];
    }
    _listeners[event]!.add(callback);
    dev.log('➕ Registered callback for event [$event]', name: 'SocketService');
  }

  /// Unregister a callback from a specific socket event
  void off(String event, [Function(dynamic)? callback]) {
    if (_listeners.containsKey(event)) {
      if (callback == null) {
        _listeners.remove(event);
        dev.log('➖ Unregistered all callbacks for event [$event]', name: 'SocketService');
      } else {
        _listeners[event]!.remove(callback);
        dev.log('➖ Unregistered specific callback for event [$event]', name: 'SocketService');
        if (_listeners[event]!.isEmpty) {
          _listeners.remove(event);
        }
      }
    }
  }

  /// Safely triggers locally registered callbacks for a specific event
  void _triggerLocalListeners(String event, dynamic data) {
    final callbacks = _listeners[event];
    if (callbacks != null && callbacks.isNotEmpty) {
      final callbacksToRun = List<Function(dynamic)>.from(callbacks);
      for (final callback in callbacksToRun) {
        try {
          callback(data);
        } catch (e, stack) {
          dev.log('❌ Error running callback for event [$event]: $e', error: e, stackTrace: stack, name: 'SocketService');
        }
      }
    }
  }

  /// Emit an event to the server
  void emit(String event, dynamic data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
      if (kDebugMode) {
        dev.log('📤 Emitted Event: [$event] -> $data', name: 'SocketService');
      }
    } else {
      dev.log('⚠️ Cannot emit event [$event]: socket is not connected.', name: 'SocketService');
    }
  }

  /// Disconnect the socket client
  void disconnect() {
    if (_socket != null) {
      dev.log('🔌 Disconnecting socket client...', name: 'SocketService');
      _socket!.disconnect();
      _socket!.close();
      _socket = null;
      _isConnected = false;
    }
  }
}
