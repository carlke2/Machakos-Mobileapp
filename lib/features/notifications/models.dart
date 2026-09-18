/// `data.type` values the backend sends. Unrecognised values fall back to
/// [unknown] rather than throwing, so a newer backend cannot crash an older
/// handset that has not been updated yet.
enum PushNotificationType {
  taskAssigned,
  taskStatusChanged,
  taskRouteChanged,
  test,
  unknown;

  static PushNotificationType fromRaw(String? raw) {
    switch (raw) {
      case 'TASK_ASSIGNED':
        return PushNotificationType.taskAssigned;
      case 'TASK_STATUS_CHANGED':
        return PushNotificationType.taskStatusChanged;
      case 'TASK_ROUTE_CHANGED':
        return PushNotificationType.taskRouteChanged;
      case 'PUSH_TEST':
        return PushNotificationType.test;
      default:
        return PushNotificationType.unknown;
    }
  }

  String get raw {
    switch (this) {
      case PushNotificationType.taskAssigned:
        return 'TASK_ASSIGNED';
      case PushNotificationType.taskStatusChanged:
        return 'TASK_STATUS_CHANGED';
      case PushNotificationType.taskRouteChanged:
        return 'TASK_ROUTE_CHANGED';
      case PushNotificationType.test:
        return 'PUSH_TEST';
      case PushNotificationType.unknown:
        return '';
    }
  }
}

/// Parsed `data` map of an FCM message.
class PushDataPayload {
  final PushNotificationType type;
  final String? caseNumber;
  final String? taskId;

  /// Present on [PushNotificationType.taskStatusChanged] only.
  final String? status;

  const PushDataPayload({
    required this.type,
    required this.caseNumber,
    required this.taskId,
    required this.status,
  });

  factory PushDataPayload.fromMap(Map<String, dynamic> data) {
    return PushDataPayload(
      type: PushNotificationType.fromRaw(data['type'] as String?),
      caseNumber: data['caseNumber'] as String?,
      taskId: data['taskId'] as String?,
      status: data['status'] as String?,
    );
  }

  /// True when there is nothing useful for routing (and it is not a typed event).
  bool get isEmpty =>
      type == PushNotificationType.unknown &&
      caseNumber == null &&
      taskId == null;

  /// Whether tapping should open the Assignment tab and refresh the active task.
  bool get shouldFocusAssignment =>
      type == PushNotificationType.taskAssigned ||
      type == PushNotificationType.taskStatusChanged ||
      type == PushNotificationType.taskRouteChanged ||
      taskId != null ||
      caseNumber != null;

  /// Pack routing fields into the single string flutter_local_notifications
  /// can carry through a foreground tap.
  String encodeTapPayload() =>
      [type.raw, taskId ?? '', caseNumber ?? '', status ?? ''].join('|');

  static PushDataPayload decodeTapPayload(String raw) {
    final parts = raw.split('|');
    return PushDataPayload(
      type: PushNotificationType.fromRaw(
        parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null,
      ),
      taskId: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      caseNumber: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      status: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
    );
  }
}

class PushNotificationContent {
  final String? title;
  final String? body;

  const PushNotificationContent({required this.title, required this.body});
}

/// Body for `POST /notifications/token`.
class PushTokenRegistration {
  final String fcmToken;

  const PushTokenRegistration({required this.fcmToken})
      : assert(fcmToken != '', 'fcmToken must not be empty');

  Map<String, dynamic> toJson() => {'fcmToken': fcmToken};
}
