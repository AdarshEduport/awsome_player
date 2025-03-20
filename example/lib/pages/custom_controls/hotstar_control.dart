
import 'package:flutter/material.dart';
import 'package:awesome_video_player/awesome_video_player.dart';

import 'dart:async';

import 'package:awesome_video_player/src/video_player/video_player.dart';


class AwsomePlayerControls extends StatefulWidget {
  /// Callback for visibility changes
  final Function(bool visibility) onControlsVisibilityChanged;

  /// Player controller
  final BetterPlayerController betterPlayerController;

  const AwsomePlayerControls({
    Key? key,
    required this.onControlsVisibilityChanged,
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

  void _onProgressBarDragStart() {
    _hideTimer?.cancel();
  }

  void _onProgressBarDragEnd() {
    _startHideTimer();
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

  String trimError(String data) {
      data =
          data.replaceAll('androidx.media3.exoplayer.ExoPlaybackException', '');
      if (data.length >= 50) {
        return data.substring(0, 50);
      } else {
        return data;
      }
    }
  @override
  Widget build(BuildContext context) {
    final controller = _videoPlayerController;
    final isPlaying = controller?.value.isPlaying == true;
    final isInitialized = controller?.value.initialized == true;
    final bool isLoading =
        controller?.value.isBuffering == true || !isInitialized;
    final size = MediaQuery.of(context).size;
    bool _hasError =_latestValue?.hasError==true;
    String _errorMessage =trimError( _latestValue?.errorDescription??'Error');

    final bool isFullscreen = widget.betterPlayerController.isFullScreen;
  

    if(_hasError){
      return
      SafeArea(
          top: false,
      bottom: false,
        child: CustomBetterPlayerErrorWidget(
                controller: widget.betterPlayerController,
                errorMessage: _errorMessage,
              ),
      );
    }
    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
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
                                onPressed: () {
                                  showModalBottomSheet(
                                    useSafeArea: true,
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        VideoSettingsBottomSheet(
                                      betterPlayerController:
                                          widget.betterPlayerController,
                                    ),
                                  );
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
                                    isBackward: true,
                                    iconData:
                                        Icons.keyboard_double_arrow_left_rounded,
                                    iconColor: _controlsConfiguration.iconsColor,
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
                                          )
                                        : AnimatedPlayPauseIcon(
                                            color: Colors.white,
                                            size: 50,
                                            isPlaying: isPlaying,
                                            onPressed: _onPlayPause,
                                          )),
                                Flexible(
                                  child: AnimatedSkipButton(
                                    isBackward: false,
                                    iconData:
                                        Icons.keyboard_double_arrow_right_rounded,
                                    iconColor: _controlsConfiguration.iconsColor,
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
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 8.0),
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
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                          
                                        // Duration
                                        Text(
                                          ' / ${isInitialized ? _formatDuration(controller!.value.duration ?? Duration.zero) : '00:00'}',
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
        
                                // Progress bar
                                Expanded(
                                  child: Container(
                                    height: 30,
                                    margin: EdgeInsets.only(
                                        bottom: widget
                                                .betterPlayerController.isFullScreen
                                            ? 30
                                            : 0),
                                    alignment: Alignment.bottomCenter,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}


class Throttler {
  final Duration interval;
  DateTime? _lastExecutionTime;

  Throttler({required this.interval});

  bool run(Function() callback) {
    final now = DateTime.now();
    
    // If this is the first run or if enough time has passed since last execution
    if (_lastExecutionTime == null || now.difference(_lastExecutionTime!) > interval) {
      _lastExecutionTime = now;
      callback();
      return true; // Function was executed
    }
    
    return false; // Function was not executed (throttled)
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
      if (mounted) setState(() {});
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

  @override
  void initState() {
    super.initState();
    controller!.addListener(listener);
  }

  @override
  void deactivate() {
    controller!.removeListener(listener);
    _cancelUpdateBlockTimer();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final bool enableProgressBarDrag = betterPlayerController!
        .betterPlayerConfiguration.controlsConfiguration.enableProgressBarDrag;

    return GestureDetector(
      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller!.value.initialized || !enableProgressBarDrag) {
          return;
        }

        _controllerWasPlaying = controller!.value.isPlaying;
        if (_controllerWasPlaying) {
          controller!.pause();
        }

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

        if (_controllerWasPlaying) {
          betterPlayerController?.play();
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
        seekToRelativePosition(details.globalPosition);
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
    );
  }

  void _setupUpdateBlockTimer() {
    _updateBlockTimer = Timer(const Duration(milliseconds: 1000), () {
      lastSeek = null;
      _cancelUpdateBlockTimer();
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

  void seekToRelativePosition(Offset globalPosition) async {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject != null) {
      final box = renderObject as RenderBox;
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      if (relative > 0) {
        final Duration position = controller!.value.duration! * relative;
        lastSeek = position;
        await betterPlayerController!.seekTo(position);

        onFinishedLastSeek();
        if (relative >= 1) {
          lastSeek = controller!.value.duration;
          await betterPlayerController!.seekTo(controller!.value.duration!);
          onFinishedLastSeek();
        }
      }
    }
    
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

  VideoPlayerValue value;
  BetterPlayerProgressColors colors;

  @override
  bool shouldRepaint(CustomPainter painter) {
    return true;
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
  final bool isBackward;

  const AnimatedSkipButton({
    Key? key,
    required this.iconData,
    required this.iconColor,
    this.iconSize = 44.0,
    required this.skipDurationInSeconds,
    required this.onSkip,
    this.isBackward = true,
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
      onTap: _handleTap,
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
  final List<double> _speedOptions = [0.25,0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final resolutionName =
        resolution == 0 ? "Auto" : '${resolution}p';
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
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFullScreen = widget.betterPlayerController.isFullScreen;
    final size = MediaQuery.of(context).size;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: isFullScreen ? size.height * 0.9 : 350,
      decoration: const BoxDecoration(
        color: Color(0xff1A1F38),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Close bar
          Container(
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

          // Settings header

          // Tab bar
          Align(
            alignment: Alignment.centerLeft,
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
    return StretchingScrollWidget(
      child: ListView.builder(
        itemCount: children.length,
        itemBuilder: (context, index) {
          return children[index];
        },
      ),
    );
  }

  Widget _buildSpeedTab() {
    return StretchingScrollWidget(
      child: ListView.builder(
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
            onTap: () {
              widget.betterPlayerController.setSpeed(speed);
              Navigator.pop(context);
            },
          );
        },
      ),
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
    _updateControllerValue();
  }

  @override
  void didUpdateWidget(AnimatedPlayPauseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _updateControllerValue();
    }
    if (widget.duration != oldWidget.duration) {
      controller.duration = widget.duration;
    }
  }

  void _updateControllerValue() {
    if (widget.isPlaying) {
      controller.forward();
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
  final VoidCallback? onRetry;
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
                errorMessage,
                style: TextStyle(color: textColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            _buildRetryButton(context),
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
          onRetry!();
        } else if (controller != null) {
          controller!.retryDataSource();
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('Retry'),
    );
  }
}


class StretchingScrollWidget extends StatelessWidget {
  const StretchingScrollWidget({super.key, required this.child, this.axisDirection = AxisDirection.down});
  final AxisDirection axisDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StretchingOverscrollIndicator(
      axisDirection: axisDirection,
      child: ScrollConfiguration(
        behavior: /* Platform.isIOS
            ?  */
            const ScrollBehavior().copyWith(physics: const ClampingScrollPhysics(), overscroll: false),
        // : ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: child,
      ),
    );
  }
}