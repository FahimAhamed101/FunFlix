// Prefixed on purpose. The package exports its own `Season` and `Episode`,
// which collide with the app's models of the same name in this file.
import 'package:xtream_code_client/xtream_code_client.dart' as xtream;

import '../models/account.dart';
import '../models/live_channel.dart';
import '../models/movie.dart';
import '../models/programme.dart';
import '../models/series.dart';
import 'movie_repository.dart';
import 'xtream_config.dart';

/// Fetches everything the portal has — films, series, episodes and live
/// channels — from an Xtream-compatible backend.
///
/// This is the only file in the project that knows a backend exists. Pass it to
/// `MovieApp` in `main.dart` and every screen keeps working unchanged.
///
/// The portal and credentials arrive through [XtreamConfig], supplied by
/// whoever runs the app. Nothing is hard-coded here on purpose — that is what
/// makes this a player rather than a clone of one particular service.
class XtreamMovieRepository implements MovieRepository {
  XtreamMovieRepository({
    required this.config,
    this.detailBudget = 24,
    xtream.XtreamClient? client,
  }) : _client = client ??
            xtream.XtreamClient(
              url: config.normalisedPortalUrl,
              username: config.username,
              password: config.password,
            );

  final XtreamConfig config;

  /// How many titles get a full `vodInfo` fetch on first load.
  ///
  /// `get_vod_info` is one request per title. Pulling it for a 20,000-item
  /// catalogue would hammer the panel and take minutes, so only a slice of the
  /// list is enriched up front. The rest fill in when they are opened.
  final int detailBudget;

  final xtream.XtreamClient _client;

  /// Raw list items, keyed by our own string id.
  ///
  /// Kept because the client's detail and playback calls take the *item*, not
  /// an id — so without this a detail request would have to re-fetch the whole
  /// catalogue to find one row. Populated as a side effect of the list calls.
  final Map<String, xtream.VodItem> _vodIndex = <String, xtream.VodItem>{};
  final Map<String, xtream.SeriesItem> _seriesIndex =
      <String, xtream.SeriesItem>{};

  /// Releases the underlying HTTP client. The client holds a connection pool,
  /// so a repository that is replaced should be disposed rather than dropped.
  @override
  void dispose() => _client.close();

  // -------------------------------------------------------------------------
  // Films
  // -------------------------------------------------------------------------

  @override
  Future<List<Movie>> fetchMovies() async {
    final categoryNames = await _loadVodCategoryNames();
    final items = (await _client.vodItems()).data;
    if (items.isEmpty) return const <Movie>[];

    final details = await _loadVodDetails(_pickForEnrichment(items));

    final movies = <Movie>[
      for (final item in items)
        _toMovie(item, categoryNames, details[item.streamId]),
    ];

    for (var i = 0; i < items.length; i++) {
      _vodIndex[movies[i].id] = items[i];
    }

    return movies;
  }

  @override
  Future<Movie> fetchMovieDetail(Movie movie) async {
    final item = _vodIndex[movie.id];
    if (item == null) return movie;

    try {
      // `vodInfo` returns the wrapper, which holds both `info` (the editorial
      // fields) and `movieData` (the stream fields). `_toMovie` wants the
      // wrapper so it can read `info`.
      final detail = (await _client.vodInfo(item)).data;
      return _toMovie(item, const <int, String>{}, detail);
    } catch (_) {
      // A panel that refuses the detail call still has a playable stream; the
      // screen just keeps the metadata it already had.
      return movie;
    }
  }

  /// The playable URL for a film.
  ///
  /// The client assembles it from the stream id and container extension, which
  /// is exactly what a player widget needs.
  String movieStreamUrl(xtream.VodItem item) {
    final id = item.streamId;
    if (id == null) {
      throw const xtream.RequestException(
        'Item has no streamId, so it cannot be played.',
      );
    }
    return _client.movieUrl(id, item.containerExtension ?? 'mp4');
  }

  /// Chooses which rows get the expensive per-title detail call.
  ///
  /// Two groups, because they serve different parts of the home feed: the head
  /// of the list (what the panel considers current) and the best-rated titles
  /// (what the "Trending now" rail and the hero pick from). Without the second
  /// group a hero chosen by rating would frequently have no synopsis and no
  /// backdrop, because its rating was high but its position was 4,000th.
  List<xtream.VodItem> _pickForEnrichment(List<xtream.VodItem> items) {
    final head = items.take(detailBudget ~/ 2).toList();

    final byRating = <xtream.VodItem>[...items]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

    final picked = <xtream.VodItem>[...head];
    final seen = <int>{for (final item in picked) item.streamId ?? -1};

    for (final item in byRating) {
      if (picked.length >= detailBudget) break;
      final id = item.streamId;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      picked.add(item);
    }

    return picked;
  }

  /// Enriches a set of titles, a few at a time so the panel is not stampeded.
  /// A title whose detail call fails still gets a card.
  Future<Map<int, xtream.VodInfo>> _loadVodDetails(
    List<xtream.VodItem> items,
  ) async {
    final details = <int, xtream.VodInfo>{};
    const batchSize = 6;

    for (var start = 0; start < items.length; start += batchSize) {
      final batch = items.skip(start).take(batchSize).toList();
      final results = await Future.wait(
        batch.map((item) async {
          try {
            return (await _client.vodInfo(item)).data;
          } catch (_) {
            return null;
          }
        }),
      );

      for (var i = 0; i < batch.length; i++) {
        final id = batch[i].streamId;
        final detail = results[i];
        if (id != null && detail != null) details[id] = detail;
      }
    }

    return details;
  }

  Movie _toMovie(
    xtream.VodItem item,
    Map<int, String> categoryNames,
    xtream.VodInfo? detail,
  ) {
    // `get_vod_info` splits its payload in two: `info` carries the editorial
    // fields, `movieData` repeats the stream fields the list call already gave
    // us. Only `info` is interesting here.
    final info = detail?.info;
    final id = item.streamId;

    final genres = _split(info?.genre);
    final cast = _split(info?.cast);

    return Movie(
      id: id == null ? 'vod-${item.hashCode}' : '$id',
      title: info?.name ?? item.name ?? item.title ?? 'Untitled',
      synopsis: info?.plot ?? info?.description ?? '',
      shelf: _shelfFor(item.categoryId, categoryNames, genres, 'Movies'),
      year: _yearFrom(info?.releaseDate, item.year),
      rating: info?.rating ?? item.rating ?? 0,
      runtimeMinutes: _minutesFrom(
        duration: info?.duration,
        seconds: info?.durationSecs,
        episodeRunTime: info?.episodeRunTime,
      ),
      genres: genres.isEmpty ? const <String>['Uncategorised'] : genres,
      cast: cast,
      posterSeed: id == null ? 'vod' : '$id',
      imageUrl: item.streamIcon ?? info?.movieImage ?? info?.coverBig,
      backdropImageUrl: info?.movieImage ?? info?.coverBig,
      addedAt: item.added,
      streamUrl: id == null ? null : movieStreamUrl(item),
      containerExtension: item.containerExtension ?? 'mp4',
    );
  }

  // -------------------------------------------------------------------------
  // Series
  // -------------------------------------------------------------------------

  @override
  Future<List<TvSeries>> fetchSeries() async {
    final categoryNames = await _loadSeriesCategoryNames();
    final items = (await _client.seriesItems()).data;

    // No per-item detail call here, deliberately. Unlike `get_vod_streams`,
    // `get_series` already ships the plot, cast, genre, cover and rating — so
    // the whole series catalogue costs exactly two requests.
    final series = <TvSeries>[
      for (final item in items) _toSeries(item, categoryNames),
    ];

    for (var i = 0; i < items.length; i++) {
      _seriesIndex[series[i].id] = items[i];
    }

    return series;
  }

  @override
  Future<SeriesDetail> fetchSeriesDetail(TvSeries series) async {
    final item = _seriesIndex[series.id] ?? _stubSeriesItem(series.id);

    final info = (await _client.seriesInfo(item)).data;
    final details = info.info;

    final rawEpisodes =
        info.episodes ?? const <String, List<xtream.Episode>>{};

    final episodes = <Episode>[
      for (final entry in rawEpisodes.entries)
        for (final episode in entry.value) _toEpisode(episode, series.title),
    ]..sort(_bySeasonThenEpisode);

    // Seasons come from the payload when it lists them; when it does not, they
    // are derived from the episodes that actually arrived. Panels are
    // inconsistent about which of the two they populate, and a season picker
    // with nothing in it is worse than one inferred from real episodes.
    final seasons = <Season>[];
    for (final season in info.seasons ?? const <xtream.Season>[]) {
      final number = season.seasonNumber ?? (seasons.length + 1);
      seasons.add(
        Season(
          number: number,
          name: season.name ?? 'Season $number',
          episodeCount: season.episodeCount ?? _countIn(rawEpisodes, number),
          overview: season.overview ?? '',
          coverUrl: season.cover ?? season.coverBig,
          year: season.airDate?.year,
        ),
      );
    }

    if (seasons.isEmpty) {
      final numbers = <int>{for (final e in episodes) e.season}.toList()
        ..sort();
      for (final number in numbers) {
        seasons.add(
          Season(
            number: number,
            name: 'Season $number',
            episodeCount: _countIn(rawEpisodes, number),
          ),
        );
      }
    }
    seasons.sort((a, b) => a.number.compareTo(b.number));

    final genres = _split(details.genre);
    final cast = _split(details.cast);

    return SeriesDetail(
      series: TvSeries(
        id: series.id,
        title: details.name ?? details.title ?? series.title,
        synopsis: details.plot ?? series.synopsis,
        shelf: series.shelf,
        year: _yearFrom(details.releaseDate, details.year ?? '${series.year}'),
        rating: details.rating ?? series.rating,
        genres: genres.isEmpty ? series.genres : genres,
        cast: cast.isEmpty ? series.cast : cast,
        posterSeed: series.posterSeed,
        imageUrl: details.cover ?? series.imageUrl,
        backdropImageUrl:
            _firstUrl(details.backdropPath) ?? series.backdropImageUrl,
        addedAt: series.addedAt,
        seasonCount: seasons.isEmpty ? series.seasonCount : seasons.length,
        episodeRunTime: details.episodeRunTime ?? series.episodeRunTime,
      ),
      seasons: seasons,
      episodes: episodes,
    );
  }

  /// A minimal item, used only if the series index is cold.
  ///
  /// That happens when a title is restored from saved state rather than freshly
  /// listed. `seriesInfo` needs nothing but the id, so one can be
  /// reconstructed instead of re-downloading the entire series catalogue.
  xtream.SeriesItem _stubSeriesItem(String id) =>
      xtream.SeriesItem(seriesId: int.tryParse(id));

  int _countIn(Map<String, List<xtream.Episode>> episodes, int season) {
    final direct = episodes['$season'];
    if (direct != null) return direct.length;
    return episodes.values
        .expand((list) => list)
        .where((e) => (e.season ?? 0) == season)
        .length;
  }

  int _bySeasonThenEpisode(Episode a, Episode b) {
    final bySeason = a.season.compareTo(b.season);
    return bySeason != 0 ? bySeason : a.number.compareTo(b.number);
  }

  TvSeries _toSeries(
    xtream.SeriesItem item,
    Map<int, String> categoryNames,
  ) {
    final id = item.seriesId;
    final genres = _split(item.genre);

    return TvSeries(
      id: id == null ? 'series-${item.hashCode}' : '$id',
      title: item.name ?? item.title ?? 'Untitled',
      synopsis: item.plot ?? '',
      shelf: _shelfFor(item.categoryId, categoryNames, genres, 'TV Shows'),
      year: _yearFrom(item.releaseDate, item.year),
      rating: item.rating ?? 0,
      genres: genres.isEmpty ? const <String>['Uncategorised'] : genres,
      cast: _split(item.cast),
      posterSeed: id == null ? 'series' : '$id',
      imageUrl: item.cover,
      backdropImageUrl: _firstUrl(item.backdropPath),
      addedAt: item.lastModified,
      episodeRunTime: item.episodeRunTime ?? 0,
    );
  }

  Episode _toEpisode(xtream.Episode episode, String seriesTitle) {
    final info = episode.info;
    final id = episode.id;
    final number = episode.episodeNum ?? 0;
    final season = episode.season ?? 1;
    final rawTitle = episode.title?.trim();

    return Episode(
      id: id == null ? 'ep-${episode.hashCode}' : '$id',
      season: season,
      number: number,
      title: (rawTitle == null || rawTitle.isEmpty)
          ? '$seriesTitle · Episode $number'
          : rawTitle,
      synopsis: info.plot ?? '',
      runtimeMinutes: _minutesFrom(
        duration: info.duration,
        seconds: info.durationSecs,
        episodeRunTime: null,
      ),
      rating: info.rating ?? 0,
      imageUrl: info.movieImage ?? info.coverBig,
      streamUrl: id == null
          ? null
          : _client.seriesUrl(id, episode.containerExtension ?? 'mp4'),
    );
  }

  /// The playable URL for an episode, rebuilt from its parts.
  ///
  /// Exposed so a caller holding an [Episode] that arrived without a URL — a
  /// cached one, say — can still play it.
  String seriesStreamUrl(int episodeId, {String extension = 'mp4'}) =>
      _client.seriesUrl(episodeId, extension);

  // -------------------------------------------------------------------------
  // Live TV
  // -------------------------------------------------------------------------

  @override
  Future<List<LiveChannel>> fetchLiveChannels() async {
    final categoryNames = await _loadLiveCategoryNames();
    final items = (await _client.liveStreamItems()).data;

    return <LiveChannel>[
      for (final item in items) _toChannel(item, categoryNames),
    ];
  }

  /// The playable URL for a channel.
  ///
  /// Only `m3u8` is offered, and that is deliberate. The client prefers `ts`
  /// whenever it appears in the allowed list, but ExoPlayer handles HLS
  /// natively and progressive MPEG-TS poorly — so asking for HLS explicitly is
  /// what actually plays. Panels that serve live video at all serve it as HLS.
  String liveStreamUrl(xtream.LiveStreamItem item) {
    final id = item.streamId;
    if (id == null) {
      throw const xtream.RequestException(
        'Channel has no streamId, so it cannot be played.',
      );
    }
    return _client.streamUrl(id, const <String>['m3u8']);
  }

  LiveChannel _toChannel(
    xtream.LiveStreamItem item,
    Map<int, String> categoryNames,
  ) {
    final id = item.streamId;
    final categoryId = item.categoryId;
    final name = item.name?.trim();

    return LiveChannel(
      id: id == null ? 'live-${item.hashCode}' : '$id',
      name: (name == null || name.isEmpty)
          ? 'Channel ${item.num ?? ''}'.trim()
          : name,
      category: (categoryId == null ? null : categoryNames[categoryId]) ??
          'Live',
      logoUrl: item.streamIcon,
      streamUrl: id == null ? null : liveStreamUrl(item),
      epgChannelId: item.epgChannelId,
      hasArchive: (item.tvArchive ?? 0) > 0,
      // Panels label audio-only streams inconsistently, so this is a
      // best-effort guess from the category name. It only affects which icon
      // the player shows — a wrong guess still plays.
      audioOnly: _looksLikeRadio(categoryId == null
          ? null
          : categoryNames[categoryId]),
    );
  }

  // -------------------------------------------------------------------------
  // Account
  // -------------------------------------------------------------------------

  @override
  Future<AccountSnapshot?> fetchAccount() async {
    final info = (await _client.serverInformation()).data;
    final user = info.userInfo;
    final server = info.serverInfo;

    return AccountSnapshot(
      username: user.username ?? 'unknown',
      status: user.status ?? '',
      isTrial: user.isTrial ?? false,
      expiresAt: user.expDate,
      createdAt: user.createdAt,
      maxConnections: user.maxConnections,
      activeConnections: user.activeCons,
      serverVersion: server.version,
      serverTimezone: server.timezone,
      allowedFormats: user.allowedOutputFormats ?? const <String>[],
    );
  }

  @override
  Future<List<Programme>> fetchProgrammes(LiveChannel channel) async {
    final streamId = int.tryParse(channel.id);
    if (streamId == null) return const <Programme>[];

    // Most panels publish no guide at all, and some answer with an empty list
    // rather than an error. Neither is worth surfacing as a failure — the tile
    // simply shows no "on now" line.
    try {
      final epg = (await _client.channelEpgViaStreamId(streamId, 6)).data;
      final listings = epg.epgListings;
      if (listings == null) return const <Programme>[];

      final programmes = <Programme>[
        for (final listing in listings)
          if (listing.title != null && listing.title!.trim().isNotEmpty)
            Programme(
              title: listing.title!.trim(),
              description: _cleanDescription(listing.description),
              startsAt: listing.startTimestamp ?? listing.start,
              endsAt: listing.stopTimestamp ?? listing.stop,
            ),
      ];
      programmes.sort(_byStart);
      return programmes;
    } catch (_) {
      return const <Programme>[];
    }
  }

  /// Panels frequently return base64 here despite the field being documented
  /// as plain text. An undecodable blob is worse than nothing, so anything
  /// that does not look like prose is dropped.
  static String? _cleanDescription(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    // Base64 has no spaces and a very limited alphabet; real summaries do.
    final noSpaces = !text.contains(' ');
    final base64ish = RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(text);
    if (noSpaces && base64ish && text.length > 24) return null;
    return text;
  }

  /// Earliest first, with anything unscheduled pushed to the end.
  static int _byStart(Programme a, Programme b) {
    final left = a.startsAt;
    final right = b.startsAt;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }

  // -------------------------------------------------------------------------
  // Category names
  // -------------------------------------------------------------------------
  // Three separate maps on purpose: the film, series and live id spaces
  // overlap, so sharing one would file a channel under a film genre.

  Future<Map<int, String>> _loadVodCategoryNames() =>
      _categoryNames(_client.vodCategories());

  Future<Map<int, String>> _loadSeriesCategoryNames() =>
      _categoryNames(_client.seriesCategories());

  Future<Map<int, String>> _loadLiveCategoryNames() =>
      _categoryNames(_client.liveStreamCategories());

  /// Turns a category call into an id -> name map.
  ///
  /// A panel that refuses the call still has usable titles, so a failure here
  /// is swallowed and everything simply lands in the fallback shelf.
  Future<Map<int, String>> _categoryNames(
    Future<xtream.ApiResult<List<xtream.Category>>> request,
  ) async {
    final names = <int, String>{};
    try {
      for (final category in (await request).data) {
        final id = category.categoryId;
        final name = category.categoryName;
        if (id != null && name != null && name.isNotEmpty) names[id] = name;
      }
    } catch (_) {
      // Intentionally ignored — see above.
    }
    return names;
  }

  String _shelfFor(
    int? categoryId,
    Map<int, String> categoryNames,
    List<String> genres,
    String fallback,
  ) {
    final name = categoryId == null ? null : categoryNames[categoryId];
    if (name != null && name.isNotEmpty) return name;
    if (genres.isNotEmpty) return genres.first;
    return fallback;
  }

  /// A channel is audio-only when its category name points at radio. Xtream has
  /// no explicit flag, so this is the most reliable signal we have.
  static bool _looksLikeRadio(String? category) {
    if (category == null) return false;
    final lowered = category.toLowerCase();
    return lowered.contains('radio') ||
        lowered.contains('audio') ||
        lowered.contains('sound');
  }
}

// ---------------------------------------------------------------------------
// Field normalisation
// ---------------------------------------------------------------------------
// Panels disagree about types far more than about meaning: a genre arrives as
// one comma-separated string, a runtime as `HH:MM:SS` *or* minutes *or*
// seconds, a year as a bare string or as a real date, and a backdrop as a list
// that may or may not be empty. Normalise once, here, so that nothing
// downstream ever has to guess.

List<String> _split(String? raw) {
  if (raw == null) return const <String>[];
  return raw
      .split(RegExp(r'[,/|]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && part.toLowerCase() != 'n/a')
      .toList();
}

/// First usable entry of a backdrop list, or null.
///
/// The list is frequently present but empty, or holds blank strings — both of
/// which would otherwise become a request for the page itself.
String? _firstUrl(List<String>? urls) {
  if (urls == null) return null;
  for (final url in urls) {
    if (url.trim().isNotEmpty) return url.trim();
  }
  return null;
}

int _yearFrom(DateTime? releaseDate, String? fallback) {
  if (releaseDate != null && releaseDate.year > 1900) return releaseDate.year;
  if (fallback != null) {
    final match = RegExp(r'(19|20)\d{2}').firstMatch(fallback);
    if (match != null) return int.parse(match.group(0)!);
  }
  return DateTime.now().year;
}

/// Runtime arrives in three different shapes depending on the panel. Sniff
/// rather than assume, then fall back through the other duration fields.
int _minutesFrom({String? duration, int? seconds, int? episodeRunTime}) {
  if (duration != null && duration.contains(':')) {
    final parts = duration.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length >= 2) return parts[0] * 60 + parts[1];
  }

  final bare = duration == null ? null : int.tryParse(duration);
  if (bare != null && bare > 0) {
    // A bare number is usually minutes, but anything above ten hours is
    // almost certainly seconds.
    return bare > 600 ? (bare / 60).round() : bare;
  }

  if (episodeRunTime != null && episodeRunTime > 0) return episodeRunTime;
  if (seconds != null && seconds > 0) return (seconds / 60).round();
  return 0;
}
