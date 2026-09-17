/// `data.type` values the backend sends. Unrecognised values fall back to
/// [unknown] rather than throwing, so a newer backend cannot crash an older
/// handset that has not been updated yet.
enum PushNotificationType {
  taskAssigned,
  taskStatusChanged,
  taskRouteChanged,
  unknown;

  static PushNotificationType fromRaw(String? raw) {
    switch (raw) {
      case 'TASK_ASSIGNED':
        return PushNotificationType.taskAssigned;
      case 'TASK_STATUS_CHANGED':
        return PushNotificationType.taskStatusChanged;
      case 'TASK_ROUTE_CHANGED':
        return PushNotificationType.taskRouteChanged;
      default:
        return PushNotificationType.unknown;
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

  bool get isEmpty => caseNumber == null && taskId == null;
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
