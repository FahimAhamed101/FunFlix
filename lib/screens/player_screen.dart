import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// Full-screen playback.
///
/// The only thing this widget knows is a URL. It has no idea what produced it,
/// which is what keeps it usable against any source.
///
/// [isLive] only changes the chrome: a live stream has no meaningful duration
/// or seek position, so the scrubber is replaced with a LIVE indicator rather
/// than showing a bar that snaps back to zero.
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

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _initialising = true;
  bool _controlsVisible = true;
  bool _immersive = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    try {
      await controller.initialize();
      await controller.play();
      if (!mounted) {
        await controller.dispose();
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
      if (!mounted) return;
      setState(() {
        _error = error;
        _initialising = false;
      });
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.hasError && _error == null) {
      setState(() => _error = controller.value.errorDescription);
    }
    setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(child: _buildStage()),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
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
      return const SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      );
    }

    final controller = _controller;
    if (_error != null || controller == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not open this stream',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_error ?? 'The player returned no video track.'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Most panels hand back HLS (.m3u8) or MP4. If this is raw '
              'MPEG-TS or MKV, video_player will refuse it — media_kit will not.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio == 0
          ? 16 / 9
          : controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }

  Widget _buildControls() {
    final controller = _controller;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xB3000000),
            Color(0x00000000),
            Color(0xCC000000),
          ],
          stops: <double>[0.0, 0.42, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.subtitle != null)
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
                  ),
                ),
                IconButton(
                  onPressed: _toggleImmersive,
                  icon: Icon(
                    _immersive
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (controller != null) _buildTransport(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildTransport(VideoPlayerController controller) {
    final value = controller.value;

    if (widget.isLive) return _buildLiveTransport(controller, value);

    final position = value.position;
    final duration = value.duration;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: <Widget>[
          _playPause(controller, value.isPlaying),
          Text(
            _clock(position),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: const Color(0x4DFFFFFF),
                thumbColor: AppColors.accent,
              ),
              child: Slider(
                value: position.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble(),
                max: duration.inMilliseconds == 0
                    ? 1
                    : duration.inMilliseconds.toDouble(),
                onChanged: (millis) {
                  controller.seekTo(Duration(milliseconds: millis.round()));
                  _scheduleHide();
                },
              ),
            ),
          ),
          Text(
            _clock(duration),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Live streams get a play/pause and a LIVE pill instead of a scrubber.
  Widget _buildLiveTransport(
    VideoPlayerController controller,
    VideoPlayerValue value,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 10),
      child: Row(
        children: <Widget>[
          _playPause(controller, value.isPlaying),
          const SizedBox(width: 4),
          if (value.isBuffering)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: Colors.white,
                ),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _LiveDot(),
                SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playPause(VideoPlayerController controller, bool isPlaying) {
    return IconButton(
      onPressed: () {
        setState(() {
          if (isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
        _scheduleHide();
      },
      icon: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: 30,
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

/// The pulsing red dot next to "LIVE".
///
/// A plain red dot reads as a recording indicator; the slow pulse is what makes
/// it read as *on air*. It animates on its own so the controls can fade out
/// without freezing it mid-cycle.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
