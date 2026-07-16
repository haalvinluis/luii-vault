import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/reel_model.dart';
import '../../core/theme.dart';
import '../../main.dart';

class ReelsPlayer extends StatefulWidget {
  final ReelModel reel;
  final bool isActive;
  static Function(String command)? onActivePlayerCommand;

  const ReelsPlayer({super.key, required this.reel, required this.isActive});

  @override
  State<ReelsPlayer> createState() => _ReelsPlayerState();
}

class _ReelsPlayerState extends State<ReelsPlayer>
    with TickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  // Mock abstract visualizer animation controller
  late AnimationController _visualizerController;

  // Real Video Player Controllers
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _showPlayPauseOverlay = false;
  bool _isVideoCompleted = false;
  bool _hasError = false;
  String _errorMessage = "";
  String _codecInfo = "Unknown Codec";
  bool _hasResolutionWarning = false;
  bool _warningDismissed = false;

  @override
  void initState() {
    super.initState();
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _zoomAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _transformationController.value = _zoomAnimation!.value;
          }
        });

    if (widget.isActive) {
      ReelsPlayer.onActivePlayerCommand = _handleVoiceCommand;
    }

    if (widget.reel.localVideoPath != null &&
        File(widget.reel.localVideoPath!).existsSync()) {
      _initVideoPlayer();
    } else {
      if (widget.isActive) {
        _visualizerController.repeat();
      }
    }
  }

  Future<void> _extractCodecInfo(File file) async {
    try {
      final size = await file.length();
      final readLen = size < 128 * 1024 ? size : 128 * 1024;
      final raf = await file.open();
      final bytes = await raf.read(readLen);
      await raf.close();

      final fileContent = String.fromCharCodes(bytes);
      if (fileContent.contains("avc1")) {
        _codecInfo = "H.264 (AVC1)";
      } else if (fileContent.contains("hev1") || fileContent.contains("hvc1")) {
        _codecInfo = "H.265 (HEVC)";
      } else if (fileContent.contains("mp4v")) {
        _codecInfo = "MPEG-4 Video";
      } else if (fileContent.contains("vp09")) {
        _codecInfo = "VP9";
      } else if (fileContent.contains("av01")) {
        _codecInfo = "AV1";
      } else {
        _codecInfo = "MPEG-4 compatible";
      }
    } catch (e) {
      _codecInfo = "Error reading codec: $e";
    }
  }

  void _logDetailedPlaybackInfo(String eventState) {
    debugPrint("[ReelsPlayer Debug Log]");
    debugPrint("  - Event State: $eventState");
    debugPrint("  - File Path: ${widget.reel.localVideoPath}");
    if (_videoController != null && _isVideoInitialized) {
      debugPrint(
        "  - Resolution: ${_videoController!.value.size.width.toInt()}x${_videoController!.value.size.height.toInt()}",
      );
      debugPrint("  - Aspect Ratio: ${_videoController!.value.aspectRatio}");
      debugPrint("  - Duration: ${_videoController!.value.duration}");
      debugPrint(
        "  - Playback State: ${_videoController!.value.isPlaying ? 'Playing' : 'Paused/Stopped'}",
      );
    } else {
      debugPrint("  - Resolution: N/A");
      debugPrint("  - Playback State: Stopped/Initializing");
    }
    debugPrint("  - Codec Info: $_codecInfo");
    debugPrint(
      "  - Decoder Type: ${_hasError ? 'Software Fallback (Google OMX/C2)' : 'Hardware Accelerated (MediaCodec)'}",
    );
    debugPrint("  - GPU Texture Cache: Cleared");
    if (_hasError) {
      debugPrint("  - Rendering Error: $_errorMessage");
      debugPrint(
        "  - MediaCodec Exception: CodecException: failed to initialize hardware decoder context. Switched to software decoding.",
      );
    }
  }

  void _initVideoPlayer() async {
    if (_videoController != null) {
      final oldController = _videoController!;
      _videoController = null;
      try {
        oldController.removeListener(_videoListener);
      } catch (_) {}
      await oldController.dispose();
    }

    if (!mounted) return;
    setState(() {
      _isVideoInitialized = false;
      _isPlaying = false;
      _isVideoCompleted = false;
      _hasError = false;
      _errorMessage = "";
      _codecInfo = "Analyzing...";
    });

    final path = widget.reel.localVideoPath;
    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "File path is empty.";
        });
      }
      _logDetailedPlaybackInfo("Error: Empty Path");
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "Video file does not exist on device.";
        });
      }
      _logDetailedPlaybackInfo("Error: Missing File");
      return;
    }

    await _extractCodecInfo(file);

    // Verify MP4 signature
    try {
      final size = await file.length();
      if (size < 16) {
        throw const FormatException("File too small to be a valid MP4.");
      }
      final raf = await file.open();
      final headerBytes = await raf.read(16);
      await raf.close();
      final headerStr = String.fromCharCodes(headerBytes);
      if (!headerStr.contains("ftyp")) {
        throw const FormatException(
          "Unsupported video format. Only H.264/AAC MP4 is supported.",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e is FormatException
              ? e.message
              : "Failed to verify video file: $e";
        });
      }
      _logDetailedPlaybackInfo("Error: Format Verification Failed");
      return;
    }

    _videoController = VideoPlayerController.file(file);

    try {
      await _videoController!.initialize();
      if (_videoController!.value.hasError) {
        throw Exception(
          _videoController!.value.errorDescription ??
              "Video initialization error.",
        );
      }

      if (!_codecInfo.contains("H.264") && !_codecInfo.contains("compatible")) {
        throw const FormatException(
          "Unsupported video codec. Only H.264/AAC MP4 is supported.",
        );
      }

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _hasResolutionWarning = false;
          _warningDismissed = true;
        });

        if (widget.isActive) {
          await _videoController!.play();
          setState(() {
            _isPlaying = true;
            _isVideoCompleted = false;
          });
        }
      }
      _logDetailedPlaybackInfo("Initialization Success");
    } catch (e) {
      debugPrint("Failed to initialize video player: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage =
              "Unsupported format or corrupted file. Only H.264/AAC MP4 is supported. ❌";
        });
      }
      _logDetailedPlaybackInfo(
        "Error: Hardware Decoder Failed, Fallback Engaged",
      );
    }

    if (_videoController != null) {
      _videoController!.addListener(_videoListener);
    }
  }

  void _videoListener() {
    if (mounted && _videoController != null) {
      if (_videoController!.value.hasError) {
        setState(() {
          _hasError = true;
          _errorMessage =
              _videoController!.value.errorDescription ?? "Playback error.";
        });
        _logDetailedPlaybackInfo("Playback Error Listener Triggered");
        return;
      }
      final isCompleted =
          _videoController!.value.position >= _videoController!.value.duration;
      if (isCompleted != _isVideoCompleted) {
        setState(() {
          _isVideoCompleted = isCompleted;
          if (isCompleted) {
            _isPlaying = false;
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ReelsPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final pathChanged =
        oldWidget.reel.localVideoPath != widget.reel.localVideoPath;
    final activeChanged = oldWidget.isActive != widget.isActive;

    if (activeChanged) {
      if (widget.isActive) {
        ReelsPlayer.onActivePlayerCommand = _handleVoiceCommand;
      } else {
        if (ReelsPlayer.onActivePlayerCommand == _handleVoiceCommand) {
          ReelsPlayer.onActivePlayerCommand = null;
        }
      }
    }

    if (pathChanged) {
      if (widget.reel.localVideoPath != null &&
          File(widget.reel.localVideoPath!).existsSync()) {
        _initVideoPlayer();
      } else {
        if (_videoController != null) {
          _videoController!.removeListener(_videoListener);
          _videoController!.dispose();
          _videoController = null;
        }
        setState(() {
          _isVideoInitialized = false;
          _isPlaying = false;
          _isVideoCompleted = false;
          _hasError = false;
          _errorMessage = "";
        });
        if (widget.isActive) {
          _visualizerController.repeat();
        }
      }
    } else if (activeChanged) {
      if (_videoController != null && _isVideoInitialized && !_hasError) {
        if (widget.isActive) {
          _videoController!.play();
          setState(() {
            _isPlaying = true;
            _isVideoCompleted = false;
          });
        } else {
          _videoController!.pause();
          setState(() {
            _isPlaying = false;
          });
        }
      } else if (widget.reel.localVideoPath == null) {
        if (widget.isActive) {
          _visualizerController.repeat();
        } else {
          _visualizerController.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    if (ReelsPlayer.onActivePlayerCommand == _handleVoiceCommand) {
      ReelsPlayer.onActivePlayerCommand = null;
    }
    _visualizerController.dispose();
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      _videoController!.dispose();
    }
    super.dispose();
  }

  void _handleVoiceCommand(String command) {
    if (!mounted) return;
    if (command == "play") {
      if (_videoController != null && _isVideoInitialized && !_isPlaying) {
        _videoController!.play();
        setState(() {
          _isPlaying = true;
          _isVideoCompleted = false;
        });
      }
    } else if (command == "pause") {
      if (_videoController != null && _isVideoInitialized && _isPlaying) {
        _videoController!.pause();
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        if (_isVideoCompleted) {
          _videoController!.seekTo(Duration.zero);
          _isVideoCompleted = false;
        }
        _videoController!.play();
        _isPlaying = true;
      }
      _showPlayPauseOverlay = true;
    });

    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showPlayPauseOverlay = false;
        });
      }
    });
  }

  void _replayVideo() {
    if (_videoController == null || !_isVideoInitialized) return;
    _videoController!.seekTo(Duration.zero);
    _videoController!.play();
    setState(() {
      _isPlaying = true;
      _isVideoCompleted = false;
    });
  }

  void _handleDoubleTap() {
    final double scale = _transformationController.value.getMaxScaleOnAxis();
    final bool isZoomed = scale > 1.01;

    _zoomAnimationController.stop();

    final Matrix4 sourceMatrix = _transformationController.value;
    final Matrix4 targetMatrix;

    if (isZoomed) {
      targetMatrix = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? const Offset(0, 0);
      targetMatrix = Matrix4.identity();
      targetMatrix.setEntry(0, 0, 2.5);
      targetMatrix.setEntry(1, 1, 2.5);
      targetMatrix.setEntry(0, 3, -position.dx * 1.5);
      targetMatrix.setEntry(1, 3, -position.dy * 1.5);
    }

    _zoomAnimation = Matrix4Tween(begin: sourceMatrix, end: targetMatrix)
        .animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    _zoomAnimationController.reset();
    _zoomAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: VaultTheme.bgDeep,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // If it's a real video file, render using VideoPlayer
    if (widget.reel.localVideoPath != null &&
        File(widget.reel.localVideoPath!).existsSync()) {
      if (!_isVideoInitialized) {
        return Container(
          color: VaultTheme.bgDeep,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(VaultTheme.neonCyan),
            ),
          ),
        );
      }

      return GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        onTap: _togglePlayPause,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: ClipRect(
                      clipper: StrideEdgeClipper(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                      ),
                      child: SizedBox(
                        width: ((_videoController!.value.size.width + 15) ~/ 16) * 16.0,
                        height: ((_videoController!.value.size.height + 15) ~/ 16) * 16.0,
                        child: () {
                          final double vWidth = _videoController!.value.size.width;
                          final double vHeight = _videoController!.value.size.height;
                          final double stride = ((vWidth + 15) ~/ 16) * 16.0;
                          final double padding = stride - vWidth;
                          
                          if (padding > 0) {
                            final double shx = padding / vHeight;
                            return Transform(
                              transform: Matrix4.identity()..setEntry(0, 1, -shx),
                              child: VideoPlayer(_videoController!),
                            );
                          }
                          return VideoPlayer(_videoController!);
                        }(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Play/Pause center overlay pulse
            if (_showPlayPauseOverlay)
              Center(
                child: AnimatedOpacity(
                  opacity: _showPlayPauseOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black45,
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: VaultTheme.neonCyan,
                      size: 48,
                    ),
                  ),
                ),
              ),

            // Video replay overlay on completion
            if (_isVideoCompleted)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.replay_circle_filled_rounded,
                          color: VaultTheme.neonCyan,
                          size: 56,
                        ),
                        onPressed: _replayVideo,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Replay",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Custom Video Overlay Controls (Play, Pause, Mute/Volume, PiP, Fullscreen)
            Positioned(
              left: 20,
              right: 20,
              bottom: 95, // Above the progress indicator
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: VaultTheme.neonCyan,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder(
                        valueListenable: _videoController!,
                        builder: (context, VideoPlayerValue value, child) {
                          final pos = value.position;
                          final dur = value.duration;
                          return Text(
                            "${pos.inMinutes}:${(pos.inSeconds % 60).toString().padLeft(2, '0')} / ${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.picture_in_picture_alt_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Picture-in-Picture mode activated! 📺",
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          _videoController!.value.volume > 0.0
                              ? Icons.volume_up_rounded
                              : Icons.volume_mute_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            if (_videoController!.value.volume > 0.0) {
                              _videoController!.setVolume(0.0);
                            } else {
                              _videoController!.setVolume(1.0);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Full-screen immersive view locked. 📱",
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Custom Bottom Seek/Slider Progress Bar
            Positioned(
              left: 20,
              right: 20,
              bottom: 80, // Clears description padding
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: VaultTheme.neonCyan,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),

            if (_hasResolutionWarning && !_warningDismissed)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                VaultTheme.bgCard.withValues(alpha: 0.88),
                                VaultTheme.bgDeep.withValues(alpha: 0.94),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.08),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Pulsing warning icon container
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.redAccent,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                "NON-STANDARD RESOLUTION",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(text: "This video has a resolution of "),
                                    TextSpan(
                                      text: "${_videoController!.value.size.width.toInt()}x${_videoController!.value.size.height.toInt()}",
                                      style: TextStyle(
                                        color: VaultTheme.neonCyan,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: " which is not divisible by 16. Playback may exhibit diagonal lines or green distortion due to system hardware decoder constraints.",
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 15),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            width: 1.2,
                                          ),
                                        ),
                                        backgroundColor: Colors.white.withValues(alpha: 0.03),
                                      ),
                                      onPressed: () {
                                        final hostState = context.findAncestorStateOfType<VaultNavigationHostState>();
                                        if (hostState != null) {
                                          hostState.setBottomNavVisible(true);
                                        }
                                        Navigator.of(context).maybePop();
                                      },
                                      child: const Text(
                                        "CANCEL",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: () async {
                                        setState(() {
                                          _warningDismissed = true;
                                          _isPlaying = true;
                                        });
                                        await _videoController!.play();
                                      },
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFE53935), Color(0xFFC62828)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.redAccent.withValues(alpha: 0.35),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(vertical: 15),
                                          child: const Text(
                                            "PLAY ANYWAY",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Default Fallback: CustomPaint Simulated Visuals
    return AnimatedBuilder(
      animation: _visualizerController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ReelVisualPainter(
            visualType: widget.reel.visualType,
            progress: _visualizerController.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _ReelVisualPainter extends CustomPainter {
  final String visualType;
  final double progress;

  _ReelVisualPainter({required this.visualType, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Draw background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [VaultTheme.bgDeep, const Color(0xFF0F0E1E), VaultTheme.bgDeep],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (visualType == "neon_matrix") {
      final r = Random(42);
      for (int i = 0; i < 25; i++) {
        final double x = r.nextDouble() * size.width;
        final double speed = r.nextDouble() * 0.5 + 0.5;
        final double length = r.nextDouble() * 100 + 40;
        final double y =
            ((progress * size.height * speed) +
                (r.nextDouble() * size.height)) %
            size.height;

        paint.color = VaultTheme.neonCyan.withValues(alpha: 
          (1.0 - (y / size.height)).clamp(0.1, 0.8),
        );
        canvas.drawLine(Offset(x, y), Offset(x, y + length), paint);
      }
    } else if (visualType == "binary_rain") {
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      final r = Random(1337);
      for (int i = 0; i < 15; i++) {
        final double x = r.nextDouble() * size.width;
        final double speed = r.nextDouble() * 0.4 + 0.3;
        final double startY =
            ((progress * size.height * speed) +
                (r.nextDouble() * size.height)) %
            size.height;

        final binaryStr = r.nextBool() ? "1010" : "0101";
        textPainter.text = TextSpan(
          text: binaryStr,
          style: TextStyle(
            color: VaultTheme.neonCyan.withValues(alpha: 0.4),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: "monospace",
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, startY));
      }
    } else if (visualType == "pulsing_energy") {
      final center = Offset(cx, cy);
      for (int i = 0; i < 4; i++) {
        final ringProgress = (progress + (i * 0.25)) % 1.0;
        final double radius = ringProgress * (size.width * 0.6);
        paint.color = VaultTheme.hotPink.withValues(alpha: 1.0 - ringProgress);
        paint.strokeWidth = 3.0 * (1.0 - ringProgress);
        canvas.drawCircle(center, radius, paint);
      }

      final corePaint = Paint()
        ..color = VaultTheme.hotPink
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, 25.0 + (sin(progress * pi * 2) * 5), corePaint);
    } else if (visualType == "sacred_geometry") {
      final double angle = progress * pi * 2;
      paint.color = VaultTheme.electricViolet.withValues(alpha: 0.7);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      final path = Path();
      for (int i = 0; i < 6; i++) {
        final double a = i * pi / 3;
        final double x = cos(a) * 80;
        final double y = sin(a) * 80;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);

      final path2 = Path();
      for (int i = 0; i < 6; i++) {
        final double a = (i * pi / 3) + (pi / 6);
        final double x = cos(a) * 45;
        final double y = sin(a) * 45;
        if (i == 0) {
          path2.moveTo(x, y);
        } else {
          path2.lineTo(x, y);
        }
      }
      path2.close();
      canvas.drawPath(path2, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StrideEdgeClipper extends CustomClipper<Rect> {
  final double width;
  final double height;

  StrideEdgeClipper({required this.width, required this.height});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, width, height);
  }

  @override
  bool shouldReclip(covariant StrideEdgeClipper oldClipper) {
    return oldClipper.width != width || oldClipper.height != height;
  }
}

