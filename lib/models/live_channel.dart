import 'package:flutter/foundation.dart';

/// One live channel.
///
/// Same rule as [Movie]: no backend vocabulary leaks past this point. The UI
/// never sees a `LiveStreamItem`, it sees this, so the live section keeps
/// working if the source is ever swapped.
@immutable
class LiveChannel {
  const LiveChannel({
    required this.id,
    required this.name,
    required this.category,
    this.logoUrl,
    this.streamUrl,
    this.epgChannelId,
    this.hasArchive = false,
    this.audioOnly = false,
  });

  final String id;
  final String name;

  /// Which group the channel sits in. Panels call these "categories"; the UI
  /// shows them as tabs. "24/7 Channels", "Radio" and "PPV & Sports" are just
  /// more of these — the app never treats them specially, so a provider that
  /// has them simply gets more tabs.
  final String category;

  /// Channel logo. Frequently missing, or a dead link — the tile falls back to
  /// [initials] rather than showing a broken image.
  final String? logoUrl;

  /// Playable URL from the backend. Null for the bundled sample data.
  final String? streamUrl;

  /// Key into the portal's EPG. Not used yet, carried so the guide can be
  /// added without touching the data layer again.
  final String? epgChannelId;

  /// True when the portal offers catch-up for this channel.
  final bool hasArchive;

  /// True for audio-only streams — radio stations, and some panels' "music"
  /// channels. The player shows a dedicated audio surface instead of a black
  /// video frame, so a radio station is obviously a radio station.
  final bool audioOnly;

  /// Monogram for the logo fallback — "BBC News" becomes "BN".
  ///
  /// Many channels are named entirely in non-Latin script, or are just a bare
  /// number. Those fall through to a neutral label instead of rendering an
  /// empty box.
  String get initials {
    final cleaned = name
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isEmpty) return 'TV';

    final words = cleaned.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'TV';
    if (words.length == 1) {
      final word = words.first;
      return (word.length <= 2 ? word : word.substring(0, 2)).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}
