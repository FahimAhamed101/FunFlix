import 'package:flutter/material.dart';

import '../data/movie_repository.dart';
import '../models/live_channel.dart';
import '../models/programme.dart';
import '../theme/app_theme.dart';
import '../widgets/n_ui.dart';
import 'player_screen.dart';

/// The live section.
///
/// Channels arrive as one flat list and are grouped here rather than in the
/// data layer, so a portal with no categories at all still works — everything
/// simply lands in a single "All" tab.
class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key, required this.repository});

  final MovieRepository repository;

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  static const String _allTab = 'All';

  final TextEditingController _search = TextEditingController();

  List<LiveChannel>? _channels;
  Object? _error;
  bool _loading = true;
  String _tab = _allTab;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final channels = await widget.repository.fetchLiveChannels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loading = false;
        // A previous tab may not exist on the reloaded list.
        if (_tab != _allTab && !channels.any((c) => c.category == _tab)) {
          _tab = _allTab;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// Tabs in first-seen order, so the portal's own ordering survives.
  List<String> get _tabs {
    final channels = _channels ?? const <LiveChannel>[];
    final seen = <String>[];
    for (final channel in channels) {
      if (!seen.contains(channel.category)) seen.add(channel.category);
    }
    return <String>[_allTab, ...seen];
  }

  List<LiveChannel> get _visible {
    final channels = _channels ?? const <LiveChannel>[];
    final needle = _query.trim().toLowerCase();

    return channels.where((channel) {
      if (_tab != _allTab && channel.category != _tab) return false;
      if (needle.isEmpty) return true;
      return channel.name.toLowerCase().contains(needle) ||
          channel.category.toLowerCase().contains(needle);
    }).toList();
  }

  void _play(LiveChannel channel) {
    final url = channel.streamUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceHigh,
          content: Text(
            '${channel.name} is sample data — connect a portal to watch it.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          title: channel.name,
          subtitle: channel.category,
          streamUrl: url,
          isLive: true,
        ),
      ),
    );
  }

  /// The channel sheet, in the same place films and series get their detail
  /// page — so tapping anything in the app does the same kind of thing.
  void _open(LiveChannel channel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ChannelSheet(
        channel: channel,
        repository: widget.repository,
        onPlay: () {
          Navigator.of(context).pop();
          _play(channel);
        },
      ),
    );
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
            _Header(
              channelCount: _channels?.length,
              controller: _search,
              onQueryChanged: (value) => setState(() => _query = value),
            ),
            if (!_loading && _error == null) ...<Widget>[
              _TabStrip(
                tabs: _tabs,
                selected: _tab,
                onSelect: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 4),
            ],
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _ChannelGridSkeleton();
    if (_error != null) return _LiveError(onRetry: _load);

    final visible = _visible;
    if (visible.isEmpty) {
      final searching = _query.trim().isNotEmpty;
      return _EmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.tv_off_rounded,
        title: searching ? 'No channels match' : 'No live channels',
        body: searching
            ? 'Nothing here matches "$_query". Try a different name.'
            : 'This portal returned no live channels. Movies are still '
                'available on the other tab.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final channel = visible[index];
          return _ChannelTile(
            channel: channel,
            onTap: () => _open(channel),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.channelCount,
    required this.controller,
    required this.onQueryChanged,
  });

  final int? channelCount;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              const Text('Live TV', style: AppTheme.display),
              const SizedBox(width: 10),
              if (channelCount != null && channelCount! > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('$channelCount channels', style: AppTheme.meta),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search channels',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0x66FFFFFF),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
                color: AppColors.textSecondary,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                    ),
              filled: true,
              fillColor: AppColors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 0.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category tabs
// ---------------------------------------------------------------------------

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tabs.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final active = tab == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: active ? AppColors.accent : AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Channel tile
// ---------------------------------------------------------------------------

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.onTap});

  final LiveChannel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: _ChannelLogo(channel: channel)),
                  if (channel.hasArchive)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: _ArchiveBadge(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            channel.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo with a graceful fallback.
///
/// Panels hand back dead logo links often enough that a broken-image icon
/// would be the common case, not the exception — so a failed load silently
/// becomes the channel monogram.
class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel});

  final LiveChannel channel;

  @override
  Widget build(BuildContext context) {
    final url = channel.logoUrl;

    if (url == null || url.isEmpty) {
      return _Monogram(text: channel.initials);
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Monogram(text: channel.initials),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: AppColors.border,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ArchiveBadge extends StatelessWidget {
  const _ArchiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0A0F),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'ARCHIVE',
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Marks audio-only streams — radio stations and music channels that carry no
/// video. Without it a radio station looks broken (a black frame); with it, the
/// sheet says out loud what the user is about to open.
class _AudioBadge extends StatelessWidget {
  const _AudioBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0A0F),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.radio_rounded, size: 9, color: AppColors.textSecondary),
          SizedBox(width: 3),
          Text(
            'AUDIO ONLY',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class _ChannelGridSkeleton extends StatelessWidget {
  const _ChannelGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 38, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(body, style: AppTheme.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _LiveError extends StatelessWidget {
  const _LiveError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              'Could not load channels',
              style: AppTheme.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'The portal did not answer. Check the connection and try again.',
              style: AppTheme.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

// ---------------------------------------------------------------------------
// Channel sheet
// ---------------------------------------------------------------------------

/// What a channel is showing, with the play control above it.
///
/// The guide is fetched here rather than with the channel list: a panel with
/// 200 channels would mean 200 requests for a grid nobody scrolls, and the
/// only question a viewer actually asks is about the one they just tapped.
class _ChannelSheet extends StatefulWidget {
  const _ChannelSheet({
    required this.channel,
    required this.repository,
    required this.onPlay,
  });

  final LiveChannel channel;
  final MovieRepository repository;
  final VoidCallback onPlay;

  @override
  State<_ChannelSheet> createState() => _ChannelSheetState();
}

class _ChannelSheetState extends State<_ChannelSheet> {
  List<Programme>? _programmes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final programmes = await widget.repository.fetchProgrammes(widget.channel);
    if (!mounted) return;
    setState(() => _programmes = programmes);
  }

  @override
  Widget build(BuildContext context) {
    final programmes = _programmes;
    final now = DateTime.now();

    Programme? onAir;
    final upcoming = <Programme>[];
    if (programmes != null) {
      for (final programme in programmes) {
        if (programme.isOnAirAt(now)) {
          onAir ??= programme;
        } else if (upcoming.length < 4) {
          upcoming.add(programme);
        }
      }
    }

    // A guide with no times puts everything "on air"; fall back to the first
    // entry so the slot is never blank.
    final headline = onAir ??
        (programmes == null || programmes.isEmpty ? null : programmes.first);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 84,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _ChannelLogo(channel: widget.channel),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.channel.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.meta,
                        ),
                        if (widget.channel.hasArchive ||
                            widget.channel.audioOnly) ...<Widget>[
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              if (widget.channel.audioOnly)
                                const _AudioBadge(),
                              if (widget.channel.audioOnly &&
                                  widget.channel.hasArchive)
                                const SizedBox(width: 6),
                              if (widget.channel.hasArchive)
                                const _ArchiveBadge(),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: NPrimaryButton(
                  label: 'Watch live',
                  icon: Icons.play_arrow_rounded,
                  onTap: widget.onPlay,
                ),
              ),
              const SizedBox(height: 20),
              if (programmes == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                )
              else if (headline == null)
                const Text(
                  'No programme guide published for this channel.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                )
              else
                _Guide(headline: headline, upcoming: upcoming),
            ],
          ),
        ),
      ),
    );
  }
}

/// "On now" plus the next few slots.
class _Guide extends StatelessWidget {
  const _Guide({required this.headline, required this.upcoming});

  final Programme headline;
  final List<Programme> upcoming;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('ON NOW', style: AppTheme.label),
        const SizedBox(height: 8),
        Text(
          headline.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (headline.description != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            headline.description!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (upcoming.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          const Text('UP NEXT', style: AppTheme.label),
          const SizedBox(height: 8),
          for (final programme in upcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 48,
                    child: Text(
                      programme.slotLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      programme.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
