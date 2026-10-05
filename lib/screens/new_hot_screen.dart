import 'package:flutter/material.dart';

import '../data/movie_repository.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/title.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/n_ui.dart';
import 'home_screen.dart' show ProfileAvatar;

/// "New & Hot" — what is new, what is popular, and what is actually charting.
///
/// Everything on this tab is derived from the same catalogue the home feed
/// uses; nothing extra is requested from the portal. That matters because
/// Xtream has no notion of a chart or a release calendar — the honest way to
/// build this screen is to rank what the panel actually gave us.
class NewHotScreen extends StatefulWidget {
  const NewHotScreen({
    super.key,
    required this.movies,
    required this.series,
    required this.loading,
    required this.onOpen,
    this.onOpenProfile,
  });

  final List<Movie> movies;
  final List<TvSeries> series;
  final bool loading;
  final void Function(CatalogTitle title, {String? heroTag}) onOpen;
  final VoidCallback? onOpenProfile;

  @override
  State<NewHotScreen> createState() => _NewHotScreenState();
}

class _NewHotScreenState extends State<NewHotScreen> {
  int _tab = 0;

  List<CatalogTitle> get _all => <CatalogTitle>[...widget.movies, ...widget.series];

  /// Most recently added first.
  ///
  /// Titles with no date go last rather than first: a null means the panel did
  /// not say, and "unknown" should not outrank "yesterday".
  List<CatalogTitle> get _newest {
    final sorted = <CatalogTitle>[..._all];
    sorted.sort((a, b) {
      final aDate = a.addedAt;
      final bDate = b.addedAt;
      if (aDate == null && bDate == null) return b.rating.compareTo(a.rating);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sorted.take(24).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: <Widget>[
                  const Text('New & Hot', style: AppTheme.display),
                  const Spacer(),
                  if (widget.onOpenProfile != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onOpenProfile,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: ProfileAvatar(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: <Widget>[
                  NPill(
                    label: "Everyone's Watching",
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  NPill(
                    label: 'Top 10',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 8),
                  NPill(
                    label: 'New',
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (widget.loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }

    if (_all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nothing to show yet.',
            style: AppTheme.body,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    switch (_tab) {
      case 1:
        return _topTen();
      case 2:
        return _newGrid();
      default:
        return _everyone();
    }
  }

  /// A single column of full-width landscape cards, the way FunFlix presents
  /// "Everyone's Watching".
  Widget _everyone() {
    final titles = trendingTitles(_all, limit: 12);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: titles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final title = titles[index];
        final tag = 'newhot-everyone-${title.id}';
        return WideTitleCard(
          title: title,
          width: null,
          heroTag: tag,
          onTap: () => widget.onOpen(title, heroTag: tag),
        );
      },
    );
  }

  Widget _topTen() {
    final movieTop = trendingTitles(widget.movies, limit: 10);
    final seriesTop = trendingTitles(widget.series, limit: 10);

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: <Widget>[
        if (seriesTop.isNotEmpty) ...<Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: NSectionHeader(title: 'Top 10 in TV Shows Today'),
          ),
          const SizedBox(height: 10),
          _RankedRow(
            titles: seriesTop,
            tagPrefix: 'newhot-top-tv',
            onOpen: widget.onOpen,
          ),
        ],
        if (movieTop.isNotEmpty) ...<Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 28, 16, 0),
            child: NSectionHeader(title: 'Top 10 in Movies Today'),
          ),
          const SizedBox(height: 10),
          _RankedRow(
            titles: movieTop,
            tagPrefix: 'newhot-top-movie',
            onOpen: widget.onOpen,
          ),
        ],
      ],
    );
  }

  Widget _newGrid() {
    final titles = _newest;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 14,
        mainAxisExtent: 180,
      ),
      itemCount: titles.length,
      itemBuilder: (context, index) {
        final title = titles[index];
        final tag = 'newhot-new-${title.id}';
        return TitleCard(
          title: title,
          width: null,
          heroTag: tag,
          onTap: () => widget.onOpen(title, heroTag: tag),
        );
      },
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.titles,
    required this.tagPrefix,
    required this.onOpen,
  });

  final List<CatalogTitle> titles;
  final String tagPrefix;
  final void Function(CatalogTitle title, {String? heroTag}) onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: titles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final title = titles[index];
          final tag = '$tagPrefix-${title.id}';
          return RankedTitleCard(
            title: title,
            rank: index + 1,
            heroTag: tag,
            onTap: () => onOpen(title, heroTag: tag),
          );
        },
      ),
    );
  }
}
