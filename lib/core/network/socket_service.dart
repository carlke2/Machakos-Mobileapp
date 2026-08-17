import 'package:socket_io_client/socket_io_client.dart' as io;
import '../storage/secure_storage_service.dart';
import 'api_client.dart';

/// Real-time Socket.IO client for dispatch task events.
class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  final List<void Function(dynamic)> _taskAssignedListeners = [];
  final List<void Function(dynamic)> _taskUpdatedListeners = [];

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    _socket?.dispose();

    final token = await SecureStorageService.instance.getToken();
    if (token == null || token.isEmpty) return;

    final baseUrl = ApiClient.instance.baseUrl;

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.on('task:assigned', (data) {
      for (final cb in _taskAssignedListeners) {
        cb(data);
      }
    });

    _socket!.on('task:updated', (data) {
      for (final cb in _taskUpdatedListeners) {
        cb(data);
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _taskAssignedListeners.clear();
    _taskUpdatedListeners.clear();
  }

  void onTaskAssigned(void Function(dynamic) listener) {
    _taskAssignedListeners.add(listener);
  }

  void offTaskAssigned(void Function(dynamic) listener) {
    _taskAssignedListeners.remove(listener);
  }

  void onTaskUpdated(void Function(dynamic) listener) {
    _taskUpdatedListeners.add(listener);
  }

  void offTaskUpdated(void Function(dynamic) listener) {
    _taskUpdatedListeners.remove(listener);
  }
}
