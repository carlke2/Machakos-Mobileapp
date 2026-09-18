import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/features/home/main_shell.dart';

void main() {
  group('BottomNavVisibilityController', () {
    ScrollUpdateNotification update({
      required double delta,
      double pixels = 100,
      double min = 0,
      double max = 500,
      Axis axis = Axis.vertical,
    }) {
      return ScrollUpdateNotification(
        metrics: FixedScrollMetrics(
          pixels: pixels,
          minScrollExtent: min,
          maxScrollExtent: max,
          viewportDimension: 400,
          axisDirection:
              axis == Axis.vertical ? AxisDirection.down : AxisDirection.right,
          devicePixelRatio: 1,
        ),
        context: _FakeBuildContext(),
        scrollDelta: delta,
      );
    }

    UserScrollNotification userScroll({
      required ScrollDirection direction,
      double pixels = 100,
    }) {
      return UserScrollNotification(
        metrics: FixedScrollMetrics(
          pixels: pixels,
          minScrollExtent: 0,
          maxScrollExtent: 500,
          viewportDimension: 400,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        ),
        context: _FakeBuildContext(),
        direction: direction,
      );
    }

    test('ignores horizontal scroll updates (Inventory sub-tab swipes)', () {
      final c = BottomNavVisibilityController();
      expect(
        c.handleNotification(update(delta: 40, axis: Axis.horizontal)),
        isFalse,
      );
      expect(c.isVisible, isTrue);
    });

    test('ignores UserScrollNotification direction flips (v1 flicker source)', () {
      final c = BottomNavVisibilityController();
      // Would have hidden under v1 — must not change visibility now.
      expect(
        c.handleNotification(
          userScroll(direction: ScrollDirection.forward),
        ),
        isFalse,
      );
      expect(c.isVisible, isTrue);
      expect(
        c.handleNotification(
          userScroll(direction: ScrollDirection.reverse),
        ),
        isFalse,
      );
      expect(c.isVisible, isTrue);
    });

    test('does not hide until downward delta exceeds threshold', () {
      final c = BottomNavVisibilityController(threshold: 16);
      expect(c.handleNotification(update(delta: 8)), isFalse);
      expect(c.isVisible, isTrue);
      expect(c.handleNotification(update(delta: 8)), isTrue);
      expect(c.isVisible, isFalse);
    });

    test('stays hidden while continuing to scroll down (no mid-scroll flicker)', () {
      final c = BottomNavVisibilityController(threshold: 16);
      c.handleNotification(update(delta: 20));
      expect(c.isVisible, isFalse);

      // Noisy downward scroll with sub-threshold reverse frames — must stay hidden.
      for (var i = 0; i < 30; i++) {
        c.handleNotification(update(delta: 12));
        c.handleNotification(update(delta: -3));
        expect(c.isVisible, isFalse, reason: 'frame $i flipped visibility');
      }
    });

    test('sub-threshold upward jitter alone does not reveal the bar', () {
      final c = BottomNavVisibilityController(threshold: 16);
      c.handleNotification(update(delta: 20));
      expect(c.isVisible, isFalse);

      // -3 * 5 = -15, still under threshold.
      for (var i = 0; i < 5; i++) {
        expect(c.handleNotification(update(delta: -3)), isFalse);
        expect(c.isVisible, isFalse);
      }
      // One more -3 crosses 16 → show.
      expect(c.handleNotification(update(delta: -3)), isTrue);
      expect(c.isVisible, isTrue);
    });

    test('shows only after upward delta exceeds threshold', () {
      final c = BottomNavVisibilityController(threshold: 16);
      c.handleNotification(update(delta: 20));
      expect(c.isVisible, isFalse);

      expect(c.handleNotification(update(delta: -8)), isFalse);
      expect(c.isVisible, isFalse);
      expect(c.handleNotification(update(delta: -8)), isTrue);
      expect(c.isVisible, isTrue);
    });

    test('always shows at the top of the list', () {
      final c = BottomNavVisibilityController(threshold: 16);
      c.handleNotification(update(delta: 20));
      expect(c.isVisible, isFalse);

      expect(
        c.handleNotification(update(delta: -1, pixels: 0)),
        isTrue,
      );
      expect(c.isVisible, isTrue);
    });

    test('always shows when content is not scrollable', () {
      final c = BottomNavVisibilityController();
      c.handleNotification(update(delta: 20, pixels: 0, max: 0));
      expect(c.isVisible, isTrue);
    });

    test('show() resets hysteresis and forces visible', () {
      final c = BottomNavVisibilityController(threshold: 16);
      c.handleNotification(update(delta: 10));
      expect(c.accumulatedDelta, 10);
      c.show();
      expect(c.isVisible, isTrue);
      expect(c.accumulatedDelta, 0);
    });
  });

  group('shared shell scroll bubbling', () {
    testWidgets(
      'vertical list under TabBarView (Inventory-like depth) hides nav once',
      (tester) async {
        final controller = BottomNavVisibilityController(threshold: 16);
        var visible = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  // Mimic MainShell: no depth filter.
                  if (controller.handleNotification(n)) {
                    visible = controller.isVisible;
                  }
                  return false;
                },
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(tabs: [Tab(text: 'Stock'), Tab(text: 'My Stock')]),
                      Expanded(
                        child: TabBarView(
                          children: [
                            ListView.builder(
                              itemCount: 40,
                              itemBuilder: (_, i) => sizedBox(i),
                            ),
                            ListView.builder(
                              itemCount: 40,
                              itemBuilder: (_, i) => sizedBox(i),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: visible
                  ? NavigationBar(
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.settings),
                          label: 'Settings',
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );

        // Scroll down past threshold on Stock tab.
        await tester.drag(find.byType(ListView).first, const Offset(0, -120));
        await tester.pumpAndSettle();
        expect(controller.isVisible, isFalse);

        // Continued downward drag must not flicker back to visible.
        await tester.drag(find.byType(ListView).first, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(controller.isVisible, isFalse);

        // Slight upward reverse → show.
        await tester.drag(find.byType(ListView).first, const Offset(0, 80));
        await tester.pumpAndSettle();
        expect(controller.isVisible, isTrue);
      },
    );

    testWidgets('horizontal TabBarView swipe does not toggle nav', (tester) async {
      final controller = BottomNavVisibilityController(threshold: 16);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                controller.handleNotification(n);
                return false;
              },
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(tabs: [Tab(text: 'Stock'), Tab(text: 'My Stock')]),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView.builder(
                            itemCount: 40,
                            itemBuilder: (_, i) => sizedBox(i),
                          ),
                          ListView.builder(
                            itemCount: 40,
                            itemBuilder: (_, i) => sizedBox(i),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Swipe to My Stock (horizontal).
      await tester.drag(find.byType(TabBarView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(controller.isVisible, isTrue);

      // Vertical scroll on My Stock still works.
      await tester.drag(find.byType(ListView).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(controller.isVisible, isFalse);
    });

    testWidgets(
      'plain SingleChildScrollView (Assignment/Crew-like) hides and stays hidden',
      (tester) async {
        final controller = BottomNavVisibilityController(threshold: 16);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  controller.handleNotification(n);
                  return false;
                },
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(40, sizedBox),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        expect(controller.isVisible, isFalse);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        expect(controller.isVisible, isFalse);

        // Jump back to top → must show.
        final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
        scrollable.position.jumpTo(0);
        // jumpTo may not dispatch ScrollUpdate with delta; dispatch a synthetic
        // update at top to mirror real overscroll/settle notifications.
        controller.handleNotification(
          ScrollUpdateNotification(
            metrics: FixedScrollMetrics(
              pixels: 0,
              minScrollExtent: 0,
              maxScrollExtent: 800,
              viewportDimension: 400,
              axisDirection: AxisDirection.down,
              devicePixelRatio: 1,
            ),
            context: tester.element(find.byType(SingleChildScrollView)),
            scrollDelta: -10,
          ),
        );
        expect(controller.isVisible, isTrue);
      },
    );
  });
}

Widget sizedBox(int i) => SizedBox(
      height: 48,
      child: Text('Item $i'),
    );

/// Minimal BuildContext stand-in for constructing notifications in unit tests.
/// ScrollUpdateNotification requires a non-null context in this Flutter version.
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
