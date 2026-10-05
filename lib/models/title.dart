import 'package:flutter/foundation.dart';

/// What a movie and a TV series have in common.
///
/// The home feed, the poster rails, the search results and the detail screen
/// all deal in *titles*, not in "movies" or "series" specifically. Putting the
/// shared surface here means a rail is written once and renders either, and a
/// tap can be routed without the caller first asking what it is holding.
///
/// Deliberately an interface rather than a base class: neither [Movie] nor
/// [TvSeries] is a kind of the other, they simply both satisfy this shape.
@immutable
abstract class CatalogTitle {
  /// Const so that subclasses can keep their own const constructors — the
  /// sample catalogue is built from const literals.
  const CatalogTitle();

  /// Stable identity. For a portal title this is the stream or series id.
  String get id;

  String get title;
  String get synopsis;

  /// Which rail this title belongs to on the home feed.
  String get shelf;

  int get year;

  /// 0.0 - 10.0, as Xtream supplies it.
  double get rating;

  List<String> get genres;
  List<String> get cast;

  /// Seed for the placeholder artwork, used only when [imageUrl] is missing or
  /// the image fails to load.
  String get posterSeed;

  /// Portrait artwork. Usually a 2:3 poster.
  String? get imageUrl;

  /// Landscape artwork, for heroes and wide cards. Falls back to [imageUrl]
  /// when the portal only supplies one image.
  String? get backdropImageUrl;

  /// When the portal says this title was added. Null for the sample catalogue,
  /// which has no such notion.
  DateTime? get addedAt;

  /// True for a series, so a tap can route to the episode list instead of
  /// straight to the player.
  bool get isSeries;

  String get posterUrl =>
      imageUrl ?? 'https://picsum.photos/seed/$posterSeed/400/600';

  String get backdropUrl =>
      backdropImageUrl ??
      imageUrl ??
      'https://picsum.photos/seed/$posterSeed-wide/1280/720';

  String get ratingLabel => rating.toStringAsFixed(1);

  /// "1 Season" / "4 Seasons", or null for a film.
  String? get seasonsLabel;
}
