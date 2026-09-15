// Mirrors the audited FCM payload and /notifications/token contract
// exactly. There is NO backend-persisted in-app notification list for
// mobile (the web NotificationDrawer is a client-only Zustand store with
// no DB table or API behind it) — so there is deliberately no
// "NotificationInbox" model here. Mobile is push-only.

/// data.type values the backend actually sends. Kept as raw strings with
/// a safe fallback (`unknown`) rather than throwing, since a future
/// backend change adding a new type shouldn't crash a running app.
enum PushNotificationType {
  taskAssigned,
  taskStatusChanged,
  unknown;

  static PushNotificationType fromRaw(String? raw) {
    switch (raw) {
      case 'TASK_ASSIGNED':
        return PushNotificationType.taskAssigned;
      case 'TASK_STATUS_CHANGED':
        return PushNotificationType.taskStatusChanged;
      default:
        return PushNotificationType.unknown;
    }
  }
}

/// Parsed form of an FCM RemoteMessage's `data` map. Both known variants
/// carry `caseNumber`; TASK_STATUS_CHANGED additionally carries `status`.
///
///   TASK_ASSIGNED:       { type, caseNumber }
///   TASK_STATUS_CHANGED: { type, caseNumber, status }
class PushDataPayload {
  final PushNotificationType type;
  final String? caseNumber;

  /// Only present for TASK_STATUS_CHANGED — one of EN_ROUTE, ON_SCENE,
  /// TRANSPORTING, AT_HOSPITAL, COMPLETED, or CANCELLED (cancellation
  /// goes through notifyCrewOfStatusPush too, per the audit).
  final String? status;

  const PushDataPayload({
    required this.type,
    required this.caseNumber,
    required this.status,
  });

  factory PushDataPayload.fromMap(Map<String, dynamic> data) {
    return PushDataPayload(
      type: PushNotificationType.fromRaw(data['type'] as String?),
      caseNumber: data['caseNumber'] as String?,
      status: data['status'] as String?,
    );
  }
}

/// The `notification` block of the payload (title/body) — present
/// alongside `data` on every send per the audited sendEachForMulticast
/// call, so this is what the OS auto-renders in background/terminated
/// state and what you build the foreground banner from.
class PushNotificationContent {
  final String? title;
  final String? body;

  const PushNotificationContent({required this.title, required this.body});
}

/// Body shape for POST /notifications/token. The backend Zod schema
/// requires at least one of fcmToken/token to be present — this class
/// enforces that at construction so a bad call fails fast client-side
/// instead of at the server.
class PushTokenRegistration {
  final String fcmToken;

  const PushTokenRegistration({required this.fcmToken})
      : assert(fcmToken != '', 'fcmToken must not be empty');

  /// Sent as `fcmToken` — the audited backend accepts either `fcmToken`
  /// or `token`, but `fcmToken` is the field actually persisted to
  /// User.fcmToken, so prefer it over the legacy `token` alias.
  Map<String, dynamic> toJson() => {'fcmToken': fcmToken};
}
