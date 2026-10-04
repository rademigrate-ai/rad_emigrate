import 'package:flutter/material.dart';

/// Chevron that flips correctly for RTL layouts.
IconData directionalChevron(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left
      : Icons.chevron_right;
}

IconData directionalBack(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl
      ? Icons.arrow_forward
      : Icons.arrow_back;
}

IconData directionalForward(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl
      ? Icons.arrow_back
      : Icons.arrow_forward;
}
