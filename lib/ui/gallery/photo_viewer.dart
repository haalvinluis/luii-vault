import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/photo_model.dart';
import '../../core/theme.dart';

class PhotoViewer extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;
  final Function(String photoId) onDelete;

  const PhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlays = true;
  
  // Track zoom scale to lock PageView swiping when zoomed in
  double _currentScale = 1.0;
  late List<TransformationController> _transformationControllers;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationControllers = List.generate(
      widget.photos.length,
      (_) => TransformationController(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _transformationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleZoomChanged(double scale) {
    if (scale != _currentScale) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _deleteCurrentPhoto() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VaultTheme.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Photo", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to permanently delete this photo from your vault?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.pop(context); // Dismiss dialog
              
              final deletedId = widget.photos[_currentIndex].id;
              widget.onDelete(deletedId);

              if (widget.photos.length <= 1) {
                // No photos left, close viewer
                Navigator.pop(context);
              } else {
                // Remove deleted photo locally and update page index
                setState(() {
                  _transformationControllers[_currentIndex].dispose();
                  _transformationControllers.removeAt(_currentIndex);
                  widget.photos.removeAt(_currentIndex);
                  
                  if (_currentIndex >= widget.photos.length) {
                    _currentIndex = widget.photos.length - 1;
                  }
                });
                _pageController.jumpToPage(_currentIndex);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiplePhotos = widget.photos.length > 1;
    // Lock PageView swiping when zoomed in
    final ScrollPhysics physics = (_currentScale > 1.0 || !hasMultiplePhotos)
        ? const NeverScrollableScrollPhysics()
        : const BouncingScrollPhysics();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen PageView for horizontal swiping
          GestureDetector(
            onTap: () {
              setState(() {
                _showOverlays = !_showOverlays;
              });
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              physics: physics,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _currentScale = 1.0;
                });
              },
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                final controller = _transformationControllers[index];

                return Center(
                  child: InteractiveViewer(
                    transformationController: controller,
                    minScale: 1.0,
                    maxScale: 4.0,
                    onInteractionUpdate: (details) {
                      // Extract scale factor from TransformationController matrix
                      final scale = controller.value.getMaxScaleOnAxis();
                      _handleZoomChanged(scale);
                    },
                    onInteractionEnd: (details) {
                      final scale = controller.value.getMaxScaleOnAxis();
                      _handleZoomChanged(scale);
                    },
                    child: GestureDetector(
                      onDoubleTapDown: (details) {
                        // Double tap zoom shortcut
                        if (controller.value != Matrix4.identity()) {
                          setState(() {
                            controller.value = Matrix4.identity();
                            _currentScale = 1.0;
                          });
                        } else {
                          final position = details.localPosition;
                          setState(() {
                            controller.value = Matrix4.identity()
                              ..translate(-position.dx * 1.5, -position.dy * 1.5)
                              ..scale(2.5);
                            _currentScale = 2.5;
                          });
                        }
                      },
                      child: photo.localFilePath != null
                          ? Image.file(
                              File(photo.localFilePath!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: VaultTheme.bgDeep,
                              child: const Center(
                                child: Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white24),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Header Overlay (Back & Delete)
          if (_showOverlays)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.photos[_currentIndex].title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: _deleteCurrentPhoto,
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),

          // Footer Vibe tagging overlay panel
          if (_showOverlays)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "AI Vibe Tagging Analysis",
                          style: TextStyle(
                            color: VaultTheme.neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          widget.photos[_currentIndex].creationDate,
                          style: const TextStyle(color: VaultTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.photos[_currentIndex].tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Text(
                            "#$tag",
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

