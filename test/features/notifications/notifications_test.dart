import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/features/notifications/models.dart';

void main() {
  group('PushNotificationType', () {
    test('parses TASK_ASSIGNED correctly', () {
      expect(
        PushNotificationType.fromRaw('TASK_ASSIGNED'),
        PushNotificationType.taskAssigned,
      );
    });

    test('parses TASK_STATUS_CHANGED correctly', () {
      expect(
        PushNotificationType.fromRaw('TASK_STATUS_CHANGED'),
        PushNotificationType.taskStatusChanged,
      );
    });

    test('falls back to unknown for unrecognized strings or null', () {
      expect(PushNotificationType.fromRaw('SOMETHING_NEW'), PushNotificationType.unknown);
      expect(PushNotificationType.fromRaw(null), PushNotificationType.unknown);
    });
  });

  group('PushDataPayload', () {
    test('parses TASK_ASSIGNED data payload correctly', () {
      final map = {
        'type': 'TASK_ASSIGNED',
        'caseNumber': 'INC-2026-0042',
      };

      final payload = PushDataPayload.fromMap(map);
      expect(payload.type, PushNotificationType.taskAssigned);
      expect(payload.caseNumber, 'INC-2026-0042');
      expect(payload.status, isNull);
    });

    test('parses TASK_STATUS_CHANGED data payload correctly', () {
      final map = {
        'type': 'TASK_STATUS_CHANGED',
        'caseNumber': 'INC-2026-0042',
        'status': 'EN_ROUTE',
      };

      final payload = PushDataPayload.fromMap(map);
      expect(payload.type, PushNotificationType.taskStatusChanged);
      expect(payload.caseNumber, 'INC-2026-0042');
      expect(payload.status, 'EN_ROUTE');
    });
  });

  group('PushTokenRegistration', () {
    test('serializes to fcmToken json correctly', () {
      const reg = PushTokenRegistration(fcmToken: 'test-fcm-token-123');
      expect(reg.toJson(), {'fcmToken': 'test-fcm-token-123'});
    });
  });
}
