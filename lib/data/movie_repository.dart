import '../models/account.dart';
import '../models/live_channel.dart';
import '../models/movie.dart';
import '../models/programme.dart';
import '../models/series.dart';
import '../models/title.dart';
import 'sample_data.dart';

export 'sample_data.dart';

/// A named rail on the home feed.
///
/// Holds [CatalogTitle]s rather than movies, so the same rail renders a film row, a
/// series row, or a mixed one.
class TitleShelf {
  const TitleShelf({required this.name, required this.titles});

  final String name;
  final List<CatalogTitle> titles;
}

/// The seam between the UI and whatever supplies the catalogue.
///
/// Every screen depends on this interface and nothing else, so the app is not
/// tied to any one backend. To go live, write another implementation — HTTP,
/// local database, bundled asset — and pass it to `MovieApp`. No screen changes.
///
/// Every method here maps to exactly one kind of Xtream data: films, series,
/// one series' seasons and episodes, live channels, and the account record.
abstract class MovieRepository {
  /// Video-on-demand titles.
  Future<List<Movie>> fetchMovies();

  /// The full record for one film.
  ///
  /// The list call only enriches the head of the catalogue — a plot summary
  /// and a runtime for every title in a 20,000-item catalogue would be 20,000
  /// requests. So the detail screen asks for the one it is about to show, and
  /// this returns the same title with whatever the portal adds.
  Future<Movie> fetchMovieDetail(Movie movie);

  /// Series, without their episodes.
  Future<List<TvSeries>> fetchSeries();

  /// Seasons and episodes for one series. One request; call it lazily, when a
  /// series is actually opened.
  Future<SeriesDetail> fetchSeriesDetail(TvSeries series);

  /// Live channels, in one flat list.
  ///
  /// Grouping into tabs is the screen's job, not the repository's — a backend
  /// that has no categories at all still satisfies this.
  Future<List<LiveChannel>> fetchLiveChannels();

  /// Who the portal thinks is signed in, and until when. Null when the
  /// implementation has no such notion (the sample catalogue).
  Future<AccountSnapshot?> fetchAccount();

  /// The electronic programme guide for one channel.
  ///
  /// Deliberately per channel and never per list: a panel with 200 channels
  /// would need 200 requests to fill a grid, and the only thing a viewer
  /// actually asks is "what is on this one". Empty when the portal publishes
  /// no guide, which most of them do not.
  Future<List<Programme>> fetchProgrammes(LiveChannel channel);

  /// Releases any held connections. Called when a repository is replaced, so
  /// signing out does not leak an HTTP pool.
  void dispose() {}
}

/// Ships the UI with data so the app runs with no network and no setup.
class MockMovieRepository implements MovieRepository {
  MockMovieRepository({this.latency = const Duration(milliseconds: 400)});

  /// Simulated round trip, so loading states are real rather than theoretical.
  final Duration latency;

  /// Honours [latency] without ever creating a timer when there is none.
  ///
  /// `Future.delayed(Duration.zero)` still schedules a `Timer`, and a widget
  /// test runs its body inside a fake-async zone where timers only fire when
  /// the clock is advanced by a pump. Awaiting such a future *before* the first
  /// `pump` therefore deadlocks the test with no error — it simply never
  /// returns. `Future.value()` completes on a microtask instead, which needs no
  /// clock, so `latency: Duration.zero` behaves the way it reads.
  Future<void> _wait() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  @override
  Future<List<Movie>> fetchMovies() async {
    await _wait();
    return kSampleMovies;
  }

  @override
  Future<Movie> fetchMovieDetail(Movie movie) async {
    await _wait();
    return movie;
  }

  @override
  Future<List<TvSeries>> fetchSeries() async {
    await _wait();
    return kSampleSeries;
  }

  @override
  Future<SeriesDetail> fetchSeriesDetail(TvSeries series) async {
    await _wait();

    final seasonCount = series.seasonCount <= 0 ? 1 : series.seasonCount;
    final seasons = <Season>[];
    final episodes = <Episode>[];

    for (var s = 1; s <= seasonCount; s++) {
      final count = _sampleEpisodeCount(series.id, s);
      seasons.add(
        Season(
          number: s,
          name: 'Season $s',
          episodeCount: count,
          year: series.year + s - 1,
        ),
      );
      for (var e = 1; e <= count; e++) {
        episodes.add(
          Episode(
            id: '${series.id}-s${s}e$e',
            season: s,
            number: e,
            title: _sampleEpisodeTitle(series.id, s, e),
            synopsis:
                'Sample episode. Connect a portal and this becomes the real '
                'plot summary, still and runtime for the episode.',
            runtimeMinutes:
                series.episodeRunTime > 0 ? series.episodeRunTime : 45,
            rating: series.rating,
          ),
        );
      }
    }

    return SeriesDetail(
      series: series.copyWith(seasonCount: seasonCount),
      seasons: seasons,
      episodes: episodes,
    );
  }

  @override
  Future<List<LiveChannel>> fetchLiveChannels() async {
    await _wait();
    return kSampleChannels;
  }

  @override
  Future<AccountSnapshot?> fetchAccount() async {
    await _wait();
    return AccountSnapshot(
      username: 'sample',
      status: 'Active',
      isTrial: false,
      expiresAt: DateTime.now().add(const Duration(days: 214)),
      createdAt: DateTime.now().subtract(const Duration(days: 151)),
      maxConnections: 2,
      activeConnections: 1,
      serverVersion: 'sample',
      serverTimezone: 'UTC',
      allowedFormats: const <String>['m3u8', 'ts'],
    );
  }

  @override
  Future<List<Programme>> fetchProgrammes(LiveChannel channel) async {
    await _wait();
    final now = DateTime.now();
    final startOfHour = DateTime(now.year, now.month, now.day, now.hour);
    // Three entries on the hour, so the guide looks like a schedule rather
    // than a single line — and so "on now" is genuinely the current slot.
    return <Programme>[
      for (var i = 0; i < 3; i++)
        Programme(
          title:
              '${channel.name} · ${_kProgrammeKinds[(channel.id.hashCode + i).abs() % _kProgrammeKinds.length]}',
          description: 'Sample listing. Connect a portal for the real guide.',
          startsAt: startOfHour.add(Duration(hours: i)),
          endsAt: startOfHour.add(Duration(hours: i + 1)),
        ),
    ];
  }

  @override
  void dispose() {}
}

/// Rotated through the sample guide so consecutive channels do not all read
/// the same.
const List<String> _kProgrammeKinds = <String>[
  'Live coverage',
  'Evening bulletin',
  'Documentary hour',
  'Classic film',
  'Highlights',
  'Studio talk',
];

/// Deterministic episode count, so the sample series look like real ones
/// without anyone having to hand-write a few hundred episodes.
int _sampleEpisodeCount(String seriesId, int season) {
  var hash = 11;
  for (final unit in '$seriesId#$season'.codeUnits) {
    hash = (hash * 31 + unit) & 0xFFFF;
  }
  return 6 + (hash % 5);
}

/// A plausible episode title, picked deterministically.
///
/// "Episode 7" repeated eighty times makes an episode list hard to read, and
/// hard to tell apart from a rendering bug.
const List<String> _kEpisodeTitles = <String>[
  'The Long Way Round',
  'Salt and Iron',
  'Everything We Left Behind',
  'The Quiet Part',
  'Ninth Floor',
  'A Small Kindness',
  'What the Water Took',
  'Paper Walls',
  'The Last Good Day',
  'Counting Backwards',
  'Nothing Personal',
  'The Weight of It',
  'Second Chances',
  'Homecoming',
  'The Price of Silence',
  'Ashes',
  'Cold Open',
  'The Turn',
  'Undertow',
  'Aftershock',
];

String _sampleEpisodeTitle(String seriesId, int season, int episode) {
  var hash = 17;
  for (final unit in '$seriesId-$season-$episode'.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return _kEpisodeTitles[hash % _kEpisodeTitles.length];
}

/// The best-rated titles across everything, for the "Trending now" rail.
///
/// Derived, not stored: a portal that reorders its own catalogue still gets a
/// sensible top row, and the sample catalogue gets one too.
List<CatalogTitle> trendingTitles(List<CatalogTitle> titles, {int limit = 10}) {
  final sorted = <CatalogTitle>[...titles]..sort((a, b) => b.rating.compareTo(a.rating));
  return sorted.take(limit).toList();
}

/// Groups titles into home-screen rails.
///
/// One rail per shelf, in first-seen order — which for a portal is the order
/// the panel returned its categories in, so the operator's own arrangement
/// survives. Titles with no shelf fall into a single fallback rail rather than
/// disappearing.
List<TitleShelf> buildShelves(List<CatalogTitle> titles) {
  final order = <String>[];
  final grouped = <String, List<CatalogTitle>>{};

  for (final title in titles) {
    final key = title.shelf.trim().isEmpty ? 'More to explore' : title.shelf;
    if (!grouped.containsKey(key)) {
      grouped[key] = <CatalogTitle>[];
      order.add(key);
    }
    grouped[key]!.add(title);
  }

  return <TitleShelf>[
    for (final name in order) TitleShelf(name: name, titles: grouped[name]!),
  ];
}
