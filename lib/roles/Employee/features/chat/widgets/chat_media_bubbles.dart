import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../../core/constants/app_size.dart';
import '../../../../../core/theme/app_color.dart';

// ─── Image bubble ─────────────────────────────────────────────────────────────

class ChatImageBubble extends StatelessWidget {
  const ChatImageBubble({
    super.key,
    required this.mediaUrl,
    required this.isMine,
  });

  final String mediaUrl;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.r16),
        child: CachedNetworkImage(
          imageUrl: mediaUrl,
          width: AppSizes.w240,
          height: AppSizes.h200,
          fit: BoxFit.cover,
          placeholder: (ctx, url) => Container(
            width: AppSizes.w240,
            height: AppSizes.h200,
            color: isMine
                ? AppColors.gradientEnd.withValues(alpha: 0.4)
                : context.colors.cardBackground,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryColor,
              ),
            ),
          ),
          errorWidget: (ctx, url, err) => Container(
            width: AppSizes.w240,
            height: AppSizes.h200,
            color: context.colors.cardBackground,
            child: Icon(
              LucideIcons.imageOff,
              color: Colors.white,
              size: AppSizes.sp32,
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImagePage(imageUrl: mediaUrl),
      ),
    );
  }
}

class _FullScreenImagePage extends StatelessWidget {
  const _FullScreenImagePage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (ctx, url) => const CircularProgressIndicator(
              color: AppColors.primaryColor,
            ),
            errorWidget: (ctx, url, err) => Icon(
              LucideIcons.imageOff,
              color: Colors.white,
              size: AppSizes.sp64,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Video bubble ─────────────────────────────────────────────────────────────

class ChatVideoBubble extends StatelessWidget {
  const ChatVideoBubble({
    super.key,
    required this.mediaUrl,
    required this.isMine,
    this.mediaDuration,
  });

  final String mediaUrl;
  final bool isMine;
  final int? mediaDuration;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPlayer(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.r16),
        child: Stack(
          children: [
            Container(
              width: AppSizes.w240,
              height: AppSizes.h200,
              color: isMine
                  ? AppColors.gradientEnd.withValues(alpha: 0.35)
                  : context.colors.cardBackground,
              child: Center(
                child: Icon(
                  LucideIcons.video,
                  color: Colors.white,
                  size: AppSizes.sp64,
                ),
              ),
            ),
            // Play button overlay
            Positioned.fill(
              child: Center(
                child: Container(
                  width: AppSizes.h48,
                  height: AppSizes.h48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: AppSizes.sp32,
                  ),
                ),
              ),
            ),
            // Duration badge
            if (mediaDuration != null)
              Positioned(
                bottom: AppSizes.h8,
                right: AppSizes.w8,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.pw6,
                    vertical: AppSizes.ph4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppSizes.r6),
                  ),
                  child: Text(
                    _formatDuration(mediaDuration!),
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: AppSizes.sp10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenVideoPage(videoUrl: mediaUrl),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  const _FullScreenVideoPage({required this.videoUrl});

  final String videoUrl;

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.play();
      }
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child: _isInitialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (_showControls) _buildControls(),
                  ],
                )
              : const CircularProgressIndicator(
                  color: AppColors.primaryColor,
                ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final isPlaying = _controller.value.isPlaying;
    final position = _controller.value.position;
    final total = _controller.value.duration;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Play/pause
        Container(
          margin: EdgeInsets.only(bottom: AppSizes.ph12),
          width: AppSizes.h56,
          height: AppSizes.h56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.55),
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: AppSizes.sp32,
            ),
            onPressed: () {
              isPlaying ? _controller.pause() : _controller.play();
            },
          ),
        ),
        // Progress bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.pw16,
            0,
            AppSizes.pw16,
            AppSizes.ph30,
          ),
          child: Column(
            children: [
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primaryColor,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
              SizedBox(height: AppSizes.h8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: GoogleFonts.manrope(
                      color: Colors.white70,
                      fontSize: AppSizes.sp11,
                    ),
                  ),
                  Text(
                    _formatDuration(total),
                    style: GoogleFonts.manrope(
                      color: Colors.white70,
                      fontSize: AppSizes.sp11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Voice bubble ─────────────────────────────────────────────────────────────

class ChatVoiceBubble extends StatefulWidget {
  const ChatVoiceBubble({
    super.key,
    required this.mediaUrl,
    required this.isMine,
    this.mediaDuration,
  });

  final String mediaUrl;
  final bool isMine;
  final int? mediaDuration;

  @override
  State<ChatVoiceBubble> createState() => _ChatVoiceBubbleState();
}

class _ChatVoiceBubbleState extends State<ChatVoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _isLoading = false;

  static const int _barCount = 28;

  // Deterministic waveform heights from URL hash
  late final List<double> _waveform = _buildWaveform();

  List<double> _buildWaveform() {
    final seed = widget.mediaUrl.hashCode;
    return List.generate(_barCount, (i) {
      final v = ((seed ^ (i * 2654435761)) & 0xFF);
      return 0.2 + (v / 255.0) * 0.8;
    });
  }

  @override
  void initState() {
    super.initState();

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    if (widget.mediaDuration != null) {
      _total = Duration(seconds: widget.mediaDuration!);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      setState(() => _isLoading = true);
      try {
        if (_position >= _total && _total > Duration.zero) {
          await _player.seek(Duration.zero);
        }
        await _player.play(UrlSource(widget.mediaUrl));
        if (mounted) setState(() => _isPlaying = true);
      } catch (_) {
        // ignore play errors silently
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final Color onBubble =
        widget.isMine ? AppColors.buttonText : context.colors.textPrimary;
    final Color mutedOnBubble = widget.isMine
        ? AppColors.buttonText.withValues(alpha: 0.55)
        : context.colors.textMuted;
    final Color activeBarColor =
        widget.isMine ? AppColors.buttonText : AppColors.primaryColor;
    final Color inactiveBarColor = widget.isMine
        ? AppColors.buttonText.withValues(alpha: 0.3)
        : context.colors.textMuted.withValues(alpha: 0.35);

    final double progress =
        _total.inMilliseconds > 0
            ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

    final displayDuration =
        _isPlaying || _position > Duration.zero ? _position : _total;

    return SizedBox(
      width: AppSizes.w240,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw12,
          vertical: AppSizes.ph12,
        ),
        child: Row(
          children: [
            // Play / pause button
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: AppSizes.h40,
                height: AppSizes.h40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isMine
                      ? AppColors.buttonText.withValues(alpha: 0.18)
                      : AppColors.primaryColor.withValues(alpha: 0.15),
                ),
                child: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: onBubble,
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: onBubble,
                        size: AppSizes.sp20,
                      ),
              ),
            ),
            SizedBox(width: AppSizes.w10),
            // Waveform + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Waveform bars
                  SizedBox(
                    height: AppSizes.h32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_barCount, (i) {
                        final isActive =
                            i / _barCount <= progress && progress > 0;
                        return Container(
                          width: 2,
                          height: AppSizes.h32 *
                              _waveform[i] *
                              (isActive ? 1.0 : 0.9),
                          decoration: BoxDecoration(
                            color: isActive ? activeBarColor : inactiveBarColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: AppSizes.h4),
                  // Duration
                  Text(
                    _formatDuration(displayDuration),
                    style: GoogleFonts.manrope(
                      color: mutedOnBubble,
                      fontSize: AppSizes.sp10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recording waveform animation ─────────────────────────────────────────────

class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({super.key});

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const int _barCount = 20;
  final _random = math.Random(42);
  late final List<double> _baseHeights;

  @override
  void initState() {
    super.initState();
    _baseHeights =
        List.generate(_barCount, (_) => 0.2 + _random.nextDouble() * 0.8);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final t = _ctrl.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (i) {
            final phase = (i / _barCount * math.pi * 2);
            final animated = _baseHeights[i] *
                (0.5 + 0.5 * math.sin(t * math.pi * 2 + phase));
            return Container(
              width: 2.5,
              height: AppSizes.h32 * animated.clamp(0.15, 1.0),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}