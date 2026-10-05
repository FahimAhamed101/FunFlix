import 'package:flutter/material.dart';

import '../data/movie_repository.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/title.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'live_tv_screen.dart';
import 'movie_detail_screen.dart';
import 'my_netflix_screen.dart';
import 'new_hot_screen.dart';

/// The signed-in shell: four top-level sections, the bar between them, and the
/// catalogue they share.
///
/// The catalogue is loaded *here* rather than in each tab. Three of these tabs
/// show films and series, and `get_vod_streams` on a real panel is tens of
/// megabytes — fetching it once per tab would be the most expensive thing the
/// app does, for no benefit at all.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.repository,
    required this.onSignOut,
    this.demoMode = false,
  });

  final MovieRepository repository;

  /// Leaves the session. Handled by the app shell so the screen can change
  /// before any storage or network work happens.
  final Future<void> Function() onSignOut;

  final bool demoMode;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  /// Tabs that have been opened at least once.
  ///
  /// An [IndexedStack] builds *every* child, so without this the live channel
  /// list and the account record would be fetched on launch even though the
  /// user is looking at the home feed. Once a tab has been visited it stays in
  /// the stack, so its loaded state survives switching back.
  final Set<int> _visited = <int>{0};

  List<Movie> _movies = const <Movie>[];
  List<TvSeries> _series = const <TvSeries>[];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    List<Movie>? movies;
    List<TvSeries>? series;
    Object? failure;

    // Run both in parallel, and catch each independently. A panel with series
    // disabled is still a perfectly usable film catalogue, so a series failure
    // must not blank the whole app — and vice versa.
    await Future.wait<void>(<Future<void>>[
      () async {
        try {
          movies = await widget.repository.fetchMovies();
        } catch (error) {
          failure = error;
        }
      }(),
      () async {
        try {
          series = await widget.repository.fetchSeries();
        } catch (_) {
          // Deliberately swallowed: see above.
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _movies = movies ?? const <Movie>[];
      _series = series ?? const <TvSeries>[];
      _error = movies == null ? failure : null;
      _loading = false;
    });
  }

  void _select(int value) {
    if (value == _index) return;
    setState(() {
      _index = value;
      _visited.add(value);
    });
  }

  void _openProfile() => _select(3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          HomeScreen(
            repository: widget.repository,
            movies: _movies,
            series: _series,
            loading: _loading,
            error: _error,
            onReload: _load,
            demoMode: widget.demoMode,
            onOpenProfile: _openProfile,
          ),
          if (_visited.contains(1))
            NewHotScreen(
              movies: _movies,
              series: _series,
              loading: _loading,
              onOpen: _openTitle,
              onOpenProfile: _openProfile,
            )
          else
            const SizedBox.shrink(),
          if (_visited.contains(2))
            LiveTvScreen(repository: widget.repository)
          else
            const SizedBox.shrink(),
          if (_visited.contains(3))
            MyNetflixScreen(
              repository: widget.repository,
              demoMode: widget.demoMode,
              onSignOut: widget.onSignOut,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: _BottomBar(index: _index, onSelect: _select),
    );
  }

  /// Opens a title from a tab that does not own the detail route.
  ///
  /// Pushed on the shell's navigator so the tab underneath stays put — coming
  /// back from a title returns the user to the tab they opened it from.
  void _openTitle(CatalogTitle title, {String? heroTag}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MovieDetailScreen(
          title: title,
          repository: widget.repository,
          catalogue: <CatalogTitle>[..._movies, ..._series],
          heroTag: heroTag,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: <Widget>[
              _NavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                active: index == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                label: 'New & Hot',
                icon: Icons.local_fire_department_outlined,
                activeIcon: Icons.local_fire_department_rounded,
                active: index == 1,
                onTap: () => onSelect(1),
              ),
              _NavItem(
                label: 'Live TV',
                icon: Icons.live_tv_outlined,
                activeIcon: Icons.live_tv_rounded,
                active: index == 2,
                onTap: () => onSelect(2),
              ),
              _NavItem(
                label: 'My Netflix',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                active: index == 3,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // White rather than the brand red. Netflix keeps red for the wordmark and
    // primary actions; a red bar reads as an error state.
    final colour = active ? AppColors.textPrimary : AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(active ? activeIcon : icon, size: 21, color: colour),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
