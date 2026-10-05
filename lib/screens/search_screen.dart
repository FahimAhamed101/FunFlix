import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../models/series.dart';
import '../models/title.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';

/// Search over the catalogue that is already loaded.
///
/// Deliberately local: every title on the home feed is in memory, so matching
/// against it is instant and works with no connection. It also avoids a class
/// of bug that plagues portal clients — panels have no search endpoint, so a
/// server-side search would mean re-downloading the whole catalogue per
/// keystroke.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.movies,
    required this.series,
    required this.onOpen,
  });

  final List<Movie> movies;
  final List<TvSeries> series;

  /// Opens a title. Owned by the caller, so the detail route is pushed on the
  /// same navigator the search screen sits on.
  final void Function(CatalogTitle title, {String? heroTag}) onOpen;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();

  String _text = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<CatalogTitle> get _all => <CatalogTitle>[...widget.movies, ...widget.series];

  List<CatalogTitle> get _results {
    final needle = _text.trim().toLowerCase();
    if (needle.isEmpty) return const <CatalogTitle>[];

    final matches = <CatalogTitle>[
      for (final title in _all)
        if (_matches(title, needle)) title,
    ];

    // Best match first: a title that *starts* with the query beats one that
    // merely contains it, and a highly-rated title beats a poorly-rated one.
    matches.sort((a, b) {
      final aStarts = a.title.toLowerCase().startsWith(needle) ? 0 : 1;
      final bStarts = b.title.toLowerCase().startsWith(needle) ? 0 : 1;
      if (aStarts != bStarts) return aStarts - bStarts;
      return b.rating.compareTo(a.rating);
    });

    return matches.take(60).toList();
  }

  bool _matches(CatalogTitle title, String needle) {
    if (title.title.toLowerCase().contains(needle)) return true;
    for (final genre in title.genres) {
      if (genre.toLowerCase().contains(needle)) return true;
    }
    for (final name in title.cast) {
      if (name.toLowerCase().contains(needle)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final idle = _text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          cursorColor: AppColors.accent,
          decoration: const InputDecoration(
            hintText: 'Search titles, genres, cast',
            hintStyle: TextStyle(fontSize: 16, color: AppColors.textMuted),
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _text = value),
        ),
        actions: <Widget>[
          if (!idle)
            IconButton(
              onPressed: () {
                _query.clear();
                setState(() => _text = '');
              },
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      body: idle
          ? _Suggestions(
              titles: _topRated(_all),
              onOpen: widget.onOpen,
            )
          : results.isEmpty
              ? const _NoMatches()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 180,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final title = results[index];
                    return TitleCard(
                      title: title,
                      width: null,
                      heroTag: 'search-${title.id}',
                      onTap: () => widget.onOpen(
                        title,
                        heroTag: 'search-${title.id}',
                      ),
                    );
                  },
                ),
    );
  }

  static List<CatalogTitle> _topRated(List<CatalogTitle> titles) {
    final sorted = <CatalogTitle>[...titles]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(12).toList();
  }
}

/// What the screen shows before anything is typed.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.titles, required this.onOpen});

  final List<CatalogTitle> titles;
  final void Function(CatalogTitle title, {String? heroTag}) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        const Text('Top searches', style: AppTheme.sectionTitle),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 14,
            mainAxisExtent: 180,
          ),
          itemCount: titles.length,
          itemBuilder: (context, index) {
            final title = titles[index];
            return TitleCard(
              title: title,
              width: null,
              heroTag: 'suggest-${title.id}',
              onTap: () => onOpen(title, heroTag: 'suggest-${title.id}'),
            );
          },
        ),
      ],
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 38,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 14),
            Text(
              'No titles match that',
              style: AppTheme.sectionTitle,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Try a shorter word, or a genre like "drama".',
              style: AppTheme.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
