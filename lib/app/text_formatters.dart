import 'package:flutter/services.dart';

/// Input formatters for UI fields. They live here, outside `lib/ui`, because
/// L-10 keeps `services.dart` (and with it `HapticFeedback`) out of the UI.
final List<TextInputFormatter> digitsOnly = [
  FilteringTextInputFormatter.digitsOnly,
];
