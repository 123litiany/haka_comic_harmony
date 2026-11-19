import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haka_comic/utils/common.dart';
import 'package:haka_comic/views/home/navigation.dart';

void main() {
  setUp(() {
    final wasOhos = isOhos;
    isOhos = true;
    addTearDown(() => isOhos = wasOhos);
  });

  testWidgets(
    'floating navigation leaves the gesture inset and selects a tab',
    (tester) async {
      setWindow(tester, width: 420);
      int? selected;
      await tester.pumpWidget(
        navigationApp(onSelect: (index) => selected = index),
      );

      final bar = find.byType(NavigationBar);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.getRect(bar).left, greaterThan(0));
      expect(tester.getRect(bar).bottom, lessThan(800 - 24));
      expect(find.text('分类'), findsOneWidget);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey(1))).bottom,
        greaterThan(tester.getRect(bar).bottom),
      );
    },
  );

  testWidgets('the tab indicator follows a horizontal swipe before release', (
    tester,
  ) async {
    setWindow(tester, width: 420);
    await tester.pumpWidget(navigationApp());

    final bar = find.byType(NavigationBar);
    final indicator = find.descendant(
      of: find.byType(BackdropFilter),
      matching: find.byType(AnimatedAlign),
    );
    final rect = tester.getRect(bar);
    final swipe = await tester.startGesture(
      rect.centerLeft + const Offset(110, 0),
    );
    await swipe.moveBy(const Offset(145, 0));
    await tester.pump();
    expect(
      tester.widget<AnimatedAlign>(indicator).alignment,
      isNot(Alignment.centerLeft),
    );
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 0);

    await swipe.up();
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 1);

    await tester.dragFrom(
      rect.centerRight - const Offset(90, 0),
      const Offset(-230, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 0);
  });

  testWidgets('a vertical swipe on the glass scrolls the active page', (
    tester,
  ) async {
    setWindow(tester, width: 420);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(navigationApp(scrollController: scroll));

    final bar = find.byType(NavigationBar);
    await tester.dragFrom(tester.getCenter(bar), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(80));
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 0);
  });

  testWidgets('high contrast uses a solid tab bar', (tester) async {
    setWindow(tester, width: 420);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(navigationApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('wide windows use the side menu', (tester) async {
    setWindow(tester, width: 840);
    await tester.pumpWidget(navigationApp());

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('HaKa Comic'), findsOneWidget);
  });
}

void setWindow(WidgetTester tester, {required double width}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  tester.view.padding = const FakeViewPadding(bottom: 24);
  addTearDown(tester.view.reset);
}

Widget navigationApp({
  ValueChanged<int>? onSelect,
  ScrollController? scrollController,
}) {
  var selected = 0;
  return MaterialApp(
    home: StatefulBuilder(
      builder: (context, setState) {
        final compact = MediaQuery.sizeOf(context).width <= 600;
        final navigation = AppNavigationBar(
          selectedIndex: selected,
          scrollController: scrollController,
          onDestinationSelected: (index) {
            setState(() => selected = index);
            onSelect?.call(index);
          },
        );
        return Scaffold(
          extendBody: compact,
          extendBodyBehindAppBar: selected == 1,
          appBar: compact ? AppBar(backgroundColor: Colors.transparent) : null,
          body: compact
              ? scrollController == null
                    ? SizedBox.expand(key: ValueKey(selected))
                    : ListView.builder(
                        controller: scrollController,
                        itemExtent: 64,
                        itemCount: 32,
                        itemBuilder: (_, index) => Text('Item $index'),
                      )
              : navigation,
          bottomNavigationBar: compact ? navigation : null,
        );
      },
    ),
  );
}
