import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';

/// Real-time Socket.IO client for dispatch task events.
class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  final List<void Function(dynamic)> _taskAssignedListeners = [];
  final List<void Function(dynamic)> _taskUpdatedListeners = [];
  final List<void Function(dynamic)> _taskStopListeners = [];

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    _socket?.dispose();

    final token = await SecureStorageService.instance.getToken();
    if (token == null || token.isEmpty) return;

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.on('task:assigned', (data) => _dispatch(_taskAssignedListeners, data));
    _socket!.on('task:updated', (data) => _dispatch(_taskUpdatedListeners, data));

    // The backend emits these when dispatch re-routes a crew mid-case. Both
    // map onto the same listener list; a stop being added or edited means the
    // crew's stop list has to be re-read either way.
    _socket!.on('task:stop-added', (data) => _dispatch(_taskStopListeners, data));
    _socket!.on('task:stop-updated', (data) => _dispatch(_taskStopListeners, data));

    _socket!.connect();
  }

  void _dispatch(List<void Function(dynamic)> listeners, dynamic data) {
    for (final cb in List.of(listeners)) {
      cb(data);
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _taskAssignedListeners.clear();
    _taskUpdatedListeners.clear();
    _taskStopListeners.clear();
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

  void onTaskStopChanged(void Function(dynamic) listener) {
    _taskStopListeners.add(listener);
  }

  void offTaskStopChanged(void Function(dynamic) listener) {
    _taskStopListeners.remove(listener);
  }
}
