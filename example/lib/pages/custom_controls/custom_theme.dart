// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:awesome_video_player_example/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player/src/video_player/video_player.dart';
import 'package:awesome_video_player/src/video_player/video_player_platform_interface.dart';

class AwsomePlayerControls extends StatefulWidget {
  /// Callback for visibility changes
  final Function(bool visibility) onControlsVisibilityChanged;
  final Function(PlayerError)? onRetry;

  /// Player controller
  final BetterPlayerController betterPlayerController;

  const AwsomePlayerControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.onRetry,
    required this.betterPlayerController,
  }) : super(key: key);

  @override
  State<AwsomePlayerControls> createState() => _CustomPlayerControlsState();
}

class _CustomPlayerControlsState extends State<AwsomePlayerControls> {
  VideoPlayerValue? _latestValue;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _initTimer;
  bool is2xSkipping = false;
  double previousSpeed = 1;
  // Get the controls configuration
  BetterPlayerControlsConfiguration get _controlsConfiguration => widget
      .betterPlayerController.betterPlayerConfiguration.controlsConfiguration;

  // Get the current video controller
  VideoPlayerController? get _videoPlayerController =>
      widget.betterPlayerController.videoPlayerController;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _videoPlayerController?.addListener(_updateState);
    // widget.betterPlayerController.addEventsListener(betterPlayerEvent);
    _updateState();

    if (_videoPlayerController?.value.isPlaying == true ||
        widget.betterPlayerController.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    _initTimer = Timer(const Duration(milliseconds: 200), () {
      setState(() {
        _controlsVisible = true;
      });
      widget.onControlsVisibilityChanged(_controlsVisible);
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(AwsomePlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.betterPlayerController != widget.betterPlayerController) {
      _videoPlayerController?.removeListener(_updateState);
      _videoPlayerController?.addListener(_updateState);
      _updateState();
    }
  }

  void _updateState() {
    if (mounted) {
      setState(() {
        _latestValue = _videoPlayerController?.value;
      });
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      widget.onControlsVisibilityChanged(_controlsVisible);
    });

    if (_controlsVisible) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
          widget.onControlsVisibilityChanged(false);
        });
      }
    });
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() {
        _controlsVisible = true;
        widget.onControlsVisibilityChanged(true);
      });
      _startHideTimer();
    }
  }

  void _onPlayPause() {
    final controller = _videoPlayerController;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      widget.betterPlayerController.pause();
      _cancelAndRestartTimer();
    } else {
      if (controller.value.initialized) {
        if (_isVideoFinished()) {
          widget.betterPlayerController.seekTo(Duration.zero);
        }
        widget.betterPlayerController.play();
        _startHideTimer();
      }
    }
  }

  bool _isVideoFinished() {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.initialized) return false;

    final Duration? position = controller.value.position;
    final Duration? duration = controller.value.duration;

    if (position == null || duration == null) return false;
    return position >= duration;
  }

  void _onForward({int multiplier = 1}) {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.initialized) return;

    _cancelAndRestartTimer();
    final position = controller.value.position;
    final seekTo = position + Duration(seconds: 10 * multiplier);
    widget.betterPlayerController.seekTo(seekTo);
  }

  void _onRewind({int multiplier = 1}) {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.initialized) return;

    _cancelAndRestartTimer();
    final position = controller.value.position;
    final seekTo = position - Duration(seconds: 10 * multiplier);
    widget.betterPlayerController
        .seekTo(seekTo.isNegative ? Duration.zero : seekTo);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  ///Min. time of buffered video to hide loading timer (in milliseconds)
  static const int _bufferingInterval = 20000;

  ///Latest value can be null
  bool loadingStatus(VideoPlayerValue? latestValue) {
    if (latestValue != null) {
      if (!latestValue.isPlaying && latestValue.duration == null) {
        return true;
      }

      final Duration position = latestValue.position;

      Duration? bufferedEndPosition;
      if (latestValue.buffered.isNotEmpty == true) {
        bufferedEndPosition = latestValue.buffered.last.end;
      }

      if (bufferedEndPosition != null) {
        final difference = bufferedEndPosition - position;

        if (latestValue.isPlaying &&
            latestValue.isBuffering &&
            difference.inMilliseconds < _bufferingInterval) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoPlayerController;
    final isPlaying = controller?.value.isPlaying == true;
    final isInitialized = controller?.value.initialized == true;
    final bool isLoading = loadingStatus(controller?.value);
    final isFinished = _isVideoFinished();
    final size = MediaQuery.of(context).size;
    bool _hasError = _latestValue?.hasError == true;
    String _errorMessage = _latestValue?.errorDescription ?? 'Error';

    final bool isFullscreen = widget.betterPlayerController.isFullScreen;

    if (_hasError) {
      return CustomBetterPlayerErrorWidget(
        onRetry: widget.onRetry,
        controller: widget.betterPlayerController,
        errorMessage: _errorMessage,
      );
    }
    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        onLongPress: () {
          setState(() {
            is2xSkipping = true;
            _controlsVisible = false;
            previousSpeed = widget.betterPlayerController.videoPlayerController
                    ?.value.speed ??
                1;
          });
          widget.betterPlayerController.setSpeed(2.0);
        },
        onLongPressEnd: (s) {
          setState(() {
            is2xSkipping = false;
          });
          widget.betterPlayerController.setSpeed(previousSpeed);
        },
        onTap: _toggleControlsVisibility,
        child: AbsorbPointer(
          absorbing: !_controlsVisible,
          child: Stack(
            children: [
              // Main video content is handled by BetterPlayer itself

              // Controls layer
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Visibility(
                  visible: _controlsVisible,
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: Colors.white,
                                ),
                                onPressed: () async {
                                  if (widget
                                      .betterPlayerController.isFullScreen) {
                                    widget.betterPlayerController.pause();
                                  }
                                  final res = await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    constraints:
                                        BoxConstraints(maxWidth: size.width),
                                    useSafeArea: true,
                                    builder: (context) =>
                                        VideoSettingsBottomSheet(
                                      betterPlayerController:
                                          widget.betterPlayerController,
                                    ),
                                  );
                                  if (res == true) {
                                    if (widget
                                        .betterPlayerController.isFullScreen) {
                                      widget.betterPlayerController.play();
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  widget.betterPlayerController.isFullScreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  color: Colors.white,
                                ),
                                onPressed: () => widget.betterPlayerController
                                    .toggleFullScreen(),
                              ),
                            ],
                          ),
                        ),

                        // Middle section with play/pause and seek buttons
                        Expanded(
                          child: SizedBox(
                            width: isFullscreen ? size.width * .6 : null,
                            child: Row(
                              mainAxisAlignment: isFullscreen
                                  ? MainAxisAlignment.spaceBetween
                                  : MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: AnimatedSkipButton(
                                    showControls: (status) =>
                                        _cancelAndRestartTimer(),
                                    isBackward: true,
                                    iconData: Icons
                                        .keyboard_double_arrow_left_rounded,
                                    iconColor:
                                        _controlsConfiguration.iconsColor,
                                    skipDurationInSeconds: 10,
                                    onSkip: (count) {
                                      _onRewind(multiplier: count);
                                    },
                                  ),
                                ),
                                SizedBox(
                                    width: 70,
                                    height: 70,
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ):isFinished?GestureDetector(
                                            onTap: ()async {
                                            await widget.betterPlayerController.seekTo(const Duration());
                                            widget.betterPlayerController.play();
                                            },
                                            child: const Icon(Icons.replay,size: 50,color: Colors.white,))
                                        : AnimatedPlayPauseIcon(
                                            color: Colors.white,
                                            size: 50,
                                            
                                            isPlaying: isPlaying,
                                            onPressed: _onPlayPause,
                                          )),
                                Flexible(
                                  child: AnimatedSkipButton(
                                    showControls: (status) =>
                                        _cancelAndRestartTimer(),
                                    isBackward: false,
                                    iconData: Icons
                                        .keyboard_double_arrow_right_rounded,
                                    iconColor:
                                        _controlsConfiguration.iconsColor,
                                    skipDurationInSeconds: 10,
                                    onSkip: (count) {
                                      _onForward(multiplier: count);
                                    },
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),

                        // Bottom bar with progress
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Current time
                                        Flexible(
                                          child: Text(
                                            isInitialized
                                                ? _formatDuration(
                                                    controller!.value.position)
                                                : '00:00',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),

                                        // Duration
                                        Flexible(
                                          child: Text(
                                            ' / ${isInitialized ? _formatDuration(controller!.value.duration ?? Duration.zero) : '00:00'}',
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Progress bar
                                Flexible(
                                  child: Container(
                                    height: 30,
                                    margin: EdgeInsets.only(
                                        bottom: widget.betterPlayerController
                                                .isFullScreen
                                            ? 30
                                            : 0),
                                    alignment: Alignment.bottomCenter,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: HotStarProgressBar(
                                      widget.betterPlayerController
                                          .videoPlayerController,
                                      widget.betterPlayerController,
                                      onDragStart: () {
                                        _hideTimer?.cancel();
                                      },
                                      onDragEnd: () {
                                        _startHideTimer();
                                      },
                                      onTapDown: () {
                                        _cancelAndRestartTimer();
                                      },
                                      colors: BetterPlayerProgressColors(
                                          playedColor: Colors.redAccent,
                                          handleColor: _controlsConfiguration
                                              .progressBarHandleColor,
                                          bufferedColor: Colors.white,
                                          backgroundColor: Colors.grey),
                                    ),
                                  ),
                                )

                                // Time and volume
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 5,
                top: 5,
                child: Visibility(
                    visible: is2xSkipping,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.5),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "2x",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          Icon(
                            Icons.fast_forward_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ],
                      ),
                    )),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class HotStarProgressBar extends StatefulWidget {
  HotStarProgressBar(
    this.controller,
    this.betterPlayerController, {
    BetterPlayerProgressColors? colors,
    this.onDragEnd,
    this.onDragStart,
    this.onDragUpdate,
    this.onTapDown,
    Key? key,
  })  : colors = colors ?? BetterPlayerProgressColors(),
        super(key: key);

  final VideoPlayerController? controller;
  final BetterPlayerController? betterPlayerController;
  final BetterPlayerProgressColors colors;
  final Function()? onDragStart;
  final Function()? onDragEnd;
  final Function()? onDragUpdate;
  final Function()? onTapDown;

  @override
  _VideoProgressBarState createState() {
    return _VideoProgressBarState();
  }
}

class _VideoProgressBarState extends State<HotStarProgressBar> {
  _VideoProgressBarState() {
    listener = () {
      if (mounted && shouldUpdateState()) {
        setState(() {});
      }
    };
  }

  late VoidCallback listener;
  bool _controllerWasPlaying = false;

  VideoPlayerController? get controller => widget.controller;
  BetterPlayerController? get betterPlayerController =>
      widget.betterPlayerController;

  bool shouldPlayAfterDragEnd = false;
  Duration? lastSeek;
  Timer? _updateBlockTimer;
  Timer? _seekDebounceTimer;

  // For selective state updates
  Duration _lastPosition = Duration.zero;
  bool _lastBufferingState = false;
  List<DurationRange> _lastBufferedRanges = [];

  // Check if we need to update state
  bool shouldUpdateState() {
    if (!controller!.value.initialized) return false;

    final newPosition = controller!.value.position;
    final positionDifference =
        (newPosition - _lastPosition).abs().inMilliseconds;

    // Update if position changed significantly (e.g., more than 250ms)
    bool positionChanged = positionDifference > 250;

    // Update if buffering state changed
    bool bufferingChanged =
        _lastBufferingState != controller!.value.isBuffering;

    // Update if buffered ranges changed
    bool bufferedRangesChanged =
        _bufferedRangesChanged(controller!.value.buffered);

    // Save current values for next comparison
    if (positionChanged || bufferingChanged || bufferedRangesChanged) {
      _lastPosition = newPosition;
      _lastBufferingState = controller!.value.isBuffering;
      _lastBufferedRanges = List.from(controller!.value.buffered);
      return true;
    }

    return false;
  }

  // Check if buffered ranges changed significantly
  bool _bufferedRangesChanged(List<DurationRange> newRanges) {
    if (_lastBufferedRanges.length != newRanges.length) return true;

    for (int i = 0; i < newRanges.length; i++) {
      final oldRange = _lastBufferedRanges[i];
      final newRange = newRanges[i];

      // Check if start or end changed by more than 1 second
      if ((oldRange.start - newRange.start).abs().inSeconds > 1 ||
          (oldRange.end - newRange.end).abs().inSeconds > 1) {
        return true;
      }
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    if (controller != null && controller!.value.initialized) {
      _lastPosition = controller!.value.position;
      _lastBufferingState = controller!.value.isBuffering;
      _lastBufferedRanges = List.from(controller!.value.buffered);
    }
    controller!.addListener(listener);
  }

  @override
  void deactivate() {
    controller!.removeListener(listener);
    _cancelUpdateBlockTimer();
    _cancelSeekDebounceTimer();
    super.deactivate();
  }

  @override
  void dispose() {
    _cancelUpdateBlockTimer();
    _cancelSeekDebounceTimer();
    super.dispose();
  }

  void _cancelSeekDebounceTimer() {
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final bool enableProgressBarDrag = betterPlayerController!
        .betterPlayerConfiguration.controlsConfiguration.enableProgressBarDrag;

    return RepaintBoundary(
      child: GestureDetector(
        onHorizontalDragStart: (DragStartDetails details) {
          if (!controller!.value.initialized || !enableProgressBarDrag) {
            return;
          }

          _controllerWasPlaying = controller!.value.isPlaying;
          if (_controllerWasPlaying) {
            // controller!.pause();
          }

          _cancelSeekDebounceTimer();

          if (widget.onDragStart != null) {
            widget.onDragStart!();
          }
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          if (!controller!.value.initialized || !enableProgressBarDrag) {
            return;
          }

          seekToRelativePosition(details.globalPosition);

          if (widget.onDragUpdate != null) {
            widget.onDragUpdate!();
          }
        },
        onHorizontalDragEnd: (DragEndDetails details) {
          if (!enableProgressBarDrag) {
            return;
          }

          // Execute any pending seek operation immediately
          _cancelSeekDebounceTimer();
          if (lastSeek != null) {
            betterPlayerController!.seekTo(lastSeek!);
          }

          if (_controllerWasPlaying) {
            // betterPlayerController?.play();
            shouldPlayAfterDragEnd = true;
          }
          _setupUpdateBlockTimer();

          if (widget.onDragEnd != null) {
            widget.onDragEnd!();
          }
        },
        onTapDown: (TapDownDetails details) {
          if (!controller!.value.initialized || !enableProgressBarDrag) {
            return;
          }

          // Direct seek on tap (no debounce)
          final position = calculatePosition(details.globalPosition);
          if (position != null) {
            lastSeek = position;
            betterPlayerController!.seekTo(position);
          }

          _setupUpdateBlockTimer();

          if (widget.onTapDown != null) {
            widget.onTapDown!();
          }
        },
        child: Center(
          child: Container(
            height: MediaQuery.of(context).size.height / 2,
            width: MediaQuery.of(context).size.width,
            color: Colors.transparent,
            child: CustomPaint(
              painter: _ProgressBarPainter(
                _getValue(),
                widget.colors,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setupUpdateBlockTimer() {
    _cancelUpdateBlockTimer();
    _updateBlockTimer = Timer(const Duration(milliseconds: 1000), () {
      lastSeek = null;
    });
  }

  void _cancelUpdateBlockTimer() {
    _updateBlockTimer?.cancel();
    _updateBlockTimer = null;
  }

  VideoPlayerValue _getValue() {
    if (lastSeek != null) {
      return controller!.value.copyWith(position: lastSeek);
    } else {
      return controller!.value;
    }
  }

  Duration? calculatePosition(Offset globalPosition) {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject != null && controller!.value.duration != null) {
      final box = renderObject as RenderBox;
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      if (relative > 0) {
        final Duration position = controller!.value.duration! * relative;
        if (relative >= 1) {
          return controller!.value.duration;
        }
        return position;
      }
    }
    return null;
  }

  void seekToRelativePosition(Offset globalPosition) {
    final position = calculatePosition(globalPosition);
    if (position == null) return;

    // Update UI immediately
    setState(() {
      lastSeek = position;
    });

    // Debounce actual seek operations to reduce load
    _cancelSeekDebounceTimer();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        betterPlayerController!.seekTo(position);
      }
    });
  }

  void onFinishedLastSeek() {
    if (shouldPlayAfterDragEnd) {
      shouldPlayAfterDragEnd = false;
      betterPlayerController?.play();
    }
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter(this.value, this.colors);

  final VideoPlayerValue value;
  final BetterPlayerProgressColors colors;

  @override
  bool shouldRepaint(_ProgressBarPainter oldPainter) {
    // Only repaint if there are meaningful changes
    if (!value.initialized) return oldPainter.value.initialized;

    if (!oldPainter.value.initialized) return true;

    // Check position difference
    final positionDiff = (value.position.inMilliseconds -
            oldPainter.value.position.inMilliseconds)
        .abs();
    if (positionDiff > 100) return true;

    // Check buffered ranges
    if (value.buffered.length != oldPainter.value.buffered.length) return true;

    // Check if any significant buffer changes
    for (int i = 0; i < value.buffered.length; i++) {
      if (i >= oldPainter.value.buffered.length) return true;

      final newRange = value.buffered[i];
      final oldRange = oldPainter.value.buffered[i];

      if ((newRange.end.inMilliseconds - oldRange.end.inMilliseconds).abs() >
          500) {
        return true;
      }
    }

    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const height = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, size.height / 2),
          Offset(size.width, size.height / 2 + height),
        ),
        const Radius.circular(8.0),
      ),
      colors.backgroundPaint,
    );

    if (!value.initialized) {
      return;
    }

    double playedPartPercent =
        value.position.inMilliseconds / value.duration!.inMilliseconds;
    if (playedPartPercent.isNaN) {
      playedPartPercent = 0;
    }

    final double playedPart =
        playedPartPercent > 1 ? size.width : playedPartPercent * size.width;

    // Draw buffered ranges
    for (final range in value.buffered) {
      double start = range.startFraction(value.duration!) * size.width;
      if (start.isNaN) {
        start = 0;
      }
      double end = range.endFraction(value.duration!) * size.width;
      if (end.isNaN) {
        end = 0;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(
            Offset(start, size.height / 2),
            Offset(end, size.height / 2 + height),
          ),
          const Radius.circular(4.0),
        ),
        colors.bufferedPaint,
      );
    }

    // Draw played part
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, size.height / 2),
          Offset(playedPart, size.height / 2 + height),
        ),
        const Radius.circular(4.0),
      ),
      colors.playedPaint,
    );

    // Draw handle
    canvas.drawCircle(
      Offset(playedPart, size.height / 2 + height / 2),
      height * 5,
      colors.handlePaint,
    );
  }
}

class AnimatedSkipButton extends StatefulWidget {
  final IconData iconData;
  final Color iconColor;
  final double iconSize;
  final int skipDurationInSeconds;
  final Function(int tapCount) onSkip; // Changed to accept tap count
  final Function(bool controlsActive)
      showControls; // Changed to accept tap count
  final bool isBackward;

  const AnimatedSkipButton({
    Key? key,
    required this.iconData,
    required this.iconColor,
    this.iconSize = 44.0,
    required this.skipDurationInSeconds,
    required this.onSkip,
    this.isBackward = true,
    required this.showControls,
  }) : super(key: key);

  @override
  _AnimatedSkipButtonState createState() => _AnimatedSkipButtonState();
}

class _AnimatedSkipButtonState extends State<AnimatedSkipButton> {
  bool _isSkipTapped = false;
  int _tapCount = 0;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();

    super.dispose();
  }

  Widget _buildDurationIndicator() {
    return AnimatedOpacity(
      opacity: _isSkipTapped ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: _isSkipTapped ? 16 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          "${widget.skipDurationInSeconds * (_tapCount > 0 ? _tapCount : 1)}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    setState(() {
      _isSkipTapped = true;
      _tapCount++;
      widget.showControls(false);
    });

    // Cancel existing timer if it's running
    _debounceTimer?.cancel();

    // Set a new timer to execute the callback after a delay
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Call the skip function with the tap count
        widget.onSkip(_tapCount);

        // Reset tap count and hide the indicator
        setState(() {
          _tapCount = 0;
          _isSkipTapped = false;
        });
      }
    });

    // Keep the indicator visible longer when tapped
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _tapCount == 0) {
        setState(() {
          _isSkipTapped = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(widget.iconSize),
      onTap: _handleTap,
      child: SizedBox(
        width: 90,
        height: 120,
        child: Row(
          mainAxisAlignment: widget.isBackward
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Visibility(
              visible: !widget.isBackward,
              child: _buildDurationIndicator(),
            ),
            // The main skip icon
            Flexible(
              child: Icon(
                widget.iconData,
                size: widget.iconSize,
                color: widget.iconColor,
              ),
            ),
            Visibility(
              visible: widget.isBackward,
              child: _buildDurationIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoSettingsBottomSheet extends StatefulWidget {
  final BetterPlayerController betterPlayerController;

  const VideoSettingsBottomSheet({
    Key? key,
    required this.betterPlayerController,
  }) : super(key: key);

  @override
  _VideoSettingsBottomSheetState createState() =>
      _VideoSettingsBottomSheetState();
}

class _VideoSettingsBottomSheetState extends State<VideoSettingsBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<double> _speedOptions = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
   ];
  
  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
     _speedOptions.addAll([
    2.25,
    2.5,
    2.75,
    3.0,
  ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTrackRow(BetterPlayerAsmsTrack track, String? preferredName) {
    final int width = track.width ?? 0;
    final int height = track.height ?? 0;

    final resolution = width > height ? height : width;
    final resolutionName = resolution == 0 ? "Auto" : '${resolution}p';
    final String trackName = preferredName ?? resolutionName;
    // "${width}x$height ${BetterPlayerUtils.formatBitrate(bitrate)} $mimeType";

    final BetterPlayerAsmsTrack? selectedTrack =
        widget.betterPlayerController.betterPlayerAsmsTrack;
    final bool isSelected = selectedTrack != null && selectedTrack == track;
    return ListTile(
      title: Text(
        trackName,
        style: TextStyle(
            color: isSelected ? Colors.white : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14),
      ),
      leading: isSelected
          ? const Icon(Icons.check, size: 22, color: Colors.white)
          : const SizedBox(
              width: 22,
              height: 22,
            ),
      onTap: () {
        widget.betterPlayerController.setTrack(track);
       
       

        Navigator.pop(context, true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFullScreen = widget.betterPlayerController.isFullScreen;
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      height: isFullScreen ? size.height : 350,
      width: isFullScreen ? size.width : null,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(isFullScreen ? 0.8 : .9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // Close bar
          Visibility(
            visible: !isFullScreen,
            child: Container(
              padding: const EdgeInsets.only(top: 8),
              margin: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          // Settings header

          // Tab bar
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: SizedBox(
                    width: isFullScreen ? 200 : null,
                    child: TabBar(
                      indicatorWeight: .5,
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white,
                      dividerHeight: 0,
                      tabs: const [
                        Tab(text: "Quality"),
                        Tab(text: "Speed"),
                      ],
                    ),
                  ),
                ),
                Visibility(
                  visible: isFullScreen,
                  child: IconButton(
                    onPressed: () {
                      if (isFullScreen) {
                        widget.betterPlayerController.play();
                      }
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                )
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: StretchingScrollWidget(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Quality tab
                  _buildQualityTab(),
                  // Speed tab
                  _buildSpeedTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityTab() {
    final List<String> asmsTrackNames =
        widget.betterPlayerController.betterPlayerDataSource!.asmsTrackNames ??
            [];
    final List<BetterPlayerAsmsTrack> asmsTracks =
        widget.betterPlayerController.betterPlayerAsmsTracks;
    final List<Widget> children = [];
    for (var index = 0; index < asmsTracks.length; index++) {
      final track = asmsTracks[index];

      String? preferredName;
      if (track.height == 0 && track.width == 0 && track.bitrate == 0) {
        preferredName = widget.betterPlayerController.translations.qualityAuto;
      } else {
        preferredName =
            asmsTrackNames.length > index ? asmsTrackNames[index] : null;
      }
      children.add(_buildTrackRow(asmsTracks[index], preferredName));
    }
    return ListView.builder(
      itemCount: children.length,
      itemBuilder: (context, index) {
        return children[index];
      },
    );
  }

  Widget _buildSpeedTab() {
    return ListView.builder(
      itemCount: _speedOptions.length,
      itemBuilder: (context, index) {
        final speed = _speedOptions[index];
        final bool isSelected =
            widget.betterPlayerController.videoPlayerController!.value.speed ==
                speed;
        final displayText = speed == 1.0 ? "Normal" : "${speed}x";

        return ListTile(
          title: Text(
            displayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          leading: isSelected
              ? const Icon(Icons.check, size: 22, color: Colors.white)
              : const SizedBox(
                  width: 22,
                  height: 22,
                ),
          onTap: () async {
            widget.betterPlayerController.setSpeed(speed);
            Navigator.pop(context, true);
          },
        );
      },
    );
  }
}

class AnimatedPlayPauseIcon extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final VoidCallback? onPressed;
  final Color? color;
  final Duration duration;

  const AnimatedPlayPauseIcon({
    super.key,
    required this.isPlaying,
    this.size = 48.0,
    this.onPressed,
    this.color,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedPlayPauseIcon> createState() => _AnimatedPlayPauseIconState();
}

class _AnimatedPlayPauseIconState extends State<AnimatedPlayPauseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    animation = Tween<double>(begin: 0.0, end: 1.0).animate(controller);
    _updateControllerValue(true);
  }

  @override
  void didUpdateWidget(AnimatedPlayPauseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _updateControllerValue(false);
    }
    if (widget.duration != oldWidget.duration) {
      controller.duration = widget.duration;
    }
  }

  void _updateControllerValue(bool isInit) {
    if (widget.isPlaying) {
      if (isInit) {
        controller.forward(from: 1);
      } else {
        controller.forward();
      }
    } else {
      controller.reverse();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: widget.size,
      onPressed: widget.onPressed,
      icon: AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: animation,
        size: widget.size,
        color: widget.color,
        semanticLabel: widget.isPlaying ? 'Pause' : 'Play',
      ),
    );
  }
}

class CustomBetterPlayerErrorWidget extends StatelessWidget {
  final BetterPlayerController? controller;
  final String errorMessage;
  final Function(PlayerError error)? onRetry;
  final Color backgroundColor;
  final Color textColor;
  final Color buttonColor;

  const CustomBetterPlayerErrorWidget({
    Key? key,
    this.controller,
    this.errorMessage = "Video playback error occurred",
    this.onRetry,
    this.backgroundColor = Colors.black87,
    this.textColor = Colors.white,
    this.buttonColor = Colors.red,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: textColor,
              size: 42,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                MediaPlayerErrorHandler.getUserMessage(errorMessage),
                style: TextStyle(color: textColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRetryButton(context),
                _buildCloseButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: () {
        if (onRetry != null) {
          onRetry!(MediaPlayerErrorHandler.getPlayerError(errorMessage));
        }
        if (controller != null) {
          controller!.retryDataSource();
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('Retry'),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    if(controller?.isFullScreen!=true){
return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: () {
          if (controller?.isFullScreen == true) {
            controller?.exitFullScreen();
          }
        },
        icon: const Icon(Icons.close_fullscreen),
        label: const Text('Close'),
      ),
    );
  }
}

class StretchingScrollWidget extends StatelessWidget {
  const StretchingScrollWidget(
      {super.key,
      required this.child,
      this.axisDirection = AxisDirection.down});
  final AxisDirection axisDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StretchingOverscrollIndicator(
      axisDirection: axisDirection,
      child: ScrollConfiguration(
        behavior: /* Platform.isIOS
            ?  */
            const ScrollBehavior().copyWith(
                physics: const ClampingScrollPhysics(), overscroll: false),
        // : ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: child,
      ),
    );
  }
}

class PlayerError {
  final String userMessage; // Message shown to user
  final String errorCode; // Error code for tracking
  final String originalError; // Original error text

  PlayerError(this.userMessage, this.errorCode, this.originalError);
}

class MediaPlayerErrorHandler {
  // Error group identifiers (for internal use and logging only)
  static const String _NETWORK_ERROR = "NET";
  static const String _FORMAT_ERROR = "FORMAT";
  static const String _DRM_ERROR = "DRM";
  static const String _SOURCE_ERROR = "SOURCE";
  static const String _SOURCE_NOT_FOUND = "SOURCE-404";
  static const String _SOURCE_ACCESS = "SOURCE-ACCESS";
  static const String _PARSING_ERROR = "PARSE";
  static const String _UNKNOWN_ERROR = "UNKNOWN";
  static const String _TIMEOUT_ERROR = "TIMEOUT";
  static const String _CODEC_ERROR = "CODEC";
  static const String _PLAYBACK_ERROR = "PLAYBACK";

  /// Class to store both user-friendly messages and error tracking data

  /// Converts ExoPlayer error codes and messages to PlayerError objects
  static PlayerError _handleExoPlayerError(dynamic error) {
    // Store the original error for logging
    final String originalError = error.toString();

    // Convert error to String if it's not already and normalize to lowercase
    final String errorDescription = originalError.toLowerCase();

    // Network related errors - with specific timeout detection
    if (errorDescription.contains('timeout') ||
        errorDescription.contains('timed out')) {
      return PlayerError(
          "Connection timed out. Please check your internet and try again.",
          _TIMEOUT_ERROR,
          originalError);
    }

    if (errorDescription.contains('connection') ||
        errorDescription.contains('network') ||
        errorDescription.contains('internet')) {
      return PlayerError(
          "Network connection issue. Please check your internet and try again.",
          _NETWORK_ERROR,
          originalError);
    }

    // Source errors - with specific subtype identification
    if (errorDescription.contains('404') ||
        errorDescription.contains('not found')) {
      return PlayerError("The media file couldn't be found.", _SOURCE_NOT_FOUND,
          originalError);
    }

    if (errorDescription.contains('access denied') ||
        errorDescription.contains('permission') ||
        errorDescription.contains('403')) {
      return PlayerError("Access to the media file was denied.", _SOURCE_ACCESS,
          originalError);
    }

    if (errorDescription.contains('source')) {
      return PlayerError("There's an issue with the media source.",
          _SOURCE_ERROR, originalError);
    }

    // Format or codec errors
    if (errorDescription.contains('format') ||
        errorDescription.contains('unsupported')) {
      return PlayerError("This media format isn't supported on your device.",
          _FORMAT_ERROR, originalError);
    }

    if (errorDescription.contains('codec') ||
        errorDescription.contains('decoder')) {
      return PlayerError("This media codec isn't supported on your device.",
          _CODEC_ERROR, originalError);
    }

    // DRM errors
    if (errorDescription.contains('drm') ||
        errorDescription.contains('protection')) {
      return PlayerError(
          "Content protection error. This content cannot be played.",
          _DRM_ERROR,
          originalError);
    }

    // Parsing errors
    if (errorDescription.contains('parse') ||
        errorDescription.contains('parsing')) {
      return PlayerError(
          "There was a problem with the media file. Please try another file.",
          _PARSING_ERROR,
          originalError);
    }

    // ExoPlayer specific error codes
    if (errorDescription.contains('error code: 2001')) {
      return PlayerError(
          "Network connection issue. Please check your internet.",
          _NETWORK_ERROR,
          originalError);
    }

    if (errorDescription.contains('error code: 2002')) {
      return PlayerError("Invalid media file. Please try another video.",
          _SOURCE_ERROR, originalError);
    }

    if (errorDescription.contains('error code: 2003')) {
      return PlayerError("This media is not compatible with your device.",
          _FORMAT_ERROR, originalError);
    }

    if (errorDescription.contains('error code: 2004')) {
      return PlayerError(
          "Content protection error. This content cannot be played.",
          _DRM_ERROR,
          originalError);
    }

    // Default message
    return PlayerError("Unable to play this media. Please try again later.",
        _UNKNOWN_ERROR, originalError);
  }

  /// Handles AVPlayer errors (iOS) and converts them to PlayerError objects
  static PlayerError _handleAVPlayerError(dynamic error) {
    // Store the original error for logging
    final String originalError = error.toString();

    // Convert error to String if it's not already and normalize to lowercase
    final String errorDescription = originalError.toLowerCase();

    // AVPlayer domain error codes
    if (errorDescription.contains('error -11800') ||
        errorDescription.contains('avfoundationerrordomain: -11800')) {
      return PlayerError("The media file couldn't be found or accessed.",
          _SOURCE_ERROR, originalError);
    }

    if (errorDescription.contains('error -11828') ||
        errorDescription.contains('avfoundationerrordomain: -11828')) {
      return PlayerError(
          "Network connection issue. Please check your internet.",
          _NETWORK_ERROR,
          originalError);
    }

    if (errorDescription.contains('error -11850') ||
        errorDescription.contains('avfoundationerrordomain: -11850')) {
      return PlayerError("Media is not compatible with your device.",
          _FORMAT_ERROR, originalError);
    }

    if (errorDescription.contains('error -12889') ||
        errorDescription.contains('avfoundationerrordomain: -12889')) {
      return PlayerError("Media playback canceled. Please try again.",
          _PLAYBACK_ERROR, originalError);
    }

    // Source errors - with specific subtype identification for iOS errors
    if (errorDescription.contains('404') ||
        errorDescription.contains('file not found')) {
      return PlayerError("The media file couldn't be found.", _SOURCE_NOT_FOUND,
          originalError);
    }

    if (errorDescription.contains('403') ||
        errorDescription.contains('access denied') ||
        errorDescription.contains('permission')) {
      return PlayerError("Access to the media file was denied.", _SOURCE_ACCESS,
          originalError);
    }

    if (errorDescription.contains('source')) {
      return PlayerError("There's an issue with the media source.",
          _SOURCE_ERROR, originalError);
    }

    // URL error domain codes
    if (errorDescription.contains('domain=nsurlerrordomain, code=-1009')) {
      return PlayerError("Internet connection appears to be offline.",
          _NETWORK_ERROR, originalError);
    }

    if (errorDescription.contains('domain=nsurlerrordomain, code=-1001')) {
      return PlayerError("Connection timed out. Please try again.",
          _TIMEOUT_ERROR, originalError);
    }

    // Check for common keywords to determine error type
    if (errorDescription.contains('timeout') ||
        errorDescription.contains('timed out')) {
      return PlayerError(
          "Connection timed out. Please check your internet and try again.",
          _TIMEOUT_ERROR,
          originalError);
    }

    if (errorDescription.contains('connection') ||
        errorDescription.contains('network') ||
        errorDescription.contains('internet')) {
      return PlayerError(
          "Network connection issue. Please check your internet.",
          _NETWORK_ERROR,
          originalError);
    }

    if (errorDescription.contains('format')) {
      return PlayerError("This media format isn't supported on your device.",
          _FORMAT_ERROR, originalError);
    }

    if (errorDescription.contains('codec') ||
        errorDescription.contains('decoder')) {
      return PlayerError("This media codec isn't supported on your device.",
          _CODEC_ERROR, originalError);
    }

    if (errorDescription.contains('drm') ||
        errorDescription.contains('fairplay') ||
        errorDescription.contains('protection')) {
      return PlayerError(
          "Content protection error. This content cannot be played.",
          _DRM_ERROR,
          originalError);
    }

    // Default message
    return PlayerError("Unable to play this media. Please try again later.",
        _UNKNOWN_ERROR, originalError);
  }

  /// Get the user-friendly error message only (for displaying to users)
  static String getUserMessage(dynamic error, {bool isIOS = false}) {
    final PlayerError playerError =
        isIOS ? _handleAVPlayerError(error) : _handleExoPlayerError(error);

    return playerError.userMessage;
  }

  /// Get the error code for analytics and logging
  static String getErrorCode(dynamic error, {bool isIOS = false}) {
    final PlayerError playerError =
        isIOS ? _handleAVPlayerError(error) : _handleExoPlayerError(error);

    return playerError.errorCode;
  }

  /// Get the full PlayerError object with all details
  static PlayerError getPlayerError(dynamic error, {bool isIOS = false}) {
    return isIOS ? _handleAVPlayerError(error) : _handleExoPlayerError(error);
  }

  /// Example usage in a video player widget
  static void showErrorDialog(BuildContext context, dynamic error,
      {bool isIOS = false}) {
    final PlayerError playerError = getPlayerError(error, isIOS: isIOS);

    // Log the detailed error for developers
    print("Player error occurred: ${playerError.errorCode}");
    print("Original error: ${playerError.originalError}");

    // Only show user-friendly message to the user
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Playback Error"),
          content: Text(playerError.userMessage),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Logs errors to analytics with detailed error information
  static void logErrorAnalytics(dynamic error, {bool isIOS = false}) {
    final playerError = getPlayerError(error, isIOS: isIOS);

    // Example of how you might log to analytics
    print("Logging to analytics: Error Code: ${playerError.errorCode}");
    print("User Message: ${playerError.userMessage}");
    print("Original Error: ${playerError.originalError}");

    // Here you would call your analytics service
    // Example: FirebaseAnalytics.instance.logEvent(
    //   name: 'player_error',
    //   parameters: {
    //     'error_code': playerError.errorCode,
    //     'user_message': playerError.userMessage,
    //     'original_error': playerError.originalError,
    //   },
    // );
  }
}


class HlsTest extends StatefulWidget {
  @override
  _HlsTracksPageState createState() => _HlsTracksPageState();
}

class _HlsTracksPageState extends State<HlsTest> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
        allowedScreenSleep: false,
      autoPlay: true,
      autoDispose: false,
    
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableAudioTracks: false,
        playerTheme: BetterPlayerTheme.custom,
        customControlsBuilder: (BetterPlayerController playerController,
                dynamic Function(bool) onControlsVisibilityChanged) =>
            AwsomePlayerControls(
          betterPlayerController: playerController,
          onControlsVisibilityChanged: onControlsVisibilityChanged,
          onRetry: (error) {},
        ),
      ),
      fit: BoxFit.contain,
    );
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.hlsTestStreamUrlNew,
      videoFormat: BetterPlayerVideoFormat.hls,
      useAsmsSubtitles: true,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("HLS tracks"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Player with HLS stream which loads tracks from HLS."
              " You can choose tracks by using overflow menu (3 dots in right corner).",
              style: TextStyle(fontSize: 16),
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
        ],
      ),
    );
  }
}
