# FunFlix — custom-UI movie browser (Flutter)

A small but complete example of a streaming-style movie UI in Flutter, with the
catalogue behind a swappable data seam.

## Run it

```bash
cd flutter_movie_demo
flutter create .          # generates android/ ios/ web/ for your SDK version
flutter pub get
flutter run
```

`flutter create .` is only needed once — it fills in the platform folders
without touching `lib/`, `pubspec.yaml`, or anything below.

## Structure

```
lib/
  main.dart                     entry + bootstrap (saved portal? setup? demo?)
  models/movie.dart             the domain model the UI sees
  data/movie_repository.dart    the seam + mock implementation + sample data
  data/xtream_config.dart       portal / username / password value object
  data/xtream_movie_repository.dart   the real backend, via xtream_code_client
  data/credentials_store.dart   keystore-backed credential storage
  theme/app_theme.dart          palette and type scale
  widgets/movie_card.dart       poster tile + graceful artwork fallback
  widgets/hero_banner.dart      featured panel at the top of the home screen
  screens/setup_screen.dart     portal entry + connection test
  screens/home_screen.dart      shelves, loading state, error state
  screens/movie_detail_screen.dart
  screens/player_screen.dart    full-screen playback
example/fetch_movies.dart       standalone CLI demo of the VOD calls
```

## Launch flow

`AppBootstrap` in `main.dart` picks one of three states:

1. **A portal is saved** → `XtreamMovieRepository` → the real catalogue.
2. **Nothing saved** → the setup screen.
3. **Demo chosen** → `MockMovieRepository` → the bundled sample films, with a
   `SAMPLE DATA` badge in the app bar so it is never mistaken for a live feed.

The setup screen's **Test connection** makes one call to `serverInformation()`
and reads `user_info.auth` (1 = good, 0 = refused) before you commit. A bad
account fails there, not as an empty grid twenty seconds later.

Credentials go to the platform keystore via `flutter_secure_storage` — not
SharedPreferences, which on Android is a plaintext XML file in the app sandbox.

## Playback

`screens/player_screen.dart` is a full-screen `video_player` surface: tap to
toggle controls, scrub bar, play/pause, immersive fullscreen with landscape
lock, and an error state that names the actual failure.

`video_player` handles HLS (`.m3u8`) and MP4. If your panel serves raw MPEG-TS
or MKV and the player refuses it, swap in
[`media_kit`](https://pub.dev/packages/media_kit) — it wraps libmpv and opens
considerably more. The rest of the app does not care which you use; the player
only ever receives a URL string.

## Hitting a real Xtream portal

Two files do this, both behind the same seam:

- `lib/data/xtream_config.dart` — portal URL, username, password. A plain value
  object with no defaults, so no host is hard-coded anywhere in the project.
- `lib/data/xtream_movie_repository.dart` — implements `MovieRepository` on top
  of the [`xtream_code_client`](https://pub.dev/packages/xtream_code_client)
  package.

The call sequence is three steps, and the order matters:

1. **`vodCategories()`** — category id → display name. These become the shelves.
2. **`vodItems()`** — the full VOD list. Carries title, artwork, rating and
   container extension, but *not* the synopsis.
3. **`vodInfo(item)`** — per-title detail: plot, cast, genre, duration,
   release date. **One request per title**, so `detailBudget` (default 24)
   caps how many are enriched on first load. Enriching a 20,000-item catalogue
   up front would take minutes and hammer the panel.

Playback URL comes from `client.movieUrl(streamId, containerExtension)`.

### Standalone example

```bash
dart run example/fetch_movies.dart <portal-url> <username> <password>
# or keep credentials out of shell history:
XTREAM_URL=... XTREAM_USER=... XTREAM_PASS=... dart run example/fetch_movies.dart
```

It checks the line is valid (`user_info.auth`) before making catalogue calls,
then prints categories, the first five titles with full detail, and the playable
URL for each.

Point it at a portal you are entitled to use — the package's own disclaimer
says the same thing, and a client is only as authorised as the account behind it.

## What's here

- **Home** — parallax hero header, derived "Trending now" shelf (top-rated
  across everything), one shelf per category, horizontal poster rails.
- **Detail** — backdrop header, floating poster, genre chips, synopsis, cast,
  and a "More like this" rail scored by shared genres.
- **Player** — full-screen playback with a scrub bar and immersive mode.
- **Setup** — portal entry with a connection test, backed by the keystore.
- **Loading and error states** — real ones, not an afterthought. The mock
  repository fakes latency so you can actually see the skeleton.
- **Artwork resilience** — `PosterImage` falls back to a deterministic colour
  block derived from the seed when a URL fails, so dead posters never render
  as broken boxes.

## Notes

- Artwork is `picsum.photos` placeholders, seeded per title so they're stable
  across runs. When a real backend supplies `Movie.imageUrl`, that wins and the
  seed is only the fallback.
- `heroTag` on `MovieCard` includes the shelf name on purpose. A title can
  appear in both "Trending now" and its own shelf, and two `Hero` widgets
  sharing a tag is a hard runtime error in Flutter.
- Not compiled against a Flutter SDK — the package surface came from the
  pub.dev docs. Expect to shake out a name or two on first `pub get`.
