import 'package:flutter/foundation.dart';

import 'title.dart';

/// One film in the catalogue.
///
/// Deliberately free of any backend vocabulary: the UI never sees a raw API
/// payload, it sees this. That is what lets the data source be swapped without
/// touching a single screen.
@immutable
class Movie extends CatalogTitle {
  const Movie({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.shelf,
    required this.year,
    required this.rating,
    required this.runtimeMinutes,
    required this.genres,
    required this.cast,
    required this.posterSeed,
    this.imageUrl,
    this.backdropImageUrl,
    this.addedAt,
    this.streamUrl,
    this.containerExtension = 'mp4',
  });

  @override
  final String id;

  @override
  final String title;

  @override
  final String synopsis;

  /// Which rail this title belongs to on the home feed.
  @override
  final String shelf;

  @override
  final int year;

  /// 0.0 - 10.0
  @override
  final double rating;

  final int runtimeMinutes;

  @override
  final List<String> genres;

  @override
  final List<String> cast;

  /// Seed for the placeholder artwork. A real backend supplies [imageUrl]
  /// instead, and the seed is only used if that is missing or fails to load.
  @override
  final String posterSeed;

  /// Portrait artwork from the backend, when there is any.
  @override
  final String? imageUrl;

  /// Landscape artwork. Most panels ship only the portrait one, in which case
  /// [backdropUrl] falls back to it rather than showing nothing.
  @override
  final String? backdropImageUrl;

  @override
  final DateTime? addedAt;

  /// Playable URL from the backend. Null for the bundled sample data.
  final String? streamUrl;

  /// Container the portal serves this title in — `mp4`, `mkv`, `avi`. Carried
  /// so a playback URL can be rebuilt for a title that arrived without one.
  final String containerExtension;

  @override
  bool get isSeries => false;

  @override
  String? get seasonsLabel => null;

  String get runtimeLabel {
    final hours = runtimeMinutes ~/ 60;
    final minutes = runtimeMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }
}
