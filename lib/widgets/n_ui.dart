import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared Netflix-style building blocks.
///
/// Kept in one file so the visual language stays consistent: a screen should
/// reach for these rather than re-deriving button padding or badge metrics.

/// The wordmark. Netflix's logo is a heavy condensed red wordmark with very
/// tight tracking — this reproduces the shape of it without the trademark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'REELHOUSE',
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: size * -0.055,
        height: 1,
        color: AppColors.accent,
      ),
    );
  }
}

/// Full-width red button. The primary action everywhere except playback.
class NPrimaryButton extends StatelessWidget {
  const NPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  /// Optional leading glyph. Sits inside the button rather than beside it, so
  /// the whole width stays tappable.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent : const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: busy
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 22, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// White "Play" button — Netflix inverts to white for playback.
class NPlayButton extends StatelessWidget {
  const NPlayButton({
    super.key,
    required this.onTap,
    this.label = 'Play',
    this.expand = true,
  });

  final VoidCallback onTap;
  final String label;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = _Pressable(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.play_arrow_rounded, size: 26, color: Colors.black),
            const SizedBox(width: 6),
            // Flexible for the same reason as [NSecondaryButton]: this button
            // shares a row with another one, and "Play S12 E24" is long enough
            // to overflow a half-width slot.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Translucent grey button: "My List", "Download", "Rate".
class NSecondaryButton extends StatelessWidget {
  const NSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = _Pressable(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
            ],
            // Flexible + ellipsis rather than a bare Text. In a half-width slot
            // next to another button, a longer label ("My List", "Download")
            // overflows the row outright on a narrow screen or at a large
            // system font scale.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Outlined pill used for the filter row ("TV Shows", "Movies", "Categories").
class NPill extends StatelessWidget {
  const NPill({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.white : const Color(0x59FFFFFF),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.black : AppColors.textPrimary,
              ),
            ),
            if (trailingIcon != null) ...<Widget>[
              const SizedBox(width: 5),
              Icon(
                trailingIcon,
                size: 16,
                color: selected ? Colors.black : AppColors.textPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "98% match" in Netflix green.
class NMatchText extends StatelessWidget {
  const NMatchText({super.key, required this.rating});

  /// 0-10 rating, as Xtream supplies it.
  final double rating;

  @override
  Widget build(BuildContext context) {
    // Xtream ratings are 0-10; Netflix shows a match percentage. Mapping the
    // rating across 5.5-9.5 keeps the useful range legible instead of
    // collapsing everything into 60-90%.
    final percent = ((rating - 5.5) / 4.0).clamp(0.0, 1.0) * 30 + 70;

    return Text(
      '${percent.round()}% match',
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.match,
      ),
    );
  }
}

/// Small bordered age-rating box: [TV-MA], [18], [PG-13].
class NAgeBadge extends StatelessWidget {
  const NAgeBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x80FFFFFF), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Row heading with an optional trailing action.
class NSectionHeader extends StatelessWidget {
  const NSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sectionTitle,
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: <Widget>[
                  Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Scales down slightly while held, so taps register visually on a device
/// where there is no hover state to confirm them.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}
