import 'package:flutter/material.dart';
import 'package:haka_comic/utils/common.dart';
import 'package:haka_comic/utils/extension.dart';
import 'package:haka_comic/utils/ui.dart';
import 'package:haka_comic/views/categories/categories.dart';
import 'package:haka_comic/views/home/navigation.dart';
import 'package:haka_comic/views/mine/mine.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _categoriesScroll = ScrollController();
  final _mineScroll = ScrollController();
  int _selectedIndex = 0;

  Widget _buildAppNavigationBar() => AppNavigationBar(
    selectedIndex: _selectedIndex,
    scrollController: _selectedIndex == 0 ? _categoriesScroll : _mineScroll,
    onDestinationSelected: (int index) {
      if (_selectedIndex == index) return;
      setState(() {
        _selectedIndex = index;
      });
    },
  );

  @override
  void dispose() {
    _categoriesScroll.dispose();
    _mineScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = UiMode.m1(context);
    final floatingNavigation = compact && isOhos;
    final scheme = context.colorScheme;
    final pages = IndexedStack(
      sizing: StackFit.expand,
      index: _selectedIndex,
      children: [
        Categories(scrollController: _categoriesScroll),
        Mine(
          floatingNavigation: floatingNavigation,
          scrollController: _mineScroll,
        ),
      ],
    );
    return Scaffold(
      extendBody: floatingNavigation,
      extendBodyBehindAppBar: _selectedIndex == 1,
      appBar: compact ? AppHeaderBar(selectedIndex: _selectedIndex) : null,
      body: Row(
        children: [
          if (!compact) _buildAppNavigationBar(),
          Expanded(
            child: floatingNavigation
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomLeft,
                        stops: const [0, 0.58, 1],
                        colors: [
                          scheme.surface,
                          scheme.surface,
                          Color.lerp(
                            scheme.surface,
                            scheme.primaryContainer,
                            0.55,
                          )!,
                        ],
                      ),
                    ),
                    child: pages,
                  )
                : pages,
          ),
        ],
      ),
      bottomNavigationBar: compact ? _buildAppNavigationBar() : null,
    );
  }
}
