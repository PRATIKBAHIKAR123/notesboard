import 'dart:async';
import 'package:flutter/foundation.dart';

/// Simple debounce utility for high-frequency canvas interactions
/// (e.g. pointer dragging, window resizing) before writing to persistence.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
  }
}
