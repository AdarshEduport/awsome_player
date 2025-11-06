class InteractiveViewerConfiguration {

  ///Max scale of the interactive viewer
  final double maxScale;

  ///Flag used to enable/disable interactive viewer on enter full screen
  final bool enabledOnLandscape;

  ///Flag used to enable/disable interactive viewer on exit full screen
  final bool enabledOnPortrait;

  const InteractiveViewerConfiguration({
    this.maxScale = 2.5,
    this.enabledOnLandscape = true,
    this.enabledOnPortrait = false,
  });
}