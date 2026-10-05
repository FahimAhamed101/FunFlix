import 'package:flutter/material.dart';

import '../models/title.dart';
import '../theme/app_theme.dart';

/// Artwork loader with a deterministic fallback.
///
/// Real catalogues are full of dead poster URLs, so the UI must degrade
/// gracefully rather than show a broken box. The fallback colour is derived
/// from the seed, which keeps it stable across rebuilds.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.url,
    required this.seed,
    this.label,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  final String url;
  final String seed;

  /// CatalogTitle used for the fallback monogram.
  ///
  /// Pass the *title*, not the seed. The seed is the numeric stream id, so a
  /// monogram built from it renders as "1" or "2" — which reads as a glitch
  /// rather than as placeholder artwork.
  final String? label;

  final BoxFit fit;

  /// Decode width in physical pixels.
  ///
  /// A rail of 120-pixel tiles holding 4000-pixel posters decodes tens of
  /// megabytes of bitmap for no visible gain, and on a low-memory phone that
  /// is the difference between a smooth scroll and a stutter. Passing this
  /// makes Flutter downscale during decode instead of after.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return PosterFallback(seed: seed, label: label);
      },
      errorBuilder: (context, error, stackTrace) =>
          PosterFallback(seed: seed, label: label),
    );
  }
}

class PosterFallback extends StatelessWidget {
  const PosterFallback({super.key, required this.seed, this.label});

  final String seed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    var hash = 7;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0xFFFFFF;
    }
    final base =
        HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.24, 0.20).toColor();

    return Container(
      color: base,
      alignment: Alignment.center,
      child: Text(
        _monogram(),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white.withAlpha(38),
        ),
      ),
    );
  }

  /// First letter-or-digit of the title, falling back to the seed.
  ///
  /// Titles arrive as "A Beautiful Life", "3:10 to Yuma" and occasionally as
  /// something that starts with punctuation or non-Latin script, so scan for
  /// the first usable character rather than blindly taking `[0]`.
  String _monogram() {
    final match = RegExp(r'[A-Za-z0-9]').firstMatch(label?.trim() ?? '');
    if (match != null) return match.group(0)!.toUpperCase();

    final fromSeed = RegExp(r'[A-Za-z0-9]').firstMatch(seed);
    if (fromSeed != null) return fromSeed.group(0)!.toUpperCase();

    return '?';
  }
}

/// A portrait poster tile.
///
/// Artwork, a small caption, and nothing else — FunFlix's rails are deliberately
/// chrome-free so the artwork carries the row. The caption is kept anyway: a
/// real portal's posters are frequently missing or wrong, and a row of
/// monograms with no names under them is not usable.
class TitleCard extends StatelessWidget {
  const TitleCard({
    super.key,
    required this.title,
    required this.onTap,
    this.width = 116,
    this.heroTag,
  });

  final CatalogTitle title;
  final VoidCallback onTap;

  /// Fixed width in a rail. Pass null to fill the parent instead, which is what
  /// a grid cell needs.
  final double? width;

  /// Unique within a route. A title can appear in "Trending now" and in its own
  /// rail at the same time, so the tag has to include the rail — two heroes
  /// sharing a tag is a hard runtime error in Flutter.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _hero(
                  PosterImage(
                    url: title.posterUrl,
                    seed: title.posterSeed,
                    label: title.title,
                    cacheWidth: width == null ? null : (width! * 2).round(),
                  ),
                ),
                if (title.isSeries)
                  const Positioned(
                    left: 5,
                    top: 5,
                    child: _SeriesBadge(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: width == null ? content : SizedBox(width: width, child: content),
    );
  }

  Widget _hero(Widget child) =>
      heroTag == null ? child : Hero(tag: heroTag!, child: child);
}

/// A poster with a large rank numeral beside it — the "Top 10" treatment.
class RankedTitleCard extends StatelessWidget {
  const RankedTitleCard({
    super.key,
    required this.title,
    required this.rank,
    required this.onTap,
    this.heroTag,
  });

  final CatalogTitle title;
  final int rank;
  final VoidCallback onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 168,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            // The numeral is drawn *behind* the poster's left edge on FunFlix.
            // Faking that with a negative offset keeps the artwork readable
            // while still reading as a chart position.
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 74,
                  height: 0.86,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -6,
                  color: Color(0xFF3D3D3D),
                ),
              ),
            ),
            SizedBox(
              width: 106,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: heroTag == null
                      ? PosterImage(
                          url: title.posterUrl,
                          seed: title.posterSeed,
                          label: title.title,
                          cacheWidth: 212,
                        )
                      : Hero(
                          tag: heroTag!,
                          child: PosterImage(
                            url: title.posterUrl,
                            seed: title.posterSeed,
                            label: title.title,
                            cacheWidth: 212,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A landscape card: 16:9 artwork with the title and match score over it.
///
/// Used for the "Trending now" rail, where the artwork alone is not enough to
/// tell one title from another at a glance.
class WideTitleCard extends StatelessWidget {
  const WideTitleCard({
    super.key,
    required this.title,
    required this.onTap,
    this.width = 232,
    this.heroTag,
  });

  final CatalogTitle title;
  final VoidCallback onTap;

  /// Fixed width in a rail. Null fills the parent, for a full-width list.
  final double? width;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final decodeWidth = width == null ? 720 : (width! * 2).round();

    final art = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PosterImage(
            url: title.backdropUrl,
            seed: title.posterSeed,
            label: title.title,
            cacheWidth: decodeWidth,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x00000000), Color(0xCC000000)],
              ),
            ),
          ),
          const Positioned(left: 7, top: 6, child: _FunFlixF()),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (title.rating > 0) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    title.isSeries
                        ? (title.seasonsLabel ?? 'Series')
                        : '${title.year}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: heroTag == null ? art : Hero(tag: heroTag!, child: art),
        ),
      ),
    );
  }
}
/// The small red "F" FunFlix stamps on the corner of its wide cards.
class _FunFlixF extends StatelessWidget {
  const _FunFlixF();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'F',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        height: 1,
        color: AppColors.accent,
      ),
    );
  }
}

/// Marks a poster as a series rather than a film.
class _SeriesBadge extends StatelessWidget {
  const _SeriesBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0x59FFFFFF), width: 0.5),
      ),
      child: const Text(
        'SERIES',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          height: 1.2,
          color: Colors.white,
        ),
      ),
    );
  }
}
