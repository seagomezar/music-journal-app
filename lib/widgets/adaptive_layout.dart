import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Width classes are based on the space available to this app window, not on
/// the physical device. This keeps layouts correct in Split View and Stage
/// Manager as an iPad window is resized.
enum AppWindowSizeClass { compact, medium, expanded, extended }

abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double extended = 1180;
}

AppWindowSizeClass windowSizeClassForWidth(double width) {
  if (width >= AppBreakpoints.extended) {
    return AppWindowSizeClass.extended;
  }
  if (width >= AppBreakpoints.expanded) {
    return AppWindowSizeClass.expanded;
  }
  if (width >= AppBreakpoints.medium) {
    return AppWindowSizeClass.medium;
  }
  return AppWindowSizeClass.compact;
}

extension AppWindowSizeClassCapabilities on AppWindowSizeClass {
  bool get usesNavigationRail => this != AppWindowSizeClass.compact;

  bool get usesExtendedNavigationRail => this == AppWindowSizeClass.extended;

  bool get supportsTwoPaneContent =>
      this == AppWindowSizeClass.expanded ||
      this == AppWindowSizeClass.extended;
}

/// Returns the full display size in logical points. Unlike MediaQuery, this is
/// stable when an iPad app is placed in a narrow multitasking window.
Size logicalDisplaySizeOf(BuildContext context) {
  final ui.Display display = View.of(context).display;
  return display.size / display.devicePixelRatio;
}

bool isTabletDisplay(BuildContext context) =>
    logicalDisplaySizeOf(context).shortestSide >= AppBreakpoints.medium;

class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({
    required this.child,
    this.maxWidth = 960,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0, maxWidth).toDouble();
        return Align(
          alignment: alignment,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}
