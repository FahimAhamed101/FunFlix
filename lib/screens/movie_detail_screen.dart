import 'package:flutter/material.dart';

import '../data/movie_repository.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/title.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/n_ui.dart';
import 'player_screen.dart';

/// The title page, for a film or a series.
///
/// One screen rather than two, because everything above the fold is identical:
/// the backdrop, the title, the match line, and one Play button. The only
/// branch is below that — a series gets a season picker and an episode list
/// where a film gets its runtime.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.title,
    required this.repository,
    this.catalogue = const <CatalogTitle>[],
    this.heroTag,
  });

  final CatalogTitle title;
  final MovieRepository repository;

  /// Everything already loaded, so "More Like This" needs no request.
  final List<CatalogTitle> catalogue;

  /// Shared-element tag from the card that was tapped, when there was one.
  final String? heroTag;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late CatalogTitle _title = widget.title;

  SeriesDetail? _detail;
  bool _loading = true;
  Object? _error;

  /// Which season's episodes are listed. Series only.
  int _season = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_title.isSeries) {
        final detail = await widget.repository
            .fetchSeriesDetail(_title as TvSeries);
        if (!mounted) return;
        setState(() {
          _detail = detail;
          _title = detail.series;
          _season = detail.seasons.isEmpty ? 1 : detail.seasons.first.number;
          _loading = false;
        });
      } else {
        // The list call only enriches the head of the catalogue, so a title
        // opened from the tail of a large catalogue arrives with no synopsis.
        // One request fills it in.
        final enriched = await widget.repository.fetchMovieDetail(_title as Movie);
        if (!mounted) return;
        setState(() {
          _title = enriched;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _play(String? url, String label) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text(
            'No stream address for "$label". The portal did not supply one.',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(title: label, streamUrl: url),
      ),
    );
  }

  /// What the Play button plays.
  ///
  /// For a series that is the first episode of the season on screen — pressing
  /// Play on a series page has to open *something*, and the first episode is
  /// what a viewer expects.
  ///
  /// Takes the season's episodes rather than recomputing them: `episodesFor`
  /// builds a fresh list, and calling it from the button *and* the list header
  /// *and* every row would rebuild the same list dozens of times per frame.
  (String? url, String label) _playTarget(List<Episode> seasonEpisodes) {
    if (!_title.isSeries) {
      final movie = _title as Movie;
      return (movie.streamUrl, movie.title);
    }

    if (seasonEpisodes.isEmpty) {
      final all = _detail?.episodes ?? const <Episode>[];
      if (all.isEmpty) return (null, _title.title);
      return (all.first.streamUrl, '${_title.title} · ${all.first.title}');
    }
    final first = seasonEpisodes.first;
    return (first.streamUrl, '${_title.title} · ${first.title}');
  }

  void _openOther(CatalogTitle other) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MovieDetailScreen(
          title: other,
          repository: widget.repository,
          catalogue: widget.catalogue,
        ),
      ),
    );
  }

  /// Titles sharing at least one genre with this one.
  List<CatalogTitle> _similarTitles() {
    final mine = _title.genres.map((g) => g.toLowerCase()).toSet();
    if (mine.isEmpty) return const <CatalogTitle>[];

    final matches = <CatalogTitle>[
      for (final other in widget.catalogue)
        if (other.id != _title.id &&
            other.genres.any((g) => mine.contains(g.toLowerCase())))
          other,
    ];
    matches.sort((a, b) => b.rating.compareTo(a.rating));
    return matches.take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Computed once and threaded through, rather than rebuilt per row. Both of
    // these walk the whole catalogue, and the grid asked for them once per cell.
    final seasonEpisodes =
        _detail?.episodesFor(_season) ?? const <Episode>[];
    final similar = _similarTitles();
    final target = _playTarget(seasonEpisodes);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: <Widget>[
          _BackdropAppBar(title: _title, heroTag: widget.heroTag),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_title.title, style: AppTheme.display),
                  const SizedBox(height: 10),
                  _MetaLine(title: _title),
                  const SizedBox(height: 16),
                  NPlayButton(
                    label: _title.isSeries ? 'Play S$_season E1' : 'Play',
                    onTap: () => _play(target.$1, target.$2),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const _InlineLoading()
                  else if (_error != null)
                    _InlineError(error: _error!, onRetry: _load)
                  else ...<Widget>[
                    if (_title.synopsis.trim().isNotEmpty)
                      Text(
                        _title.synopsis.trim(),
                        style: AppTheme.body,
                      ),
                    if (_title.genres.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _FactLine(
                        label: 'Genres',
                        value: _title.genres.join(', '),
                      ),
                    ],
                    if (_title.cast.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _FactLine(
                        label: 'Cast',
                        value: _title.cast.take(8).join(', '),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          if (_title.isSeries && _detail != null) ...<Widget>[
            SliverToBoxAdapter(
              child: _EpisodesHeader(
                detail: _detail!,
                season: _season,
                onPick: _pickSeason,
              ),
            ),
            SliverList.builder(
              itemCount: seasonEpisodes.length,
              itemBuilder: (context, index) {
                final episode = seasonEpisodes[index];
                return _EpisodeRow(
                  episode: episode,
                  onTap: () => _play(
                    episode.streamUrl,
                    '${_title.title} · ${episode.title}',
                  ),
                );
              },
            ),
          ],

          if (similar.isNotEmpty) ...<Widget>[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: NSectionHeader(title: 'More Like This'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 200,
                ),
                itemCount: similar.length,
                itemBuilder: (context, index) {
                  final other = similar[index];
                  return TitleCard(
                    title: other,
                    width: null,
                    onTap: () => _openOther(other),
                  );
                },
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Future<void> _pickSeason() async {
    final detail = _detail;
    if (detail == null) return;

    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _SeasonSheet(
        seasons: detail.seasons,
        selected: _season,
      ),
    );

    if (!mounted || picked == null) return;
    setState(() => _season = picked);
  }
}

/// The backdrop header, with a circular back button floating over it.
class _BackdropAppBar extends StatelessWidget {
  const _BackdropAppBar({required this.title, this.heroTag});

  final CatalogTitle title;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final art = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PosterImage(
          url: title.backdropUrl,
          seed: title.posterSeed,
          label: title.title,
          fit: BoxFit.cover,
          cacheWidth: 1080,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x99000000),
                Color(0x00000000),
                Color(0x66000000),
                AppColors.background,
              ],
              stops: <double>[0.0, 0.32, 0.72, 1.0],
            ),
          ),
        ),
      ],
    );

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Center(
          child: _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: heroTag == null ? art : Hero(tag: heroTag!, child: art),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0x99000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

/// "98% match  2021  ·  4 Seasons  ·  [16+]"
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.title});

  final CatalogTitle title;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '${title.year}',
      if (title.isSeries && title.seasonsLabel != null) title.seasonsLabel!,
      if (!title.isSeries) (title as Movie).runtimeLabel,
      if (title.genres.isNotEmpty) title.genres.first,
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: <Widget>[
        if (title.rating > 0) NMatchText(rating: title.rating),
        Text(
          parts.join('  ·  '),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const NAgeBadge(label: '16+'),
      ],
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.45),
        children: <TextSpan>[
          TextSpan(
            text: '$label  ',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// "Season 2 ▾" plus the episode count — the season picker.
class _EpisodesHeader extends StatelessWidget {
  const _EpisodesHeader({
    required this.detail,
    required this.season,
    required this.onPick,
  });

  final SeriesDetail detail;
  final int season;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    // Not `firstOrNull` — that lives in package:collection, and this file does
    // not need the dependency for one lookup.
    Season? current;
    for (final candidate in detail.seasons) {
      if (candidate.number == season) {
        current = candidate;
        break;
      }
    }
    final count = detail.episodesFor(season).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPick,
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    current?.displayName ?? 'Season $season',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sectionTitle,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == 1 ? '1 episode' : '$count episodes',
            style: AppTheme.meta,
          ),
          if (current != null && current.overview.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              current.overview.trim(),
              style: AppTheme.body,
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of the episode list: still, code, title, runtime.
class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.onTap});

  final Episode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final playable = episode.streamUrl != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 128,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: <Widget>[
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: PosterImage(
                        url: episode.stillUrl,
                        seed: episode.id,
                        label: episode.title,
                        cacheWidth: 320,
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x33000000)),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xCC000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!playable)
                        const Icon(
                          Icons.link_off_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Text(
                        episode.code,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(episode.runtimeLabel, style: AppTheme.meta),
                    ],
                  ),
                  if (episode.synopsis.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      episode.synopsis.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The season picker sheet.
class _SeasonSheet extends StatelessWidget {
  const _SeasonSheet({required this.seasons, required this.selected});

  final List<Season> seasons;
  final int selected;

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
                Text('Select a season', style: AppTheme.sectionTitle),
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
          // hangs the UI thread hard enough that not even a timer fires. A
          // plain ConstrainedBox removes the cycle: the cap is known up front,
          // and the list sizes itself underneath it.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                for (final season in seasons)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(season.number),
                    child: Container(
                      color: season.number == selected
                          ? AppColors.surfaceHigh
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              season.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: season.number == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${season.episodeCount} ep',
                            style: AppTheme.meta,
                          ),
                          if (season.number == selected) ...<Widget>[
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(width: 10),
          Text('Loading details...', style: AppTheme.meta),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'The portal did not return the details for this title.',
          style: AppTheme.body,
        ),
        const SizedBox(height: 10),
        NSecondaryButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          expand: false,
          onTap: onRetry,
        ),
      ],
    );
  }
}
