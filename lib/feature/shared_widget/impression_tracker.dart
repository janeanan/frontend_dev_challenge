import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Fires [onImpression] once when the child has been ≥50% visible
/// for at least 1 continuous second. No setState — no rebuilds.
class ImpressionTracker extends StatefulWidget {
  final VoidCallback onImpression;
  final Widget child;

  const ImpressionTracker({
    required super.key,
    required this.onImpression,
    required this.child,
  });

  @override
  State<ImpressionTracker> createState() => _ImpressionTrackerState();
}

class _ImpressionTrackerState extends State<ImpressionTracker> {
  Timer? _timer;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction >= 0.5) {
      // Start 1-second hold timer only if not already running.
      _timer ??= Timer(const Duration(seconds: 1), () {
        widget.onImpression();
        _timer = null;
      });
    } else {
      // Card scrolled out before 1 second — cancel and reset.
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.key!,
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}
