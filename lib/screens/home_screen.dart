import 'package:flutter/material.dart';

import '../data/movie_repository.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/title.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_banner.dart';
import '../widgets/movie_card.dart';
import '../widgets/n_ui.dart';
import 'movie_detail_screen.dart';
import 'search_screen.dart';

/// The home feed.
///
/// Films and series arrive already loaded, from the shell. That is deliberate:
/// three tabs share one catalogue, and re-running `get_vod_streams` — tens of
/// megabytes on a real panel — once per tab would be the single most expensive
/// thing the app does.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.movies,
    required this.series,
    required this.loading,
    required this.error,
    required this.onReload,
    this.demoMode = false,
    this.onOpenProfile,
  });

  final MovieRepository repository;
  final List<Movie> movies;
  final List<TvSeries> series;
  final bool loading;
  final Object? error;
  final Future<void> Function() onReload;

  /// True when the bundled sample catalogue is showing rather than a portal.
  final bool demoMode;

  /// Opens the account tab. Null hides the avatar.
  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// How many category rails of each kind are shown before the feed stops.
///
/// A large portal returns a hundred categories. Rendering them all makes the
/// home feed an endless list of three-item rails; the operator's first batch is
/// the interesting part, and the Categories sheet reaches the rest. Set high
/// enough that a typical panel's every category appears on the feed.
const int _kMaxSeriesRails = 30;
const int _kMaxMovieRails = 30;

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scroll = ScrollController();

  /// Drives the top bar's background only. Kept out of `setState` so scrolling
  /// repaints one small subtree instead of the entire feed.
  final ValueNotifier<double> _barT = ValueNotifier<double>(0);

  /// Active content filters. Empty means "everything".
  final Set<String> _active = <String>{};

  /// When set, only this rail is shown. Chosen from the Categories sheet.
  String? _onlyShelf;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _barT.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final t = (_scroll.offset / 220).clamp(0.0, 1.0);
    // Only notify on a visible change; a per-pixel notification would repaint
    // the bar sixty times a second for nothing.
    if ((t - _barT.value).abs() > 0.02) _barT.value = t;
  }

  List<CatalogTitle> get _everything => <CatalogTitle>[...widget.movies, ...widget.series];

  void _open(CatalogTitle title, {String? heroTag}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MovieDetailScreen(
          title: title,
          repository: widget.repository,
          catalogue: _everything,
          heroTag: heroTag,
        ),
      ),
    );
  }

  Future<void> _pickCategory() async {
    final shelves = <String>{
      for (final shelf in buildShelves(widget.movies)) shelf.name,
      for (final shelf in buildShelves(widget.series)) shelf.name,
    }.toList()
      ..sort();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _CategorySheet(shelves: shelves, selected: _onlyShelf),
    );

    if (!mounted) return;
    // A null result means the sheet was dismissed without choosing — which must
    // not clear an existing filter.
    if (picked == null) return;
    setState(() => _onlyShelf = picked == _kAllCategories ? null : picked);
  }

  void _toggle(String key) {
    setState(() {
      if (!_active.remove(key)) _active.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const _HomeSkeleton();

    final hasAnything = widget.movies.isNotEmpty || widget.series.isNotEmpty;
    if (!hasAnything) return _HomeError(onRetry: widget.onReload, detail: widget.error);

    final featured = trendingTitles(_everything, limit: 1).first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          RefreshIndicator(
            onRefresh: widget.onReload,
            color: AppColors.accent,
            backgroundColor: AppColors.surface,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 470,
                    child: HeroBanner(
                      title: featured,
                      onPlay: () => _open(featured),
                      onDetails: () => _open(featured),
                    ),
                  ),
                ),
                ..._rails(),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _barT,
              builder: (context, t, _) => _TopBar(
                background: t,
                active: _active,
                onToggle: _toggle,
                onCategories: _pickCategory,
                onlyShelf: _onlyShelf,
                onClearShelf: () => setState(() => _onlyShelf = null),
                demoMode: widget.demoMode,
                onOpenProfile: widget.onOpenProfile,
                onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SearchScreen(
                      movies: widget.movies,
                      series: widget.series,
                      onOpen: _open,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rails() {
    final wantMovies = _active.isEmpty || _active.contains(_kMovies);
    final wantSeries = _active.isEmpty || _active.contains(_kSeries);

    final rails = <Widget>[];

    void add(String heading, List<CatalogTitle> titles, _RailKind kind) {
      if (titles.isEmpty) return;
      rails.add(
        SliverToBoxAdapter(
          child: _Rail(
            heading: heading,
            titles: titles,
            kind: kind,
            onTap: _open,
          ),
        ),
      );
    }

    // A chosen category replaces the whole feed rather than filtering it — the
    // point of picking "4K UHD" is to see that shelf, not to see it plus
    // twenty-five others.
    if (_onlyShelf != null) {
      add(
        _onlyShelf!,
        <CatalogTitle>[
          if (wantMovies) ...widget.movies.where((m) => m.shelf == _onlyShelf),
          if (wantSeries) ...widget.series.where((s) => s.shelf == _onlyShelf),
        ],
        _RailKind.poster,
      );
      return rails.isEmpty
          ? <Widget>[const SliverToBoxAdapter(child: _NoResults())]
          : rails;
    }

    final mixed = <CatalogTitle>[
      if (wantMovies) ...widget.movies,
      if (wantSeries) ...widget.series,
    ];

    add('Trending Now', trendingTitles(mixed, limit: 10), _RailKind.wide);

    if (wantSeries) {
      add(
        'Top 10 in TV Shows Today',
        trendingTitles(widget.series, limit: 10),
        _RailKind.ranked,
      );
    }
    if (wantMovies) {
      add(
        'Top 10 in Movies Today',
        trendingTitles(widget.movies, limit: 10),
        _RailKind.ranked,
      );
    }

    if (wantSeries) {
      for (final shelf in buildShelves(widget.series).take(_kMaxSeriesRails)) {
        add('TV Shows · ${shelf.name}', shelf.titles, _RailKind.poster);
      }
    }
    if (wantMovies) {
      for (final shelf in buildShelves(widget.movies).take(_kMaxMovieRails)) {
        add(shelf.name, shelf.titles, _RailKind.poster);
      }
    }

    return rails;
  }
}

const String _kSeries = 'series';
const String _kMovies = 'movies';

/// Sentinel returned by the Categories sheet for "All categories".
const String _kAllCategories = '\u0000all';

enum _RailKind { poster, wide, ranked }

/// One horizontal rail: a heading and a lazily-built list of artwork.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.heading,
    required this.titles,
    required this.kind,
    required this.onTap,
  });

  final String heading;
  final List<CatalogTitle> titles;
  final _RailKind kind;
  final void Function(CatalogTitle title, {String? heroTag}) onTap;

  @override
  Widget build(BuildContext context) {
    final height = switch (kind) {
      _RailKind.poster => 200.0,
      _RailKind.wide => 132.0,
      _RailKind.ranked => 170.0,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NSectionHeader(title: heading),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: titles.length,
              separatorBuilder: (_, __) => SizedBox(
                width: kind == _RailKind.ranked ? 4 : 8,
              ),
              itemBuilder: (context, index) {
                final title = titles[index];
                // The rail name is part of the hero tag: a title can sit in
                // both "Trending Now" and its own rail at once, and two heroes
                // sharing a tag is a hard runtime error in Flutter.
                final tag = 'poster-$heading-${title.id}';

                return switch (kind) {
                  _RailKind.poster => TitleCard(
                      title: title,
                      heroTag: tag,
                      onTap: () => onTap(title, heroTag: tag),
                    ),
                  _RailKind.wide => WideTitleCard(
                      title: title,
                      heroTag: tag,
                      onTap: () => onTap(title, heroTag: tag),
                    ),
                  _RailKind.ranked => RankedTitleCard(
                      title: title,
                      rank: index + 1,
                      heroTag: tag,
                      onTap: () => onTap(title, heroTag: tag),
                    ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating top bar: wordmark, filter pills and the category chip.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.background,
    required this.active,
    required this.onToggle,
    required this.onCategories,
    required this.onlyShelf,
    required this.onClearShelf,
    required this.demoMode,
    required this.onOpenProfile,
    required this.onSearch,
  });

  /// 0 = fully transparent, 1 = solid. Animated by the scroll offset.
  final double background;

  final Set<String> active;
  final void Function(String key) onToggle;
  final VoidCallback onCategories;
  final String? onlyShelf;
  final VoidCallback onClearShelf;
  final bool demoMode;
  final VoidCallback? onOpenProfile;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Interpolated rather than faded with an opacity layer, so the bar
        // never composites the feed underneath it.
        color: Color.lerp(Colors.transparent, AppColors.background, background),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 8,
            ),
            child: Row(
              children: <Widget>[
                const Wordmark(size: 21),
                if (demoMode) ...<Widget>[
                  const SizedBox(width: 8),
                  const _SampleChip(),
                ],
                const Spacer(),
                _BarIcon(icon: Icons.search_rounded, onTap: onSearch),
                const SizedBox(width: 4),
                if (onOpenProfile != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenProfile,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: ProfileAvatar(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: <Widget>[
                NPill(
                  label: 'TV Shows',
                  selected: active.contains(_kSeries),
                  onTap: () => onToggle(_kSeries),
                ),
                const SizedBox(width: 8),
                NPill(
                  label: 'Movies',
                  selected: active.contains(_kMovies),
                  onTap: () => onToggle(_kMovies),
                ),
                const SizedBox(width: 8),
                NPill(
                  label: 'Categories',
                  trailingIcon: Icons.keyboard_arrow_down_rounded,
                  selected: onlyShelf != null,
                  onTap: onCategories,
                ),
              ],
            ),
          ),
          if (onlyShelf != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClearShelf,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        onlyShelf!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

/// The signed-in avatar. A coloured tile rather than a photo — there is no
/// profile picture to be had from an Xtream panel.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE50914), Color(0xFF7A0A12)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, size: size * 0.6, color: Colors.white),
    );
  }
}

class _SampleChip extends StatelessWidget {
  const _SampleChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Text(
        'SAMPLE',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// The category picker.
class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.shelves, required this.selected});

  final List<String> shelves;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 34,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Text('Categories', style: AppTheme.sectionTitle),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Bounded explicitly instead of `Flexible` + `shrinkWrap`.
          //
          // A `Flexible` child holding a shrink-wrapped ListView inside a
          // min-size Column gives the layout a circular constraint — the
          // Column's height depends on the list, and the list's height depends
          // on the Column. Flutter resolves that by looping forever, which
          // hangs the UI thread hard enough that not even a timer fires.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                _CategoryRow(
                  label: 'All categories',
                  selected: selected == null,
                  onTap: () => Navigator.of(context).pop(_kAllCategories),
                ),
                for (final shelf in shelves)
                  _CategoryRow(
                    label: shelf,
                    selected: selected == shelf,
                    onTap: () => Navigator.of(context).pop(shelf),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected ? AppColors.surfaceHigh : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.accent,
              ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.filter_alt_off_outlined,
            size: 34,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'Nothing in this category',
            style: AppTheme.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Placeholder that mirrors the real layout.
///
/// Built from the same sliver structure as the feed rather than a fixed-height
/// column: the old column was 960 logical pixels tall, which overflowed the
/// ~868 available on a 720x1520 device — so the placeholder for a *loading*
/// screen was itself broken.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 470,
              child: ColoredBox(color: AppColors.surface),
            ),
          ),
          SliverList.builder(
            itemCount: 3,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 15,
                      width: 132,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, __) => Container(
                        width: 116,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry, this.detail});

  final Future<void> Function() onRetry;
  final Object? detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not load the catalogue',
                style: AppTheme.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your connection and try again.',
                style: AppTheme.body,
                textAlign: TextAlign.center,
              ),
              if (detail != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _short(detail!),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              NPrimaryButton(
                label: 'Retry',
                onTap: () => onRetry(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _short(Object error) {
    final text = error.toString();
    return text.length > 180 ? '${text.substring(0, 180)}...' : text;
  }
}
