import 'package:flutter/foundation.dart';

/// App-wide signals that cross feature boundaries, so features never have to
/// import one another just to nudge a refresh.
class AppEvents {
  AppEvents._();

  /// Bumped when the crew should be taken to their active assignment — a
  /// tapped dispatch notification, for example. Listeners re-read the task
  /// rather than rebuilding the shell, which would drop tab state.
  static final ValueNotifier<int> assignmentFocusRequest = ValueNotifier(0);

  static void focusAssignment() {
    assignmentFocusRequest.value++;
  }
}
