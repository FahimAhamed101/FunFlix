import 'package:flutter/foundation.dart';

import 'title.dart';

/// One TV series in the catalogue.
///
/// Satisfies [CatalogTitle] so it can share rails, cards and the detail screen with
/// films — the only thing that makes it different to the UI is that opening it
/// leads to an episode list rather than a player.
@immutable
class TvSeries extends CatalogTitle {
  const TvSeries({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.shelf,
    required this.year,
    required this.rating,
    required this.genres,
    required this.cast,
    required this.posterSeed,
    this.imageUrl,
    this.backdropImageUrl,
    this.addedAt,
    this.seasonCount = 0,
    this.episodeRunTime = 0,
  });

  /// The portal's series id. Distinct from an episode id, which is what the
  /// playback URL is actually built from.
  @override
  final String id;

  @override
  final String title;

  @override
  final String synopsis;

  @override
  final String shelf;

  @override
  final int year;

  @override
  final double rating;

  @override
  final List<String> genres;

  @override
  final List<String> cast;

  @override
  final String posterSeed;

  /// Portrait cover.
  @override
  final String? imageUrl;

  @override
  final String? backdropImageUrl;

  @override
  final DateTime? addedAt;

  /// How many seasons the portal advertised. Zero when it did not say — the
  /// count is only known for certain once the detail call returns.
  final int seasonCount;

  /// Typical episode length in minutes, when the panel supplies one.
  final int episodeRunTime;

  @override
  bool get isSeries => true;

  @override
  String? get seasonsLabel {
    if (seasonCount <= 0) return null;
    return seasonCount == 1 ? '1 Season' : '$seasonCount Seasons';
  }

  TvSeries copyWith({int? seasonCount, String? backdropImageUrl}) {
    return TvSeries(
      id: id,
      title: title,
      synopsis: synopsis,
      shelf: shelf,
      year: year,
      rating: rating,
      genres: genres,
      cast: cast,
      posterSeed: posterSeed,
      imageUrl: imageUrl,
      backdropImageUrl: backdropImageUrl ?? this.backdropImageUrl,
      addedAt: addedAt,
      seasonCount: seasonCount ?? this.seasonCount,
      episodeRunTime: episodeRunTime,
    );
  }
}

/// One season of a series, as the detail call describes it.
@immutable
class Season {
  const Season({
    required this.number,
    required this.name,
    required this.episodeCount,
    this.overview = '',
    this.coverUrl,
    this.year,
  });

  final int number;
  final String name;
  final int episodeCount;
  final String overview;
  final String? coverUrl;
  final int? year;

  /// What the season picker shows: "Season 2", or the portal's own name when
  /// it has one that is not just a repeat of the number.
  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Season $number';
    final lower = trimmed.toLowerCase();
    if (lower == 'season $number' || lower == '$number') {
      return 'Season $number';
    }
    return trimmed;
  }
}

/// One episode.
@immutable
class Episode {
  const Episode({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    required this.synopsis,
    required this.runtimeMinutes,
    required this.rating,
    this.imageUrl,
    this.streamUrl,
  });

  /// The portal's episode id — this is what [streamUrl] is built from.
  final String id;

  final int season;
  final int number;
  final String title;
  final String synopsis;
  final int runtimeMinutes;
  final double rating;

  /// Landscape still. Usually present, often dead.
  final String? imageUrl;

  /// Playable URL. Null when the episode carried no id.
  final String? streamUrl;

  String get runtimeLabel {
    if (runtimeMinutes <= 0) return '--';
    final hours = runtimeMinutes ~/ 60;
    final minutes = runtimeMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  /// "S02E07" — the standard way to label an episode in a list.
  String get code =>
      'S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}';

  String get stillUrl =>
      imageUrl ?? 'https://picsum.photos/seed/ep-$id/640/360';
}

/// Everything the series detail screen needs, in one object.
@immutable
class SeriesDetail {
  const SeriesDetail({
    required this.series,
    required this.seasons,
    required this.episodes,
  });

  /// The series, enriched with anything the list call did not know — notably
  /// the real season count and a landscape backdrop.
  final TvSeries series;

  /// Seasons, ascending by number.
  final List<Season> seasons;

  /// Every episode across every season, ordered by season then episode number.
  final List<Episode> episodes;

  List<Episode> episodesFor(int season) =>
      episodes.where((e) => e.season == season).toList();

  bool get isEmpty => episodes.isEmpty;
}
