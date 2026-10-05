import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movie_ui_demo/data/movie_repository.dart';
import 'package:movie_ui_demo/main.dart';
import 'package:movie_ui_demo/models/account.dart';
import 'package:movie_ui_demo/models/live_channel.dart';
import 'package:movie_ui_demo/models/movie.dart';
import 'package:movie_ui_demo/models/programme.dart';
import 'package:movie_ui_demo/models/series.dart';
import 'package:movie_ui_demo/screens/live_tv_screen.dart';
import 'package:movie_ui_demo/screens/main_shell.dart';
import 'package:movie_ui_demo/screens/movie_detail_screen.dart';
import 'package:movie_ui_demo/screens/my_netflix_screen.dart';
import 'package:movie_ui_demo/services/video_cache_manager.dart';
import 'package:movie_ui_demo/theme/app_theme.dart';
import 'package:movie_ui_demo/widgets/n_ui.dart';

/// A repository whose account call fails the way an unreachable portal does.
///
/// Everything else still works, so this isolates the one thing being tested:
/// that a broken network does not take the sign-out control with it.
class _OfflineRepository implements MovieRepository {
  @override
  Future<AccountSnapshot?> fetchAccount() async =>
      throw Exception('SocketException: offline');

  @override
  Future<List<Movie>> fetchMovies() async => kSampleMovies;

  @override
  Future<Movie> fetchMovieDetail(Movie movie) async => movie;

  @override
  Future<List<TvSeries>> fetchSeries() async => kSampleSeries;

  @override
  Future<SeriesDetail> fetchSeriesDetail(TvSeries series) async =>
      MockMovieRepository(latency: Duration.zero).fetchSeriesDetail(series);

  @override
  Future<List<LiveChannel>> fetchLiveChannels() async => kSampleChannels;

  @override
  Future<List<Programme>> fetchProgrammes(LiveChannel channel) async =>
      const <Programme>[];

  @override
  void dispose() {}
}

/// Makes the test surface tall enough that slivers below the hero are built.
///
/// The default 800x600 window only ever builds the hero and the first rail, so
/// an assertion about a rail further down would fail for layout reasons rather
/// than because anything is broken.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Drains a simulated network round trip.
///
/// `pumpAndSettle` stops as soon as no frame is scheduled, so on its own it
/// never fires the `Future.delayed` the sample repository uses — and worse, a
/// single `pump(duration)` elapses the clock *before* the frame in which that
/// timer is created. Stepping the clock in small increments after the frame
/// guarantees a pending timer falls inside one of them.
Future<void> settleAfterLoad(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('Sample catalogue', () {
    test('covers every category real panels hide inside Live TV', () {
      final live = kSampleChannels.map((c) => c.category).toSet();
      expect(
        live,
        containsAll(<String>['24/7 Channels', 'Radio', 'PPV & Sports']),
      );
      // Radio channels are flagged so the sheet can say they are audio-only.
      expect(
        kSampleChannels.where((c) => c.category == 'Radio').every((c) => c.audioOnly),
        isTrue,
      );
    });

    test('covers the extra VOD and series categories', () {
      final movies = kSampleMovies.map((m) => m.shelf).toSet();
      final series = kSampleSeries.map((s) => s.shelf).toSet();
      expect(
        movies,
        containsAll(<String>['Documentaries', 'Concerts & Music', 'Adult']),
      );
      expect(
        series,
        containsAll(<String>['Reality & Talk', 'Anime & Cartoons']),
      );
    });
  });

  group('MockMovieRepository', () {
    final repo = MockMovieRepository(latency: Duration.zero);

    test('serves both films and series', () async {
      expect(await repo.fetchMovies(), isNotEmpty);
      expect(await repo.fetchSeries(), isNotEmpty);
      expect(await repo.fetchLiveChannels(), isNotEmpty);
    });

    test('every series carries ordered seasons and episodes', () async {
      for (final series in await repo.fetchSeries()) {
        final detail = await repo.fetchSeriesDetail(series);

        expect(detail.seasons, isNotEmpty, reason: series.title);
        expect(detail.episodes, isNotEmpty, reason: series.title);
        expect(detail.series.seasonCount, detail.seasons.length,
            reason: series.title);

        // Seasons ascend, because the picker lists them in order.
        for (var i = 1; i < detail.seasons.length; i++) {
          expect(detail.seasons[i].number,
              greaterThan(detail.seasons[i - 1].number));
        }

        // Episodes are ordered by season, then by episode number.
        for (var i = 1; i < detail.episodes.length; i++) {
          final previous = detail.episodes[i - 1];
          final current = detail.episodes[i];
          final ordered = current.season > previous.season ||
              (current.season == previous.season &&
                  current.number >= previous.number);
          expect(ordered, isTrue, reason: '${series.title} episode order');
        }

        // A season with no episodes would render an empty picker entry.
        for (final season in detail.seasons) {
          expect(detail.episodesFor(season.number), isNotEmpty,
              reason: '${series.title} S${season.number}');
        }
      }
    });

    test('trending is ranked and shelving keeps every title', () async {
      final movies = await repo.fetchMovies();
      final top = trendingTitles(movies, limit: 5);

      expect(top.length, 5);
      for (var i = 1; i < top.length; i++) {
        expect(top[i - 1].rating, greaterThanOrEqualTo(top[i].rating));
      }

      final shelved = buildShelves(movies).fold<int>(
        0,
        (total, shelf) => total + shelf.titles.length,
      );
      expect(shelved, movies.length,
          reason: 'no title may be dropped when grouping into rails');
    });
  });

  testWidgets('the home feed builds its rails from the catalogue',
      (tester) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MainShell(
          repository: MockMovieRepository(latency: Duration.zero),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('Top 10 in TV Shows Today'), findsOneWidget);
    expect(find.text('Top 10 in Movies Today'), findsOneWidget);

    // The filter pills and the category picker entry point.
    expect(find.text('TV Shows'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('a series page shows the season picker and its episodes',
      (tester) async {
    useTallSurface(tester);

    final repo = MockMovieRepository(latency: Duration.zero);

    // Read the sample list directly rather than awaiting the repository before
    // the first pump: a widget test body runs inside fake async, so any timer
    // created before a pump never fires.
    final series = kSampleSeries.firstWhere((s) => s.seasonCount > 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MovieDetailScreen(title: series, repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Play has to point at something concrete on a series page.
    expect(find.text('Play S1 E1'), findsOneWidget);
    expect(find.text(series.title), findsWidgets);

    // The first season's episodes are listed. `_EpisodeRow` labels each one
    // "S01E01", which is stable regardless of what the portal calls the episode.
    expect(find.text('S01E01'), findsOneWidget);

    // Opening the picker offers every season.
    await tester.tap(find.text('Season 1').first);
    await tester.pumpAndSettle();

    expect(find.text('Select a season'), findsOneWidget);
    expect(find.text('Season 2'), findsWidgets);
  });

  testWidgets('sign out still works when the account request fails',
      (tester) async {
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MyFunFlixScreen(
          repository: _OfflineRepository(),
          onSignOut: () async => signedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The failure is reported, and translated rather than dumped raw.
    expect(find.text('Could not read the account details'), findsOneWidget);
    expect(find.textContaining('Could not reach the portal'), findsOneWidget);

    // ...and the way out is still there, and still works.
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
  });

  testWidgets('tapping a channel opens its guide, not the player',
      (tester) async {
    final repo = MockMovieRepository(latency: Duration.zero);
    final channels = await repo.fetchLiveChannels();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: LiveTvScreen(repository: repo),
      ),
    );
    await settleAfterLoad(tester);

    await tester.tap(find.text(channels.first.name).first);
    await settleAfterLoad(tester);

    // The guide replaces the old tap-to-play: a channel now gets the same
    // detail-then-play shape a film does.
    expect(find.text('Watch live'), findsOneWidget);
    expect(find.text('ON NOW'), findsOneWidget);
    expect(find.text(channels.first.name), findsWidgets);
  });

  testWidgets('the app enters a session and leaves it again', (tester) async {
    // The sign-in screen is a ListView, so on a short window the sample-data
    // action is never built and cannot be found. A tall surface keeps the whole
    // form in the tree.
    useTallSurface(tester);

    // No keystore plugin exists in a test, so `CredentialsStore.read()` throws
    // and the app must still land on sign-in rather than hanging on the
    // spinner. Reaching the button below proves that path works.
    await tester.pumpWidget(const MovieApp());
    await tester.pumpAndSettle();

    expect(find.text('Browse the sample catalogue'), findsOneWidget);

    await tester.tap(find.text('Browse the sample catalogue'));
    await settleAfterLoad(tester);

    expect(find.text('Trending Now'), findsOneWidget);

    await tester.tap(find.text('My FunFlix'));
    await settleAfterLoad(tester);

    expect(find.text('Sign out'), findsOneWidget);
    // We came in through the sample catalogue, so the portal action is the
    // demo one rather than "Switch account".
    expect(find.text('Connect a portal'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // Back at sign-in, with the fields cleared.
    expect(find.widgetWithText(NPrimaryButton, 'Sign In'), findsOneWidget);
    expect(find.text('Browse the sample catalogue'), findsOneWidget);
  });

  testWidgets('selecting a category displays the category grid of titles',
      (tester) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MainShell(
          repository: MockMovieRepository(latency: Duration.zero),
          onSignOut: () async {},
        ),
      ),
    );
    await settleAfterLoad(tester);

    // Open the Categories sheet from the top bar
    expect(find.text('Categories'), findsOneWidget);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    // The searchable category sheet should be open
    expect(find.text('Select Category'), findsOneWidget);
    expect(find.text('Sci-Fi'), findsOneWidget);

    // Pick Sci-Fi
    await tester.tap(find.text('Sci-Fi'));
    await tester.pumpAndSettle();

    // The category header should appear with title and count
    expect(find.textContaining('titles available'), findsOneWidget);

    // Going back to All restores the main home feed
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();

    expect(find.text('Trending Now'), findsOneWidget);
  });

  test('VideoCacheManager cleans video cache and trims image memory without throwing', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
    expect(VideoCacheManager.instance.clearPlayerCache(), completes);
  });
}

