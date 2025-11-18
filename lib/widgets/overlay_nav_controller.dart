import 'package:flutter/foundation.dart';

/// Simple helper to control overlay nav visibility from outside
/// without coupling state into the widget.
class OverlayNavController {
  OverlayNavController({bool initiallyHidden = false})
      : hiddenNotifier = ValueNotifier<bool>(initiallyHidden);

  final ValueNotifier<bool> hiddenNotifier;

  bool get isHidden => hiddenNotifier.value;

  void hide() => hiddenNotifier.value = true;
  void show() => hiddenNotifier.value = false;

  /// Toggle hidden state. If [value] is provided, set explicitly.
  void toggle([bool? value]) {
    if (value == null) {
      hiddenNotifier.value = !hiddenNotifier.value;
    } else {
      hiddenNotifier.value = value;
    }
  }

  void dispose() => hiddenNotifier.dispose();
}
