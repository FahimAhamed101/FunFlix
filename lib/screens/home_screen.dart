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
  _CategorySort _categorySort = _CategorySort.defaultOrder;
  _CategoryFilter _categorySubFilter = _CategoryFilter.all;

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

  List<String> get _shelves {
    final set = <String>{};
    for (final m in widget.movies) {
      final s = m.shelf.trim().isEmpty ? 'More to explore' : m.shelf.trim();
      set.add(s);
    }
    for (final s in widget.series) {
      final sh = s.shelf.trim().isEmpty ? 'More to explore' : s.shelf.trim();
      set.add(sh);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Map<String, int> get _shelfCounts {
    final counts = <String, int>{};
    for (final m in widget.movies) {
      final s = m.shelf.trim().isEmpty ? 'More to explore' : m.shelf.trim();
      counts[s] = (counts[s] ?? 0) + 1;
    }
    for (final s in widget.series) {
      final sh = s.shelf.trim().isEmpty ? 'More to explore' : s.shelf.trim();
      counts[sh] = (counts[sh] ?? 0) + 1;
    }
    return counts;
  }

  bool _matchesShelf(CatalogTitle title, String shelf) {
    final s = title.shelf.trim().isEmpty ? 'More to explore' : title.shelf.trim();
    return s.toLowerCase() == shelf.trim().toLowerCase();
  }

  List<CatalogTitle> _categoryTitles(String shelf) {
    final movies = widget.movies.where((m) => _matchesShelf(m, shelf)).toList();
    final series = widget.series.where((s) => _matchesShelf(s, shelf)).toList();

    var list = switch (_categorySubFilter) {
      _CategoryFilter.all => <CatalogTitle>[...movies, ...series],
      _CategoryFilter.movies => movies,
      _CategoryFilter.series => series,
    };

    switch (_categorySort) {
      case _CategorySort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case _CategorySort.name:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _CategorySort.year:
        list.sort((a, b) => b.year.compareTo(a.year));
      case _CategorySort.defaultOrder:
        break;
    }
    return list;
  }

  void _selectShelf(String? shelf) {
    setState(() {
      _onlyShelf = shelf;
      _categorySubFilter = _CategoryFilter.all;
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

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
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CategorySheet(
        shelves: _shelves,
        shelfCounts: _shelfCounts,
        selected: _onlyShelf,
        totalAllCount: widget.movies.length + widget.series.length,
      ),
    );

    if (!mounted) return;
    if (picked == null) return;
    _selectShelf(picked == _kAllCategories ? null : picked);
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
    final inCategoryMode = _onlyShelf != null;

    final titles = inCategoryMode ? _categoryTitles(_onlyShelf!) : const <CatalogTitle>[];
    final moviesInShelf = inCategoryMode
        ? widget.movies.where((m) => _matchesShelf(m, _onlyShelf!)).length
        : 0;
    final seriesInShelf = inCategoryMode
        ? widget.series.where((s) => _matchesShelf(s, _onlyShelf!)).length
        : 0;

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
                if (!inCategoryMode) ...<Widget>[
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
                ] else ...<Widget>[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 130,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CategoryHeader(
                      shelf: _onlyShelf!,
                      totalCount: moviesInShelf + seriesInShelf,
                      movieCount: moviesInShelf,
                      seriesCount: seriesInShelf,
                      subFilter: _categorySubFilter,
                      onSubFilterChanged: (filter) =>
                          setState(() => _categorySubFilter = filter),
                      sort: _categorySort,
                      onSortChanged: (sort) =>
                          setState(() => _categorySort = sort),
                      onBack: () => _selectShelf(null),
                    ),
                  ),
                  if (titles.isEmpty)
                    SliverToBoxAdapter(
                      child: _CategoryEmptyView(
                        shelf: _onlyShelf!,
                        onReset: () => setState(() {
                          _categorySubFilter = _CategoryFilter.all;
                        }),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 200,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final title = titles[index];
                            final tag = 'category-${_onlyShelf}-${title.id}';
                            return TitleCard(
                              title: title,
                              width: null,
                              heroTag: tag,
                              onTap: () => _open(title, heroTag: tag),
                            );
                          },
                          childCount: titles.length,
                        ),
                      ),
                    ),
                ],
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
                background: inCategoryMode ? 1.0 : t,
                active: _active,
                onToggle: _toggle,
                onCategories: _pickCategory,
                onlyShelf: _onlyShelf,
                onClearShelf: () => _selectShelf(null),
                onSelectShelf: (shelf) => _selectShelf(shelf),
                shelves: _shelves,
                shelfCounts: _shelfCounts,
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
    if (_onlyShelf != null) return const <Widget>[];

    final wantMovies = _active.isEmpty || _active.contains(_kMovies);
    final wantSeries = _active.isEmpty || _active.contains(_kSeries);

    final rails = <Widget>[];

    void add(
      String heading,
      List<CatalogTitle> titles,
      _RailKind kind, {
      VoidCallback? onMore,
    }) {
      if (titles.isEmpty) return;
      rails.add(
        SliverToBoxAdapter(
          child: _Rail(
            heading: heading,
            titles: titles,
            kind: kind,
            onTap: _open,
            onMore: onMore,
          ),
        ),
      );
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
        add(
          'TV Shows · ${shelf.name}',
          shelf.titles,
          _RailKind.poster,
          onMore: () => _selectShelf(shelf.name),
        );
      }
    }
    if (wantMovies) {
      for (final shelf in buildShelves(widget.movies).take(_kMaxMovieRails)) {
        add(
          shelf.name,
          shelf.titles,
          _RailKind.poster,
          onMore: () => _selectShelf(shelf.name),
        );
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
    this.onMore,
  });

  final String heading;
  final List<CatalogTitle> titles;
  final _RailKind kind;
  final void Function(CatalogTitle title, {String? heroTag}) onTap;
  final VoidCallback? onMore;

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
            child: NSectionHeader(
              title: heading,
              actionLabel: onMore != null ? 'See all' : null,
              onAction: onMore,
            ),
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
    required this.onSelectShelf,
    required this.shelves,
    required this.shelfCounts,
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
  final ValueChanged<String> onSelectShelf;
  final List<String> shelves;
  final Map<String, int> shelfCounts;
  final bool demoMode;
  final VoidCallback? onOpenProfile;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: onlyShelf != null
            ? AppColors.background
            : Color.lerp(Colors.transparent, AppColors.background, background),
        border: (onlyShelf != null || background > 0.6)
            ? const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              )
            : null,
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
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: shelves.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = onlyShelf == null;
                  return _CategoryChip(
                    label: 'All',
                    selected: isSelected,
                    onTap: onClearShelf,
                  );
                }
                final shelf = shelves[index - 1];
                final count = shelfCounts[shelf] ?? 0;
                final isSelected = onlyShelf == shelf;
                return _CategoryChip(
                  label: shelf,
                  count: count,
                  selected: isSelected,
                  onTap: () => onSelectShelf(shelf),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
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

enum _CategorySort { defaultOrder, rating, year, name }

enum _CategoryFilter { all, movies, series }

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 0.6,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x66E50914),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x40FFFFFF)
                      : const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.shelf,
    required this.totalCount,
    required this.movieCount,
    required this.seriesCount,
    required this.subFilter,
    required this.onSubFilterChanged,
    required this.sort,
    required this.onSortChanged,
    required this.onBack,
  });

  final String shelf;
  final int totalCount;
  final int movieCount;
  final int seriesCount;
  final _CategoryFilter subFilter;
  final ValueChanged<_CategoryFilter> onSubFilterChanged;
  final _CategorySort sort;
  final ValueChanged<_CategorySort> onSortChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final showTypeTabs = movieCount > 0 && seriesCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      shelf,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalCount titles available',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_CategorySort>(
                initialValue: sort,
                onSelected: onSortChanged,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border, width: 0.5),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.sort_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        switch (sort) {
                          _CategorySort.defaultOrder => 'Default',
                          _CategorySort.rating => 'Rating',
                          _CategorySort.year => 'Year',
                          _CategorySort.name => 'A-Z',
                        },
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _CategorySort.defaultOrder,
                    child: Text('Default Order', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: _CategorySort.rating,
                    child: Text('Highest Rating ★', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: _CategorySort.year,
                    child: Text('Newest Release Year', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: _CategorySort.name,
                    child: Text('Title (A to Z)', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
          if (showTypeTabs) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _SubFilterTab(
                    label: 'All ($totalCount)',
                    selected: subFilter == _CategoryFilter.all,
                    onTap: () => onSubFilterChanged(_CategoryFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _SubFilterTab(
                    label: 'Movies ($movieCount)',
                    selected: subFilter == _CategoryFilter.movies,
                    onTap: () => onSubFilterChanged(_CategoryFilter.movies),
                  ),
                  const SizedBox(width: 8),
                  _SubFilterTab(
                    label: 'TV Shows ($seriesCount)',
                    selected: subFilter == _CategoryFilter.series,
                    onTap: () => onSubFilterChanged(_CategoryFilter.series),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubFilterTab extends StatelessWidget {
  const _SubFilterTab({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategoryEmptyView extends StatelessWidget {
  const _CategoryEmptyView({
    required this.shelf,
    required this.onReset,
  });

  final String shelf;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.filter_alt_off_rounded,
              size: 36,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No titles match this filter in "$shelf"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try switching to All or resetting your filter.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Show all in this category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The category picker sheet with live instant search and item counts.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.shelves,
    required this.shelfCounts,
    required this.selected,
    required this.totalAllCount,
  });

  final List<String> shelves;
  final Map<String, int> shelfCounts;
  final String? selected;
  final int totalAllCount;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.trim().toLowerCase();
    final filtered = needle.isEmpty
        ? widget.shelves
        : widget.shelves
            .where((s) => s.toLowerCase().contains(needle))
            .toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.category_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select Category',
                      style: AppTheme.sectionTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.shelves.length} categories',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _query = val),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  hintStyle: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0x66FFFFFF),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.58,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: <Widget>[
                  if (needle.isEmpty)
                    _CategoryRow(
                      label: 'All categories',
                      count: widget.totalAllCount,
                      selected: widget.selected == null,
                      onTap: () => Navigator.of(context).pop(_kAllCategories),
                    ),
                  for (final shelf in filtered)
                    _CategoryRow(
                      label: shelf,
                      count: widget.shelfCounts[shelf] ?? 0,
                      selected: widget.selected == shelf,
                      onTap: () => Navigator.of(context).pop(shelf),
                    ),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'No categories found',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected ? AppColors.surfaceHigh : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x33E50914)
                    : const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                selected ? Icons.folder_open_rounded : Icons.folder_rounded,
                size: 16,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            if (count != null) ...[
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.accent,
              ),
          ],
        ),
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
