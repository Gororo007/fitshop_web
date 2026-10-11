import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Calls [onTimeout] after [timeout] without pointer or keyboard activity.
/// The timer only runs while [enabled] is true (e.g. user is logged in).
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.child,
    required this.onTimeout,
    this.enabled = true,
    this.timeout = const Duration(minutes: 15),
  });

  final Widget child;
  final VoidCallback onTimeout;
  final bool enabled;
  final Duration timeout;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  @override
  void didUpdateWidget(covariant InactivityWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.timeout != widget.timeout) {
      _restart();
    }
  }

  bool _onKey(KeyEvent event) {
    _restart();
    return false;
  }

  void _restart() {
    _timer?.cancel();
    if (!widget.enabled) return;
    _timer = Timer(widget.timeout, () {
      if (mounted && widget.enabled) widget.onTimeout();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerHover: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
