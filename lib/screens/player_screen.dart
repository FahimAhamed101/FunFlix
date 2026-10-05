import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/video_cache_manager.dart';
import '../theme/app_theme.dart';

enum VideoFitMode { contain, cover, sixteenNine }

/// High-fidelity, smooth full-screen video player for Movies and Live TV.
///
/// Features:
///   * Multi-layer YouTube-style scrubber showing downloaded / cached buffer ahead
///   * Double-tap left/right to seek ±10 seconds with ripple animations
///   * Center playback transport (Replay 10s, Play/Pause, Forward 10s)
///   * Real-time buffering and cache diagnostics
///   * Aspect ratio modes (Fit, Zoom to Fill, 16:9)
///   * Playback speed selector (0.75x to 2.0x)
///   * Live TV latency and stream reconnect logic
///   * Automatic video cache purging and decoder release on close
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    this.subtitle,
    this.isLive = false,
  });

  final String title;
  final String? subtitle;
  final String streamUrl;
  final bool isLive;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Object? _error;
  bool _initialising = true;
  bool _controlsVisible = true;
  bool _immersive = false;
  bool _isClosing = false;
  VideoFitMode _fitMode = VideoFitMode.contain;
  double _speed = 1.0;
  Timer? _hideTimer;

  // Double-tap seek animation state
  bool _showLeftSeekRipple = false;
  bool _showRightSeekRipple = false;
  Timer? _leftSeekTimer;
  Timer? _rightSeekTimer;

  // Dragging / scrubbing state
  bool _isScrubbing = false;
  Duration _scrubPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app is minimized or the screen is turned off, immediately pause
    // the video decoder so the device CPU and other applications run smoothly.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller?.pause();
    }
  }

  /// Synchronously halts playback, restores system UI, exits cleanly,
  /// and purges player cache files and RAM in the background.
  void _handleClose() {
    if (_isClosing) return;
    _isClosing = true;

    // 1. Cancel timers to halt UI scheduling
    _hideTimer?.cancel();
    _leftSeekTimer?.cancel();
    _rightSeekTimer?.cancel();

    // 2. Immediately stop audio & video playback
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        controller.removeListener(_onTick);
        controller.pause();
      } catch (_) {}
    }

    // 3. Restore system bars and orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);

    // 4. Pop player route smoothly
    if (mounted) {
      Navigator.of(context).pop();
    }

    // 5. Clean up hardware decoder and delete temporary video cache files
    unawaited(() async {
      try {
        await controller?.dispose();
      } catch (_) {}
      await VideoCacheManager.instance.clearPlayerCache();
    }());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _leftSeekTimer?.cancel();
    _rightSeekTimer?.cancel();

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        controller.removeListener(_onTick);
        controller.pause();
      } catch (_) {}
      unawaited(() async {
        try {
          await controller.dispose();
        } catch (_) {}
        await VideoCacheManager.instance.clearPlayerCache();
      }());
    } else if (!_isClosing) {
      unawaited(VideoCacheManager.instance.clearPlayerCache());
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _initialising = true;
      _error = null;
    });

    final previous = _controller;
    _controller = null;
    if (previous != null) {
      try {
        previous.removeListener(_onTick);
        await previous.pause();
      } catch (_) {}
      await previous.dispose();
      unawaited(VideoCacheManager.instance.clearPlayerCache());
    }

    // Standard desktop browser User-Agent ensures IPTV CDN / panel servers
    // do not rate-limit or throttle chunk downloading.
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
      httpHeaders: const <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': '*/*',
      },
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    try {
      await controller.initialize();
      await controller.play();
      if (!mounted || _isClosing) {
        await controller.dispose();
        unawaited(VideoCacheManager.instance.clearPlayerCache());
        return;
      }
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _initialising = false;
      });
      _scheduleHide();
    } catch (error) {
      await controller.dispose();
      unawaited(VideoCacheManager.instance.clearPlayerCache());
      if (!mounted || _isClosing) return;
      setState(() {
        _error = error;
        _initialising = false;
      });
    }
  }

  void _onTick() {
    if (_isClosing) return;
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.hasError && _error == null) {
      setState(() => _error = controller.value.errorDescription);
    }
    if (mounted && !_isClosing) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_isClosing) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isScrubbing && !_isClosing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  Future<void> _toggleImmersive() async {
    final next = !_immersive;
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    await SystemChrome.setPreferredOrientations(
      next
          ? const <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : DeviceOrientation.values,
    );
    setState(() => _immersive = next);
  }

  void _seekBy(int seconds) {
    final controller = _controller;
    if (controller == null || widget.isLive) return;

    final current = controller.value.position;
    final total = controller.value.duration;
    final target = current + Duration(seconds: seconds);
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, total.inMilliseconds),
    );

    controller.seekTo(clamped);
    HapticFeedback.lightImpact();
    _scheduleHide();
  }

  void _triggerDoubleTapSeek(bool isForward) {
    if (widget.isLive) return;

    if (isForward) {
      _seekBy(10);
      setState(() => _showRightSeekRipple = true);
      _rightSeekTimer?.cancel();
      _rightSeekTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showRightSeekRipple = false);
      });
    } else {
      _seekBy(-10);
      setState(() => _showLeftSeekRipple = true);
      _leftSeekTimer?.cancel();
      _leftSeekTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showLeftSeekRipple = false);
      });
    }
  }

  void _cycleFitMode() {
    setState(() {
      _fitMode = switch (_fitMode) {
        VideoFitMode.contain => VideoFitMode.cover,
        VideoFitMode.cover => VideoFitMode.sixteenNine,
        VideoFitMode.sixteenNine => VideoFitMode.contain,
      };
    });
    HapticFeedback.selectionClick();
    _scheduleHide();
  }

  void _showSpeedPicker() {
    _hideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Playback Speed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Divider(color: Color(0xFF282834), height: 1),
              for (final s in <double>[0.75, 1.0, 1.25, 1.5, 2.0])
                ListTile(
                  title: Text(
                    s == 1.0 ? '1.0x (Normal)' : '${s}x',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                          _speed == s ? FontWeight.w700 : FontWeight.w500,
                      color: _speed == s ? AppColors.accent : Colors.white,
                    ),
                  ),
                  trailing: _speed == s
                      ? const Icon(Icons.check_rounded, color: AppColors.accent)
                      : null,
                  onTap: () {
                    setState(() => _speed = s);
                    _controller?.setPlaybackSpeed(s);
                    Navigator.of(context).pop();
                    _scheduleHide();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Video Canvas
            Center(child: _buildStage()),

            // Gesture Detector for Double-Tap Seek & Controls Toggle
            Positioned.fill(
              child: Row(
                children: <Widget>[
                  // Left 50% screen (Seek -10s on double tap)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleControls,
                      onDoubleTap: () => _triggerDoubleTapSeek(false),
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: _showLeftSeekRipple
                            ? const _SeekRipple(seconds: -10, isForward: false)
                            : null,
                      ),
                    ),
                  ),
                  // Right 50% screen (Seek +10s on double tap)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleControls,
                      onDoubleTap: () => _triggerDoubleTapSeek(true),
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: _showRightSeekRipple
                            ? const _SeekRipple(seconds: 10, isForward: true)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Buffering & Caching Indicator Overlay
            if (_controller != null &&
                _controller!.value.isBuffering &&
                !_initialising &&
                _error == null &&
                !_isClosing)
              const Center(child: _BufferingGlowIndicator()),

            // Full Player Controls Overlay
            AnimatedOpacity(
              opacity: (_controlsVisible && !_isClosing) ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible || _isClosing,
                child: _buildControls(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStage() {
    if (_initialising) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accent,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Buffering stream...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    final controller = _controller;
    if (_error != null || controller == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x33E50914),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not open this stream',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_error ?? 'The stream returned no playable video data.'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _handleClose,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry Playback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final rawRatio = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return switch (_fitMode) {
      VideoFitMode.contain => AspectRatio(
          aspectRatio: rawRatio,
          child: VideoPlayer(controller),
        ),
      VideoFitMode.cover => SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      VideoFitMode.sixteenNine => const AspectRatio(
          aspectRatio: 16 / 9,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.shrink(),
          ),
        ),
    };
  }

  Widget _buildControls() {
    final controller = _controller;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xCC000000),
            Colors.transparent,
            Color(0xF0000000),
          ],
          stops: <double>[0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Back',
                    onPressed: _handleClose,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xB3FFFFFF),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Aspect Ratio Mode Switcher
                  IconButton(
                    tooltip: 'Aspect Ratio: ${_fitMode.name}',
                    onPressed: _cycleFitMode,
                    icon: Icon(
                      _fitMode == VideoFitMode.cover
                          ? Icons.fit_screen_rounded
                          : Icons.aspect_ratio_rounded,
                      color: _fitMode != VideoFitMode.contain
                          ? AppColors.accent
                          : Colors.white,
                      size: 22,
                    ),
                  ),

                  // Playback Speed Button (VOD only)
                  if (!widget.isLive)
                    IconButton(
                      tooltip: 'Speed (${_speed}x)',
                      onPressed: _showSpeedPicker,
                      icon: const Icon(
                        Icons.speed_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),

                  // Fullscreen Orientation Toggle
                  IconButton(
                    tooltip: 'Toggle Fullscreen',
                    onPressed: _toggleImmersive,
                    icon: Icon(
                      _immersive
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Center Play / Pause & Quick Seek Transport
            Expanded(
              child: controller == null
                  ? const SizedBox.shrink()
                  : Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          // Replay 10s
                          if (!widget.isLive) ...[
                            _TransportCircleButton(
                              icon: Icons.replay_10_rounded,
                              size: 46,
                              onTap: () => _triggerDoubleTapSeek(false),
                            ),
                            const SizedBox(width: 32),
                          ],

                          // Big Center Play / Pause
                          _TransportCircleButton(
                            icon: controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 64,
                            isPrimary: true,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (controller.value.isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
                              });
                              _scheduleHide();
                            },
                          ),

                          // Forward 10s
                          if (!widget.isLive) ...[
                            const SizedBox(width: 32),
                            _TransportCircleButton(
                              icon: Icons.forward_10_rounded,
                              size: 46,
                              onTap: () => _triggerDoubleTapSeek(true),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),

            // Bottom Transport Bar (YouTube-style buffer bar for VOD, Live controls for TV)
            if (controller != null)
              widget.isLive
                  ? _buildLiveBottomBar(controller)
                  : _buildVodBottomBar(controller),
          ],
        ),
      ),
    );
  }

  /// YouTube-style multi-layer scrubber bar showing total length, downloaded/cached
  /// buffer ranges, played progress, and floating timestamp preview.
  Widget _buildVodBottomBar(VideoPlayerController controller) {
    final value = controller.value;
    final duration = value.duration;
    final currentPos = _isScrubbing ? _scrubPosition : value.position;

    // Calculate buffer health (cached seconds ahead of current playback)
    int cachedAheadSec = 0;
    for (final range in value.buffered) {
      if (range.start <= currentPos && range.end >= currentPos) {
        cachedAheadSec = (range.end - currentPos).inSeconds;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Timestamp & Buffer Diagnostics Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${_clock(currentPos)} / ${_clock(duration)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (cachedAheadSec > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.cloud_download_rounded,
                        size: 11,
                        color: Color(0xFFB0B0B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cached ${cachedAheadSec}s ahead',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE0E0E6),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Custom Multi-Layer YouTube Progress Bar
          _YouTubeProgressBar(
            controller: controller,
            isScrubbing: _isScrubbing,
            scrubPosition: _scrubPosition,
            onSeekStart: () {
              setState(() {
                _isScrubbing = true;
                _scrubPosition = controller.value.position;
              });
              _hideTimer?.cancel();
            },
            onSeekChanged: (pos) {
              setState(() => _scrubPosition = pos);
            },
            onSeekEnd: (pos) {
              setState(() => _isScrubbing = false);
              controller.seekTo(pos);
              HapticFeedback.lightImpact();
              _scheduleHide();
            },
          ),
        ],
      ),
    );
  }

  /// Live TV transport controls with pulsing LIVE badge and buffer status.
  Widget _buildLiveBottomBar(VideoPlayerController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: <Widget>[
          // Pulsing LIVE Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x33E50914),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _LiveDot(),
                SizedBox(width: 6),
                Text(
                  'LIVE STREAM',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Stream Health
          const Expanded(
            child: Text(
              'Low latency stream · Auto-cached',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xB3FFFFFF),
              ),
            ),
          ),

          // Stream Reconnect / Refresh Button
          IconButton(
            tooltip: 'Sync / Reload Live Stream',
            icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              _open();
            },
          ),
        ],
      ),
    );
  }

  String _clock(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

// -----------------------------------------------------------------------------
// YouTube-style Multi-Layer Scrubber Bar
// -----------------------------------------------------------------------------

class _YouTubeProgressBar extends StatelessWidget {
  const _YouTubeProgressBar({
    required this.controller,
    required this.isScrubbing,
    required this.scrubPosition,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final VideoPlayerController controller;
  final bool isScrubbing;
  final Duration scrubPosition;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeekChanged;
  final ValueChanged<Duration> onSeekEnd;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final totalDuration = value.duration;
    final totalMs = totalDuration.inMilliseconds == 0
        ? 1
        : totalDuration.inMilliseconds;
    final currentPos = isScrubbing ? scrubPosition : value.position;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;

        Duration positionFromOffset(double dx) {
          final ratio = (dx / barWidth).clamp(0.0, 1.0);
          return Duration(milliseconds: (ratio * totalMs).round());
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            onSeekStart();
            onSeekChanged(positionFromOffset(details.localPosition.dx));
          },
          onHorizontalDragUpdate: (details) {
            onSeekChanged(positionFromOffset(details.localPosition.dx));
          },
          onHorizontalDragEnd: (_) {
            onSeekEnd(scrubPosition);
          },
          onTapDown: (details) {
            onSeekStart();
            final target = positionFromOffset(details.localPosition.dx);
            onSeekChanged(target);
            onSeekEnd(target);
          },
          child: Container(
            height: 28,
            alignment: Alignment.center,
            child: CustomPaint(
              size: Size(barWidth, 24),
              painter: _YouTubeTrackPainter(
                totalDuration: totalDuration,
                currentPosition: currentPos,
                bufferedRanges: value.buffered,
                isScrubbing: isScrubbing,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _YouTubeTrackPainter extends CustomPainter {
  const _YouTubeTrackPainter({
    required this.totalDuration,
    required this.currentPosition,
    required this.bufferedRanges,
    required this.isScrubbing,
  });

  final Duration totalDuration;
  final Duration currentPosition;
  final List<DurationRange> bufferedRanges;
  final bool isScrubbing;

  @override
  void paint(Canvas canvas, Size size) {
    final totalMs = totalDuration.inMilliseconds == 0
        ? 1
        : totalDuration.inMilliseconds;
    final centerY = size.height / 2;
    const trackHeight = 3.5;

    // 1. Dark background line (total video length)
    final bgPaint = Paint()
      ..color = const Color(0x38FFFFFF)
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      bgPaint,
    );

    // 2. YouTube-style Downloaded / Cached Buffer Lines
    // Renders the exact chunks downloaded into memory by ExoPlayer
    final bufferPaint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;

    for (final range in bufferedRanges) {
      final startRatio =
          (range.start.inMilliseconds / totalMs).clamp(0.0, 1.0);
      final endRatio = (range.end.inMilliseconds / totalMs).clamp(0.0, 1.0);

      if (endRatio > startRatio) {
        canvas.drawLine(
          Offset(size.width * startRatio, centerY),
          Offset(size.width * endRatio, centerY),
          bufferPaint,
        );
      }
    }

    // 3. Played progress line (vibrant red)
    final playedRatio =
        (currentPosition.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final playedPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = trackHeight + 0.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width * playedRatio, centerY),
      playedPaint,
    );

    // 4. Scrubber Thumb
    final thumbX = size.width * playedRatio;
    final thumbRadius = isScrubbing ? 7.5 : 5.5;

    // Outer red thumb
    final thumbPaint = Paint()..color = AppColors.accent;
    canvas.drawCircle(Offset(thumbX, centerY), thumbRadius, thumbPaint);

    // Inner white dot when scrubbing
    if (isScrubbing) {
      final innerPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(thumbX, centerY), 3.0, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _YouTubeTrackPainter oldDelegate) {
    return oldDelegate.totalDuration != totalDuration ||
        oldDelegate.currentPosition != currentPosition ||
        oldDelegate.bufferedRanges != bufferedRanges ||
        oldDelegate.isScrubbing != isScrubbing;
  }
}

// -----------------------------------------------------------------------------
// Transport Controls & Animations
// -----------------------------------------------------------------------------

class _TransportCircleButton extends StatelessWidget {
  const _TransportCircleButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPrimary ? AppColors.accent : const Color(0x38FFFFFF),
            boxShadow: isPrimary
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x59E50914),
                      blurRadius: 16,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: size * 0.55,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Double-tap seek ripple animation (YouTube style)
class _SeekRipple extends StatelessWidget {
  const _SeekRipple({required this.seconds, required this.isForward});

  final int seconds;
  final bool isForward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33FFFFFF), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!isForward) ...[
            const Icon(Icons.fast_rewind_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 6),
          ],
          Text(
            '${isForward ? '+' : ''}$seconds seconds',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (isForward) ...[
            const SizedBox(width: 6),
            const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 24),
          ],
        ],
      ),
    );
  }
}

/// Buffering glowing indicator in the center of the stage
class _BufferingGlowIndicator extends StatelessWidget {
  const _BufferingGlowIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF), width: 0.8),
      ),
      child: const SizedBox(
        width: 38,
        height: 38,
        child: CircularProgressIndicator(
          strokeWidth: 2.8,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// Pulsing red indicator next to LIVE
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
