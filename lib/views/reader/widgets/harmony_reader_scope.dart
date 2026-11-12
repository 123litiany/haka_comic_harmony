import 'dart:async';

import 'package:flutter/material.dart';
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/router/route_observer.dart';
import 'package:haka_comic/utils/ohos_reader.dart';
import 'package:haka_comic/widgets/toast.dart';

/// Releases hardware keys, brightness and the wake lock whenever another route,
/// a drawer, or another application covers the reader.
class HarmonyReaderScope extends StatefulWidget {
  const HarmonyReaderScope({
    super.key,
    required this.child,
    required this.onPrevious,
    required this.onNext,
    required this.onActivityChanged,
    this.interactionsEnabled = true,
    this.bridge,
  });

  final Widget child;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<bool> onActivityChanged;
  final bool interactionsEnabled;
  final OhosReaderBridge? bridge;

  @override
  State<HarmonyReaderScope> createState() => _HarmonyReaderScopeState();
}

class _HarmonyReaderScopeState extends State<HarmonyReaderScope>
    with WidgetsBindingObserver, RouteAware {
  late final _bridge = widget.bridge ?? OhosReaderBridge.instance;
  StreamSubscription<String>? _keys;
  ModalRoute<void>? _route;
  bool _foreground = true;
  bool _active = false;
  bool _reportedKeyFailure = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    OhosReaderBridge.preferencesRevision.addListener(_sync);
    _keys = _bridge.volumeKeys.listen((key) {
      if (!_active || !AppConf().enableVolume) return;
      if (key == 'up') widget.onPrevious();
      if (key == 'down') widget.onNext();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      routeObserver.unsubscribe(this);
      _route = route;
      if (route != null) routeObserver.subscribe(this, route);
    }
    _sync();
  }

  @override
  void didUpdateWidget(HarmonyReaderScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactionsEnabled != widget.interactionsEnabled) _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void didPushNext() => _sync(forceInactive: true);
  @override
  void didPopNext() => _sync();
  @override
  void didPop() => _sync(forceInactive: true);

  void _sync({bool forceInactive = false}) {
    final active =
        !forceInactive &&
        mounted &&
        _foreground &&
        widget.interactionsEnabled &&
        (_route?.isCurrent ?? false);
    if (active != _active) {
      _active = active;
      widget.onActivityChanged(active);
    }
    final revision = ++_revision;
    final conf = AppConf();
    _bridge
        .configure(
          active: active,
          volumeKeys: conf.enableVolume,
          keepScreenOn: conf.readerKeepScreenOn,
          brightness: conf.readerBrightness,
        )
        .then((listening) {
          if (!mounted ||
              revision != _revision ||
              !_active ||
              !conf.enableVolume ||
              listening ||
              _reportedKeyFailure) {
            return;
          }
          _reportedKeyFailure = true;
          Toast.show(message: '此设备暂时无法监听音量键，请使用点击或滑动翻页。');
        });
  }

  @override
  void dispose() {
    ++_revision;
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    OhosReaderBridge.preferencesRevision.removeListener(_sync);
    _keys?.cancel();
    if (_active) {
      _bridge.configure(
        active: false,
        volumeKeys: false,
        keepScreenOn: false,
        brightness: -1,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
