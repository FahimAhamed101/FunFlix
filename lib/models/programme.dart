import 'package:flutter/foundation.dart';

/// One programme in a channel's guide.
///
/// Times are kept as [DateTime]s rather than formatted strings so the same
/// listing can be shown as "On now", "20:30" or "in 12 min" depending on where
/// it appears, without the data layer guessing about presentation.
@immutable
class Programme {
  const Programme({
    required this.title,
    this.description,
    this.startsAt,
    this.endsAt,
  });

  final String title;
  final String? description;

  /// When the programme goes on air. Null when the portal omits it.
  final DateTime? startsAt;

  /// When it finishes. Null when the portal omits it.
  final DateTime? endsAt;

  /// True while [now] falls inside the broadcast window.
  ///
  /// A listing with no times is treated as current rather than discarded —
  /// some panels return the title of what is on air and nothing else, and that
  /// is still the most useful thing to show.
  bool isOnAirAt(DateTime now) {
    final start = startsAt;
    final end = endsAt;
    if (start == null || end == null) return true;
    return !now.isBefore(start) && now.isBefore(end);
  }

  /// `20:30`, or an em dash when the portal gave no start time.
  String get startLabel {
    final start = startsAt;
    if (start == null) return '—';
    final h = start.hour.toString().padLeft(2, '0');
    final m = start.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// How the UI labels it in a schedule: the slot, not the duration.
  String get slotLabel => startLabel;
}
