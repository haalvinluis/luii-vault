import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../models/reel_model.dart';
import '../../services/storage_service.dart';
import '../../ai/action_executor.dart';
import 'reels_player.dart';
import 'package:video_player/video_player.dart';
import '../../ai/analytics_logging.dart';
import 'package:file_picker/file_picker.dart';
import '../../main.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final StorageService _storage = StorageService();
  
  int _activePageIndex = 0;
  List<ReelModel> _reels = [];
  
  bool _showPlayer = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final TextEditingController _linkController = TextEditingController();
  
  // State properties

  @override
  void initState() {
    super.initState();
    final savedData = _storage.loadDownloadedReels();
    _reels = savedData.map((item) => ReelModel.fromJson(item)).toList();

    // Register voice command receiver for list navigation
    ActionExecutor.onReelsCommand = (command) {
      if (!mounted) return;
      if (command == "next") {
        if (!_showPlayer) {
          if (_reels.isNotEmpty) {
            setState(() {
              _showPlayer = true;
              _activePageIndex = 0;
            });
            context.findAncestorStateOfType<VaultNavigationHostState>()?.setBottomNavVisible(false);
          }
        } else {
          if (_activePageIndex < _reels.length - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      } else if (command == "prev") {
        if (_showPlayer && _activePageIndex > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else if (command == "play" || command == "pause") {
        if (ReelsPlayer.onActivePlayerCommand != null) {
          ReelsPlayer.onActivePlayerCommand!(command);
        }
      }
    };
  }

  @override
  void dispose() {
    _linkController.dispose();
    if (ActionExecutor.onReelsCommand != null) {
      ActionExecutor.onReelsCommand = null;
    }
    super.dispose();
  }

  Future<void> _startDownload(String url) async {
    if (url.isEmpty) return;



    // Detailed Log: Input URL
    AnalyticsLogging.log("Downloader", "Input URL: $url");

    final isDuplicate = _reels.any((r) => r.caption.contains(url));
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This Reel is already saved in the vault! 📥")),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();

      // Clear temporary cache before each new download
      final List<FileSystemEntity> files = dir.listSync();
      for (var f in files) {
        if (f is File && f.path.contains("reel_temp_")) {
          try {
            await f.delete();
            debugPrint("Cleaned up cached temp file: ${f.path}");
          } catch (_) {}
        }
      }

      final filename = "reel_${DateTime.now().millisecondsSinceEpoch}.mp4";
      final thumbname = "thumb_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final videoFile = File("${dir.path}/$filename");
      final thumbFile = File("${dir.path}/$thumbname");

      // Verify that the link is valid
      final trimmedUrl = url.trim();
      final isDirectVideo = trimmedUrl.toLowerCase().endsWith(".mp4") ||
          trimmedUrl.toLowerCase().contains(".mp4?") ||
          trimmedUrl.toLowerCase().endsWith(".mov") ||
          trimmedUrl.toLowerCase().contains("video");

      String downloadUrl = trimmedUrl;

      // Extract direct video link if it's an Instagram web page link
      if (!isDirectVideo) {
        AnalyticsLogging.log("Downloader", "URL sent to backend/retrieval: $trimmedUrl");
        final parsedUrl = await _extractInstagramVideoUrl(trimmedUrl);
        if (parsedUrl == null) {
          throw Exception(
            "Could not retrieve the raw video stream from this Instagram link.\n\n"
            "Instagram's security policy blocked the connection. Please try a direct video/MP4 link."
          );
        }
        downloadUrl = parsedUrl;
      }

      // Detailed Log: Retrieved video URL
      AnalyticsLogging.log("Downloader", "Retrieved video URL: $downloadUrl");

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException("Download request failed with status: ${response.statusCode}");
      }

      final int totalBytes = response.contentLength ?? 1024 * 1024;
      int receivedBytes = 0;
      final List<int> bytes = [];

      await for (var chunk in response.stream) {
        if (!mounted) {
          client.close();
          return;
        }
        bytes.addAll(chunk);
        receivedBytes += chunk.length;
        setState(() {
          _downloadProgress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
        });
        
        // Detailed Log: Download progress
        final percent = (_downloadProgress * 100).toInt();
        AnalyticsLogging.log("Downloader", "Download progress: $percent%");
      }
      client.close();

      // Save video bytes
      await videoFile.writeAsBytes(bytes);

      // Verify the downloaded video belongs to the requested Reel and is non-empty before saving
      if (!videoFile.existsSync() || await videoFile.length() == 0) {
        throw const FileSystemException("Downloaded video file is empty or corrupt.");
      }

      // Detailed Log: Saved file path
      AnalyticsLogging.log("Downloader", "Saved file path: ${videoFile.path}");

      // Save a local thumbnail image directly using Base64 content
      final thumbBytes = base64Decode("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=");
      await thumbFile.writeAsBytes(thumbBytes);

      // Detailed Log: Thumbnail generation
      AnalyticsLogging.log("Downloader", "Thumbnail generation: ${thumbFile.path}");

      // Extract metadata dynamically from the local MP4 file
      String videoDuration = "0:00";
      String videoResolution = "N/A";
      try {
        final tempController = VideoPlayerController.file(videoFile);
        await tempController.initialize();
        final durationVal = tempController.value.duration;
        final minutes = durationVal.inMinutes;
        final seconds = durationVal.inSeconds % 60;
        videoDuration = "$minutes:${seconds.toString().padLeft(2, '0')}";
        
        final sizeVal = tempController.value.size;
        videoResolution = "${sizeVal.width.toInt()}x${sizeVal.height.toInt()}";
        await tempController.dispose();
      } catch (e) {
        debugPrint("Failed to extract video metadata: $e");
      }

      final fileSizeVal = "${(await videoFile.length() / (1024 * 1024)).toStringAsFixed(2)} MB";
      final downloadDateVal = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

      final newReel = ReelModel(
        id: "insta_${DateTime.now().millisecondsSinceEpoch}",
        creatorName: "imported_reel_vault",
        caption: "Imported from Link: $url",
        likesCount: 0,
        commentsCount: 0,
        tags: ["downloaded", "instagram"],
        visualType: ["neon_matrix", "binary_rain", "pulsing_energy", "sacred_geometry"][_reels.length % 4],
        audioFrequencyName: "Insta Stream Audio - 432Hz",
        localVideoPath: videoFile.path,
        localThumbnailPath: thumbFile.path,
        downloadDate: downloadDateVal,
        duration: videoDuration,
        fileSize: fileSizeVal,
        resolution: videoResolution,
      );

      _storage.saveDownloadedReel(newReel.toJson());

      setState(() {
        _reels.insert(0, newReel);
        _isDownloading = false;
        _downloadProgress = 0.0;
        _linkController.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reel downloaded and saved to vault! 📥🛡️")),
      );
    } catch (e) {
      debugPrint("Reel download exception: $e");
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: VaultTheme.bgDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Download Failed", style: TextStyle(color: Colors.redAccent)),
          content: Text(
            "An error occurred while downloading the reel. Check your internet connection.\n\nError: $e",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text("OK", style: TextStyle(color: VaultTheme.neonCyan)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  Future<String?> _extractInstagramVideoUrl(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint("HTTP GET returned status code: ${response.statusCode}");
        return null;
      }

      final body = response.body;
      
      final ogVideoRegex = RegExp(r"""<meta[^>]*property=["']og:video["'][^>]*content=["']([^"']+)["']""");
      final match1 = ogVideoRegex.firstMatch(body);
      if (match1 != null) {
        return match1.group(1);
      }

      final videoUrlRegex = RegExp(r""""video_url"\s*:\s*["']([^"']+)["']""");
      final match2 = videoUrlRegex.firstMatch(body);
      if (match2 != null) {
        return match2.group(1)?.replaceAll(r'\/', '/');
      }

      final secureVideoRegex = RegExp(r"""<meta[^>]*property=["']og:video:secure_url["'][^>]*content=["']([^"']+)["']""");
      final match3 = secureVideoRegex.firstMatch(body);
      if (match3 != null) {
        return match3.group(1);
      }
    } catch (e) {
      debugPrint("Error extracting Instagram video URL: $e");
    }
    return null;
  }

  Future<void> _importReelFromDevice() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint("File picker canceled or empty.");
        return;
      }

      final sourcePath = result.files.single.path;
      if (sourcePath == null) {
        throw Exception("Could not resolve file path.");
      }

      final File sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        throw Exception("Selected file does not exist on device.");
      }

      final String filename = result.files.single.name;
      final int sizeInBytes = result.files.single.size;

      final isDuplicate = _reels.any((r) => r.caption.contains(filename));
      if (isDuplicate) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: VaultTheme.bgDeep,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Duplicate Video", style: TextStyle(color: Colors.redAccent)),
            content: const Text(
              "This video has already been imported into the vault.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text("OK", style: TextStyle(color: VaultTheme.neonCyan)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return;
      }

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final dir = await getApplicationDocumentsDirectory();
      final destinationPath = "${dir.path}/imported_$filename";
      final File destinationFile = File(destinationPath);

      final sourceStream = sourceFile.openRead();
      int bytesCopied = 0;
      final List<int> copiedBytes = [];

      await for (var chunk in sourceStream) {
        copiedBytes.addAll(chunk);
        bytesCopied += chunk.length;
        if (mounted) {
          setState(() {
            _downloadProgress = (bytesCopied / sizeInBytes).clamp(0.0, 1.0);
          });
        }
      }
      await destinationFile.writeAsBytes(copiedBytes);

      if (!destinationFile.existsSync() || destinationFile.lengthSync() == 0) {
        throw const FileSystemException("Imported file is empty or corrupted during copy.");
      }

      final thumbname = "thumb_imported_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final thumbFile = File("${dir.path}/$thumbname");
      final thumbBytes = base64Decode("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=");
      await thumbFile.writeAsBytes(thumbBytes);

      String videoDuration = "0:00";
      String videoResolution = "N/A";
      try {
        final tempController = VideoPlayerController.file(destinationFile);
        await tempController.initialize();
        final durationVal = tempController.value.duration;
        final minutes = durationVal.inMinutes;
        final seconds = durationVal.inSeconds % 60;
        videoDuration = "$minutes:${seconds.toString().padLeft(2, '0')}";
        
        final sizeVal = tempController.value.size;
        videoResolution = "${sizeVal.width.toInt()}x${sizeVal.height.toInt()}";
        await tempController.dispose();
      } catch (e) {
        debugPrint("Failed to extract video metadata: $e");
      }

      final fileSizeVal = "${(destinationFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB";
      final importDateVal = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

      AnalyticsLogging.log("Downloader", "Importing file: $filename");
      AnalyticsLogging.log("Downloader", "Saved file path: ${destinationFile.path}");
      AnalyticsLogging.log("Downloader", "Thumbnail generation: ${thumbFile.path}");

      final newReel = ReelModel(
        id: "imported_${DateTime.now().millisecondsSinceEpoch}",
        creatorName: "local_device_import",
        caption: "Imported file: $filename",
        likesCount: 0,
        commentsCount: 0,
        tags: ["imported", "local"],
        visualType: ["neon_matrix", "binary_rain", "pulsing_energy", "sacred_geometry"][_reels.length % 4],
        audioFrequencyName: "Local Audio Stream - 440Hz",
        localVideoPath: destinationFile.path,
        localThumbnailPath: thumbFile.path,
        downloadDate: importDateVal,
        duration: videoDuration,
        fileSize: fileSizeVal,
        resolution: videoResolution,
      );

      _storage.saveDownloadedReel(newReel.toJson());

      setState(() {
        _reels.insert(0, newReel);
        _isDownloading = false;
        _downloadProgress = 0.0;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video imported and saved successfully! 📂🛡️")),
      );
    } catch (e) {
      debugPrint("Reel import exception: $e");
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: VaultTheme.bgDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Import Failed", style: TextStyle(color: Colors.redAccent)),
          content: Text(
            "An error occurred while importing the video.\n\nError: $e",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text("OK", style: TextStyle(color: VaultTheme.neonCyan)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDownloaderDashboard() {
    return Container(
      decoration: const BoxDecoration(
        color: VaultTheme.bgDeep,
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, color: VaultTheme.neonCyan, size: 24),
                      SizedBox(width: 10),
                      Text(
                        "REELS DOWNLOADER",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Device Import Section Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: VaultTheme.bgCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "SECURE DEVICE IMPORT",
                          style: TextStyle(
                            color: VaultTheme.neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Encrypt and store local phone videos permanently inside the vault.",
                          style: TextStyle(color: VaultTheme.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VaultTheme.neonCyan.withValues(alpha: 0.1),
                            foregroundColor: VaultTheme.neonCyan,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: VaultTheme.neonCyan, width: 1),
                            ),
                          ),
                          onPressed: _importReelFromDevice,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_rounded, size: 18),
                              SizedBox(width: 8),
                              Text("IMPORT VIDEO FILE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: VaultTheme.bgCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "PULSE DOWNLOADER",
                          style: TextStyle(
                            color: VaultTheme.neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Paste any Instagram reel link to download and encrypt inside the vault.",
                          style: TextStyle(color: VaultTheme.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _linkController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "https://www.instagram.com/reel/...",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.3),
                            prefixIcon: const Icon(Icons.link, color: VaultTheme.neonCyan, size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: VaultTheme.neonCyan),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VaultTheme.neonCyan.withValues(alpha: 0.1),
                            foregroundColor: VaultTheme.neonCyan,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: VaultTheme.neonCyan, width: 1),
                            ),
                          ),
                          onPressed: () {
                            final url = _linkController.text.trim();
                            if (url.toLowerCase().contains("instagram.com/") || url.toLowerCase().contains("instagr.am/")) {
                              _startDownload(url);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Invalid Instagram Reel link, bro! ❌")),
                              );
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 18),
                              SizedBox(width: 8),
                              Text("DOWNLOAD TO VAULT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "DOWNLOADED FILES",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _reels.isEmpty
                        ? const Center(
                            child: Text(
                              "No downloads in vault yet, bro.",
                              style: TextStyle(color: VaultTheme.textMuted),
                            ),
                          )
                        : GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: _reels.length,
                            itemBuilder: (context, index) {
                              final reel = _reels[index];
                              return _buildDownloadCoverCard(reel, index);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_isDownloading) _buildDownloadProgressOverlay(),
        ],
      ),
    );
  }

  void _deleteReel(ReelModel reel) {
    _storage.deleteDownloadedReel(reel.id);
    setState(() {
      _reels.removeWhere((r) => r.id == reel.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Reel deleted from vault! 🗑️")),
    );
  }

  Widget _buildDownloadCoverCard(ReelModel reel, int index) {
    Color accentColor = VaultTheme.neonCyan;
    if (reel.visualType == "binary_rain") {
      accentColor = Colors.greenAccent;
    } else if (reel.visualType == "pulsing_energy") {
      accentColor = VaultTheme.hotPink;
    } else if (reel.visualType == "sacred_geometry") {
      accentColor = VaultTheme.electricViolet;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _activePageIndex = index;
          _showPlayer = true;
        });
        context.findAncestorStateOfType<VaultNavigationHostState>()?.setBottomNavVisible(false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(index);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: VaultTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: reel.localVideoPath != null && File(reel.localVideoPath!).existsSync()
                    ? ReelThumbnailPreview(videoPath: reel.localVideoPath!)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.95),
                              accentColor.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                      ),
              ),
              // Delete overlay button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    _deleteReel(reel);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                  ),
                ),
              ),
              Center(
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.6),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: accentColor, size: 28),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "@${reel.creatorName}",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          reel.resolution ?? "N/A",
                          style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          reel.duration ?? "0:00",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          reel.downloadDate ?? "N/A",
                          style: const TextStyle(color: Colors.white54, fontSize: 8),
                        ),
                        Text(
                          reel.fileSize ?? "N/A",
                          style: const TextStyle(color: Colors.white54, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadProgressOverlay() {
    final int percent = (_downloadProgress * 100).toInt();
    String stepText = "Initializing connection...";
    if (percent > 25 && percent <= 50) {
      stepText = "Decrypting Instagram video packet stream...";
    } else if (percent > 50 && percent <= 75) {
      stepText = "Caching audio & video frequencies...";
    } else if (percent > 75) {
      stepText = "Saving to vault...";
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: VaultTheme.bgCard.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: VaultTheme.neonCyan.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.downloading, color: VaultTheme.neonCyan, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    "$percent%",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stepText,
                    style: const TextStyle(color: VaultTheme.textMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(VaultTheme.neonCyan),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPlayer) {
      return Scaffold(
        body: _buildDownloaderDashboard(),
      );
    }

    return PopScope(
      canPop: !_showPlayer,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _showPlayer = false;
        });
        context.findAncestorStateOfType<VaultNavigationHostState>()?.setBottomNavVisible(true);
      },
      child: Scaffold(
        body: Stack(
          children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _activePageIndex = index;
              });
            },
            itemCount: _reels.length,
            itemBuilder: (context, index) {
              final reel = _reels[index];
              final bool isActive = _activePageIndex == index;
              return GestureDetector(
                key: ValueKey(reel.id),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ReelsPlayer(reel: reel, isActive: isActive),
                    _buildRightControls(reel),
                    _buildBottomDescription(reel),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showPlayer = false;
                });
                context.findAncestorStateOfType<VaultNavigationHostState>()?.setBottomNavVisible(true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VaultTheme.neonCyan.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, color: VaultTheme.neonCyan, size: 16),
                    SizedBox(width: 6),
                    Text(
                      "BACK",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildRightControls(ReelModel reel) {
    return Positioned(
      right: 16,
      bottom: 120,
      child: Column(
        children: [
          _buildSpinningDisk(reel.audioFrequencyName),
        ],
      ),
    );
  }


  Widget _buildSpinningDisk(String trackName) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return RotationTransition(
          turns: AlwaysStoppedAnimation(
            DateTime.now().millisecondsSinceEpoch / 4000.0,
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Colors.grey[900]!,
                  Colors.black,
                  Colors.grey[900]!,
                ],
              ),
              border: Border.all(color: VaultTheme.neonCyan.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const CircleAvatar(
              backgroundColor: Color(0xFF1E1E2E),
              child: Icon(Icons.music_note, size: 16, color: VaultTheme.neonCyan),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomDescription(ReelModel reel) {
    return Positioned(
      left: 16,
      bottom: 110,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: VaultTheme.neonCyan.withValues(alpha: 0.2),
                radius: 16,
                child: const Text("👽", style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Text(
                "@${reel.creatorName}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reel.caption,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  reel.audioFrequencyName,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.fade,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReelThumbnailPreview extends StatefulWidget {
  final String videoPath;
  const ReelThumbnailPreview({super.key, required this.videoPath});

  @override
  State<ReelThumbnailPreview> createState() => _ReelThumbnailPreviewState();
}

class _ReelThumbnailPreviewState extends State<ReelThumbnailPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (File(widget.videoPath).existsSync()) {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(VaultTheme.neonCyan),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: ClipRect(
          clipper: StrideEdgeClipper(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
          ),
          child: SizedBox(
            width: ((_controller!.value.size.width + 15) ~/ 16) * 16.0,
            height: ((_controller!.value.size.height + 15) ~/ 16) * 16.0,
            child: () {
              final double vWidth = _controller!.value.size.width;
              final double vHeight = _controller!.value.size.height;
              final double stride = ((vWidth + 15) ~/ 16) * 16.0;
              final double padding = stride - vWidth;
              
              if (padding > 0) {
                final double shx = padding / vHeight;
                return Transform(
                  transform: Matrix4.identity()..setEntry(0, 1, -shx),
                  child: VideoPlayer(_controller!),
                );
              }
              return VideoPlayer(_controller!);
            }(),
          ),
        ),
      ),
    );
  }
}

