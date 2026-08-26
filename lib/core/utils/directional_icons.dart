import 'package:flutter/material.dart';

/// Direction-aware icons for navigation that must mirror in RTL.
class DirectionalIcons {
  DirectionalIcons._();

  /// Chevron pointing towards the "previous" direction (back in reading order).
  static IconData chevronBackward(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_right
          : Icons.chevron_left;

  /// Chevron pointing towards the "next" direction (forward in reading order).
  static IconData chevronForward(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left
          : Icons.chevron_right;
}
