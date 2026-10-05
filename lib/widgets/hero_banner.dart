import 'package:flutter/material.dart';

import '../models/title.dart';
import '../theme/app_theme.dart';
import 'movie_card.dart';
import 'n_ui.dart';

/// The full-bleed featured panel at the top of the home feed.
///
/// Netflix's hero is mostly artwork: a large still, a scrim heavy enough that
/// white type always reads, and only three pieces of information — what it is,
/// how well it is rated, and the one action worth taking. Everything else is
/// one tap away.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    required this.onPlay,
    required this.onDetails,
  });

  final CatalogTitle title;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PosterImage(
          url: title.backdropUrl,
          seed: title.posterSeed,
          label: title.title,
          fit: BoxFit.cover,
          cacheWidth: 1080,
        ),

        // Two scrims rather than one. The top one exists purely so the
        // translucent app bar's white wordmark stays legible over a bright
        // still; the bottom one carries the type.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xCC000000),
                Color(0x00000000),
                Color(0x33000000),
                Color(0xF2000000),
              ],
              stops: <double>[0.0, 0.28, 0.62, 1.0],
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  title.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display,
                ),
                const SizedBox(height: 10),
                _MetaRow(title: title),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: NPlayButton(onTap: onPlay),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NSecondaryButton(
                        label: 'My List',
                        icon: Icons.add_rounded,
                        onTap: onDetails,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "98% match · 2021 · 4 Seasons · [TV-MA]" — one line, centred.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.title});

  final CatalogTitle title;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (title.rating > 0) '${title.year}',
      if (title.isSeries && title.seasonsLabel != null) title.seasonsLabel!,
      if (!title.isSeries && title.genres.isNotEmpty) title.genres.first,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (title.rating > 0) ...<Widget>[
          NMatchText(rating: title.rating),
          const _Dot(),
        ],
        Flexible(
          child: Text(
            parts.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const NAgeBadge(label: '16+'),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 7),
      child: Text(
        '·',
        style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
      ),
    );
  }
}
