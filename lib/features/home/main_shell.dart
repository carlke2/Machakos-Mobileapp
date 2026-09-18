import 'package:flutter/material.dart';
import 'package:mobileapp/core/app_events.dart';
import 'package:mobileapp/core/network/socket_service.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'package:mobileapp/features/tasks/task_screen.dart';
import 'package:mobileapp/features/crew/crew_screen.dart';
import 'package:mobileapp/features/history/history_screen.dart';
import 'package:mobileapp/features/inventory/inventory_screen.dart';

/// Duration for bottom-nav show/hide slide (Gmail/Twitter-like).
const Duration kBottomNavAnimDuration = Duration(milliseconds: 250);

/// Minimum accumulated scroll delta (logical px) before toggling nav visibility.
/// Filters sub-pixel / frame-to-frame direction noise that caused v1 flicker.
const double kBottomNavScrollThreshold = 16.0;

/// Stable show/hide state machine for the bottom nav.
///
/// Driven by [ScrollUpdateNotification.scrollDelta] with hysteresis — not by
/// per-frame [ScrollDirection] flips — so a committed hide stays hidden until
/// the user reverses past [threshold] (and vice versa).
@visibleForTesting
class BottomNavVisibilityController {
  BottomNavVisibilityController({
    this.threshold = kBottomNavScrollThreshold,
    bool initiallyVisible = true,
  }) : _visible = initiallyVisible;

  final double threshold;

  bool _visible;
  double _accumulatedDelta = 0;

  bool get isVisible => _visible;

  /// Accumulated delta toward the opposite state (for tests).
  @visibleForTesting
  double get accumulatedDelta => _accumulatedDelta;

  /// Forces the bar visible and clears hysteresis (tab switch, focus, etc.).
  void show() {
    _visible = true;
    _accumulatedDelta = 0;
  }

  /// Applies one scroll notification. Returns `true` if [isVisible] changed.
  bool handleNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (!notification.metrics.hasPixels) return false;

    final metrics = notification.metrics;

    // Unscrollable or pinned at top → always show (committed).
    if (metrics.maxScrollExtent <= 0 ||
        metrics.pixels <= metrics.minScrollExtent) {
      if (_visible && _accumulatedDelta == 0) return false;
      final changed = !_visible;
      show();
      return changed;
    }

    // Only ScrollUpdate deltas drive toggles. UserScrollNotification /
    // idle / end events are intentionally ignored to avoid direction flicker.
    if (notification is! ScrollUpdateNotification) return false;

    final delta = notification.scrollDelta;
    if (delta == null || delta == 0) return false;

    if (_visible) {
      // Visible: only downward motion (positive delta) accumulates toward hide.
      if (delta > 0) {
        _accumulatedDelta += delta;
        if (_accumulatedDelta >= threshold) {
          _accumulatedDelta = 0;
          _visible = false;
          return true;
        }
      } else {
        // Upward while already visible — discard any hide progress.
        _accumulatedDelta = 0;
      }
    } else {
      // Hidden: only upward motion (negative delta) accumulates toward show.
      if (delta < 0) {
        _accumulatedDelta += delta;
        if (_accumulatedDelta <= -threshold) {
          _accumulatedDelta = 0;
          _visible = true;
          return true;
        }
      } else {
        // Continued downward while hidden — discard any show progress.
        _accumulatedDelta = 0;
      }
    }

    return false;
  }
}

/// Main navigation shell containing Assignment, Crew, History, and Inventory tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};
  final BottomNavVisibilityController _navVisibility =
      BottomNavVisibilityController();

  @override
  void initState() {
    super.initState();
    SocketService.instance.connect();
    AppEvents.assignmentFocusRequest.addListener(_focusAssignmentTab);
  }

  @override
  void dispose() {
    AppEvents.assignmentFocusRequest.removeListener(_focusAssignmentTab);
    super.dispose();
  }

  void _focusAssignmentTab() {
    if (!mounted || _currentIndex == 0) return;
    setState(() {
      _currentIndex = 0;
      _navVisibility.show();
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Intentionally no depth filter: Inventory lists live under TabBarView
    // (extra Viewport → depth >= 1). Horizontal scrolls are ignored inside
    // the controller via metrics.axis.
    if (_navVisibility.handleNotification(notification)) {
      setState(() {});
    }
    return false;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
      // Switching tabs restores the bar so destinations stay reachable.
      _navVisibility.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNavVisible = _navVisibility.isVisible;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _loadedTabs.contains(0) ? const TaskScreen() : const SizedBox.shrink(),
            _loadedTabs.contains(1) ? const CrewScreen() : const SizedBox.shrink(),
            _loadedTabs.contains(2) ? const HistoryScreen() : const SizedBox.shrink(),
            _loadedTabs.contains(3) ? const InventoryScreen() : const SizedBox.shrink(),
          ],
        ),
      ),
      // ClipRect + AnimatedAlign (bottom-aligned) collapses layout height while
      // the bar recedes downward off-screen — content gains space and the hidden
      // bar cannot receive taps. Binary heightFactor only (0 or 1); hysteresis
      // above prevents mid-scroll animation reversals from noise.
      bottomNavigationBar: ClipRect(
        child: AnimatedAlign(
          duration: kBottomNavAnimDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          heightFactor: isNavVisible ? 1.0 : 0.0,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.12),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 64,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment, color: AppColors.primary),
                label: 'Assignment',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group, color: AppColors.primary),
                label: 'Crew',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history, color: AppColors.primary),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
                label: 'Inventory',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
