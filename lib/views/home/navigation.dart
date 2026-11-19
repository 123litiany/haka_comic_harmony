import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:haka_comic/utils/common.dart';
import 'package:haka_comic/utils/extension.dart';
import 'package:haka_comic/utils/ui.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.scrollController,
  });

  static const double _kDesktopNavigationWidth = 200;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ScrollController? scrollController;

  Widget _buildMobileNavigationBar() {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: _destinations,
    );
  }

  Widget _buildDesktopNavigationMenu(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox(
      width: _kDesktopNavigationWidth,
      child: Material(
        color: scheme.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: SafeArea(
            right: false,
            left: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      'HaKa Comic',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _SideMenuItem(
                  selected: selectedIndex == 0,
                  icon: selectedIndex == 0
                      ? Icons.category
                      : Icons.category_outlined,
                  label: '分类',
                  onTap: () => onDestinationSelected(0),
                ),
                _SideMenuItem(
                  selected: selectedIndex == 1,
                  icon: selectedIndex == 1
                      ? Icons.person
                      : Icons.person_outline,
                  label: '我的',
                  onTap: () => onDestinationSelected(1),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    spacing: 4,
                    children: [
                      Divider(
                        height: 16,
                        indent: 16,
                        endIndent: 16,
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                      _SideMenuItem(
                        selected: false,
                        icon: Icons.search,
                        label: '搜索',
                        onTap: () => context.push('/search'),
                      ),
                      _SideMenuItem(
                        selected: false,
                        icon: Icons.notifications,
                        label: '通知',
                        onTap: () => context.push('/notifications'),
                      ),
                      _SideMenuItem(
                        selected: false,
                        icon: Icons.settings,
                        label: '设置',
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!UiMode.m1(context)) return _buildDesktopNavigationMenu(context);
    return isOhos
        ? _FloatingNavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            scrollController: scrollController,
          )
        : _buildMobileNavigationBar();
  }
}

const _destinations = [
  NavigationDestination(
    icon: Icon(Icons.category_outlined),
    label: '分类',
    selectedIcon: Icon(Icons.category),
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    label: '我的',
    selectedIcon: Icon(Icons.person),
  ),
];

class _FloatingNavigationBar extends StatefulWidget {
  const _FloatingNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.scrollController,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ScrollController? scrollController;

  @override
  State<_FloatingNavigationBar> createState() => _FloatingNavigationBarState();
}

class _FloatingNavigationBarState extends State<_FloatingNavigationBar> {
  double? _dragAlignment;
  Drag? _pageDrag;

  void _select(int index) {
    if (index == widget.selectedIndex) return;
    HapticFeedback.selectionClick();
    widget.onDestinationSelected(index);
  }

  void _track(double x, double width) {
    final alignment = (4 * x / width - 2).clamp(-1.0, 1.0).toDouble();
    setState(() => _dragAlignment = alignment);
  }

  void _finishSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final position = velocity.abs() > 400
        ? velocity
        : _dragAlignment ?? (widget.selectedIndex == 0 ? -1.0 : 1.0);
    setState(() => _dragAlignment = null);
    _select(position < 0 ? 0 : 1);
  }

  void _startPageDrag(DragStartDetails details) {
    final position = widget.scrollController?.positions.singleOrNull;
    if (position == null ||
        !position.hasContentDimensions ||
        !position.physics.shouldAcceptUserOffset(position)) {
      return;
    }
    _pageDrag = position.drag(details, () => _pageDrag = null);
  }

  @override
  void dispose() {
    _pageDrag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(26);
    final surface = scheme.surface.withValues(alpha: dark ? 0.72 : 0.63);
    final navigation = LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        excludeFromSemantics: true,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (details) =>
            _track(details.localPosition.dx, constraints.maxWidth),
        onHorizontalDragUpdate: (details) =>
            _track(details.localPosition.dx, constraints.maxWidth),
        onHorizontalDragEnd: _finishSwipe,
        onHorizontalDragCancel: () => setState(() => _dragAlignment = null),
        onVerticalDragStart: _startPageDrag,
        onVerticalDragUpdate: (details) => _pageDrag?.update(details),
        onVerticalDragEnd: (details) => _pageDrag?.end(details),
        onVerticalDragCancel: () => _pageDrag?.cancel(),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: AnimatedAlign(
                    alignment: Alignment(
                      _dragAlignment ?? (widget.selectedIndex == 0 ? -1 : 1),
                      0,
                    ),
                    duration: _dragAlignment != null || reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: highContrast
                              ? scheme.secondaryContainer
                              : scheme.secondaryContainer.withValues(
                                  alpha: dark ? 0.64 : 0.58,
                                ),
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            NavigationBar(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: _select,
              height: 64,
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: Colors.transparent,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: _destinations,
            ),
          ],
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: dark ? 0.17 : 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: highContrast
                        ? scheme.outline
                        : scheme.onSurface.withValues(
                            alpha: dark ? 0.24 : 0.13,
                          ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: highContrast
                      ? ColoredBox(color: scheme.surface, child: navigation)
                      : BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: ColoredBox(color: surface, child: navigation),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bg = selected ? scheme.secondaryContainer : Colors.transparent;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: scheme.primary.withValues(alpha: 0.08),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 20),
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const AppHeaderBar({super.key, required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final title = ['分类', '我的'][selectedIndex];
    final isCategory = title == '分类';
    final systemUiOverlayStyle = Theme.brightnessOf(context) == Brightness.light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    return AppBar(
      title: Text(title),
      backgroundColor: isCategory ? null : Colors.transparent,
      systemOverlayStyle: isCategory ? null : systemUiOverlayStyle,
      actions: [
        IconButton(
          onPressed: () => context.push('/search'),
          icon: const Icon(Icons.search),
          tooltip: '搜索',
        ),
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications),
          tooltip: '通知',
        ),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings),
          tooltip: '设置',
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
