import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/photo_model.dart';
import '../../services/storage_service.dart';
import '../../utils/image_processor.dart';
import 'photo_viewer.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final StorageService _storage = StorageService();

  bool _isUnlocked = false;
  bool _isScanning = false;
  String _activeTab = "All"; // All, Faces, Places, Vibes
  String _searchQuery = "";
  List<PhotoModel> _photos = [];

  // Face scanning glowing controller
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    
    final customList = _storage.loadCustomPhotos();
    final customPhotos = customList.map((j) => PhotoModel.fromJson(j)).toList();
    _photos = customPhotos;

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _triggerScan() {
    setState(() {
      _isScanning = true;
    });
    _scannerController.repeat(reverse: true);
    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isUnlocked = true;
        });
        _scannerController.stop();
        HapticFeedback.vibrate();
      }
    });
  }

  List<PhotoModel> _getFilteredPhotos() {
    return _photos.where((photo) {
      final matchesTab = _activeTab == "All" || photo.category == _activeTab;
      final matchesSearch = _searchQuery.isEmpty ||
          photo.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          photo.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchesTab && matchesSearch;
    }).toList();
  }

  void _showShareIntakeSimulator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 380,
              decoration: BoxDecoration(
                color: const Color(0xFF12121E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.share_rounded, color: VaultTheme.neonCyan),
                      SizedBox(width: 10),
                      Text(
                        "System Share Intake Simulator",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Simulate sharing a photo from your browser/album to LUII VAULT:",
                    style: TextStyle(color: VaultTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildShareItem(
                          title: "Sunset Surf Photo.jpg",
                          tags: ["sunset", "beach", "warm"],
                          style: "neon_sunset",
                          category: "Vibes",
                        ),
                        _buildShareItem(
                          title: "Cyberpunk Avatar Draft.png",
                          tags: ["cyberpunk", "hologram", "neon"],
                          style: "hologram_face",
                          category: "Faces",
                        ),
                        _buildShareItem(
                          title: "New Office Server Rack.jpg",
                          tags: ["office", "desk", "servers"],
                          style: "server_room",
                          category: "Places",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareItem({
    required String title,
    required List<String> tags,
    required String style,
    required String category,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Vibe Tags: #${tags.join(" #")}",
                  style: const TextStyle(color: VaultTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VaultTheme.neonCyan.withOpacity(0.15),
              foregroundColor: VaultTheme.neonCyan,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: VaultTheme.neonCyan, width: 1),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _ingestSharedPhoto(title, tags, style, category);
            },
            child: const Text("SHARE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _ingestSharedPhoto(String filename, List<String> tags, String style, String category) {
    setState(() {
      _isScanning = true;
    });
    
    // Simulate AI Tagging scan visual
    _scannerController.repeat(reverse: true);
    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        final newPhoto = PhotoModel(
          id: "photo_${DateTime.now().millisecondsSinceEpoch}",
          title: filename.replaceAll(".jpg", "").replaceAll(".png", ""),
          category: category,
          tags: tags,
          aiConfidence: {
            tags[0]: 0.98,
            if (tags.length > 1) tags[1]: 0.91,
          },
          visualStyle: style,
          creationDate: DateTime.now().toIso8601String().substring(0, 10),
        );

        setState(() {
          _photos.insert(0, newPhoto);
          _isScanning = false;
        });
        _scannerController.stop();
        HapticFeedback.vibrate();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Shared photo \"$filename\" imported & classified! 🤝😎"),
            backgroundColor: VaultTheme.bgCard,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildSecurityScreen();
    }

    final filteredList = _getFilteredPhotos();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: VaultTheme.neonCyan, size: 22),
            SizedBox(width: 8),
            Text(
              "GALLERY VAULT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded, color: VaultTheme.neonCyan, size: 20),
            onPressed: _showShareIntakeSimulator,
          ),
          IconButton(
            icon: const Icon(Icons.security, color: VaultTheme.neonCyan, size: 20),
            onPressed: () {
              setState(() {
                _isUnlocked = false;
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search vault via vibe or tag...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search, color: VaultTheme.neonCyan),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {
                          setState(() {
                            _searchQuery = "";
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF13121F),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: VaultTheme.neonCyan),
                ),
              ),
            ),
          ),
          
          // Tabs Category Selector
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ["All", "Faces", "Places", "Vibes"].map((tab) {
                final bool isActive = _activeTab == tab;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeTab = tab;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? VaultTheme.neonCyan.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? VaultTheme.neonCyan : Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: isActive ? VaultTheme.neonCyan : VaultTheme.textMuted,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Photos Grid
          Expanded(
            child: _photos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 48, color: VaultTheme.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          "No images saved yet.",
                          style: TextStyle(
                            color: VaultTheme.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 50, color: VaultTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              "No items found for \"$_searchQuery\"",
                              style: const TextStyle(color: VaultTheme.textMuted),
                            )
                          ],
                        ),
                      )
                    : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final photo = filteredList[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) => PhotoViewer(
                                photos: List.from(filteredList),
                                initialIndex: index,
                                onDelete: (photoId) {
                                  if (photo.localFilePath != null) {
                                    _storage.deleteCustomPhoto(photoId);
                                    try {
                                      final f = File(photo.localFilePath!);
                                      if (f.existsSync()) f.deleteSync();
                                      if (photo.thumbnailPath != null) {
                                        final t = File(photo.thumbnailPath!);
                                        if (t.existsSync()) t.deleteSync();
                                      }
                                    } catch (e) {
                                      debugPrint("Error deleting custom photo: $e");
                                    }
                                  }
                                  setState(() {
                                    _photos.removeWhere((p) => p.id == photoId);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Photo deleted from vault! 🗑️")),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF13121F),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Visual thumbnail painter
                              Expanded(
                                child: photo.localFilePath != null
                                    ? Image.file(
                                        File(photo.thumbnailPath ?? photo.localFilePath!),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                    : CustomPaint(
                                        painter: _GridThumbPainter(style: photo.visualStyle),
                                        child: Container(),
                                      ),
                              ),
                              // Description label
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      photo.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "#${photo.category}",
                                      style: const TextStyle(
                                        color: VaultTheme.neonCyan,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton(
            onPressed: _handleImageImport,
            backgroundColor: VaultTheme.neonCyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.add, size: 32),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _handleImageImport() async {
    final Permission permissionToCheck = Platform.isAndroid 
        ? Permission.photos 
        : Permission.photos;

    PermissionStatus status = await permissionToCheck.status;

    if (Platform.isAndroid && status.isDenied) {
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        status = PermissionStatus.granted;
      }
    }

    if (status.isGranted) {
      _showImageSourcePicker();
      return;
    }

    if (status.isPermanentlyDenied) {
      _showSettingsDialog("Permissions were permanently denied. Please enable storage and photo access in system Settings to import images.");
      return;
    }

    if (mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: VaultTheme.bgCard,
          title: const Text("Photo Library Access", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Luii Vault requires permission to access your device's photo library so you can pick and store your personal images inside the secure gallery.",
            style: TextStyle(color: VaultTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Allow", style: TextStyle(color: VaultTheme.neonCyan)),
            ),
          ],
        ),
      );

      if (proceed == true) {
        PermissionStatus requestStatus = await permissionToCheck.request();
        if (Platform.isAndroid && (requestStatus.isDenied || requestStatus.isPermanentlyDenied)) {
          requestStatus = await Permission.storage.request();
        }

        if (requestStatus.isGranted) {
          _showImageSourcePicker();
        } else if (requestStatus.isPermanentlyDenied) {
          _showSettingsDialog("Permission denied permanently. Please open system settings to enable access manually.");
        } else {
          _showPermissionDeniedSnackBar();
        }
      } else {
        _showPermissionDeniedSnackBar();
      }
    }
  }

  void _showPermissionDeniedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Import failed: Photo library access is required. ❌"),
        action: SnackBarAction(
          label: "Settings",
          textColor: VaultTheme.neonCyan,
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  void _showSettingsDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VaultTheme.bgCard,
        title: const Text("Permission Required", style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: VaultTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Settings", style: TextStyle(color: VaultTheme.neonCyan)),
          ),
        ],
      ),
    );
  }

  void _showImageSourcePicker() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: VaultTheme.bgDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0x20FFFFFF), width: 1.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "SELECT IMAGE SOURCE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: VaultTheme.neonCyan),
              title: const Text("Choose from Gallery", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickFromFiles();
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded, color: VaultTheme.electricViolet),
              title: const Text("Choose from Files", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickFromFiles();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final name = result.files.single.name;
        await _importImageFile(file, name);
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      _showError("Failed to access file browser.");
    }
  }

  Future<void> _importImageFile(File sourceFile, String originalName) async {
    setState(() {
      _isScanning = true;
    });
    _scannerController.repeat(reverse: true);
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final uuid = DateTime.now().microsecondsSinceEpoch.toString();
      
      final localPath = "${dir.path}/photo_$uuid.png";
      final thumbPath = "${dir.path}/thumb_$uuid.png";
      
      final localFile = File(localPath);
      final thumbFile = File(thumbPath);
      
      await ImageProcessor.processImage(
        inputFile: sourceFile,
        outputFile: localFile,
        thumbnailFile: thumbFile,
        maxDimension: 1080,
        thumbnailDimension: 250,
      );
      
      final size = await localFile.length();
      
      String category = "Vibes";
      List<String> tags = ["imported", "gallery"];
      
      if (originalName.toLowerCase().contains("face") || originalName.toLowerCase().contains("selfie") || originalName.toLowerCase().contains("person")) {
        category = "Faces";
        tags.add("portrait");
      } else if (originalName.toLowerCase().contains("place") || originalName.toLowerCase().contains("room") || originalName.toLowerCase().contains("office") || originalName.toLowerCase().contains("city")) {
        category = "Places";
        tags.add("scenery");
      }
      
      final newPhoto = PhotoModel(
        id: "custom_photo_$uuid",
        title: originalName.split('.').first,
        category: category,
        tags: tags,
        aiConfidence: {
          tags[0]: 0.95,
          tags[1]: 0.88,
        },
        visualStyle: "imported_image",
        creationDate: DateTime.now().toIso8601String().substring(0, 10),
        localFilePath: localPath,
        thumbnailPath: thumbPath,
        fileSize: size,
        originalName: originalName,
      );
      
      _storage.saveCustomPhoto(newPhoto.toJson());
      
      if (mounted) {
        setState(() {
          _photos.insert(0, newPhoto);
          _isScanning = false;
        });
        _scannerController.stop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Photo imported to $category! 📥")),
        );
      }
    } catch (e) {
      debugPrint("Error importing file: $e");
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        _scannerController.stop();
        _showError("Failed to save or process image. Format might be unsupported.");
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $message ❌")),
    );
  }

  Widget _buildSecurityScreen() {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dark space background
          Container(color: VaultTheme.bgDeep),
          
          // Secure layout details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(
                  Icons.lock_rounded,
                  color: VaultTheme.neonCyan,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  "VAULT",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "BIOMETRIC ENCRYPTION ACTIVE",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VaultTheme.textMuted,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 80),
                
                // Holographic scanning container
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Scanner Ring
                      Container(
                        height: 160,
                        width: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isScanning ? VaultTheme.neonCyan : Colors.white.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                      ),
                      // Animated scanning bar
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _scannerController,
                          builder: (context, child) {
                            return Positioned(
                              top: 20 + (_scannerController.value * 120),
                              child: Container(
                                width: 140,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: VaultTheme.neonCyan,
                                  boxShadow: [
                                    BoxShadow(
                                      color: VaultTheme.neonCyan.withOpacity(0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      // Scanner Target
                      Icon(
                        Icons.fingerprint_rounded,
                        color: _isScanning
                            ? VaultTheme.neonCyan
                            : Colors.white.withOpacity(0.3),
                        size: 90,
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Scan Button
                ElevatedButton(
                  onPressed: _isScanning ? null : _triggerScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VaultTheme.neonCyan.withOpacity(0.15),
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: VaultTheme.neonCyan,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _isScanning ? Colors.white12 : VaultTheme.neonCyan,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    _isScanning ? "Scanning..." : "AUTHORIZE VAULT ACCESS",
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridThumbPainter extends CustomPainter {
  final String style;

  _GridThumbPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    // Simple colored mini shapes for grid preview
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    
    final paint = Paint()
      ..color = const Color(0xFF0C0B14)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, paint);

    final itemPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (style == "neon_sunset") {
      itemPaint.color = VaultTheme.neonCyan.withOpacity(0.4);
      canvas.drawLine(Offset(0, cy + 10), Offset(size.width, cy + 10), itemPaint);
      canvas.drawCircle(Offset(cx, cy + 10), 22, Paint()..color = VaultTheme.hotPink.withOpacity(0.3)..style = PaintingStyle.fill);
    } else if (style == "server_room") {
      itemPaint.color = VaultTheme.neonCyan.withOpacity(0.4);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx - 20, cy), width: 14, height: size.height - 20), itemPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx + 20, cy), width: 14, height: size.height - 20), itemPaint);
    } else if (style == "hologram_face") {
      itemPaint.color = VaultTheme.neonCyan.withOpacity(0.4);
      canvas.drawCircle(Offset(cx, cy - 10), 12, itemPaint);
      canvas.drawLine(Offset(cx - 20, cy + 20), Offset(cx, cy), itemPaint);
      canvas.drawLine(Offset(cx + 20, cy + 20), Offset(cx, cy), itemPaint);
    } else if (style == "quantum_grid") {
      itemPaint.color = VaultTheme.neonCyan.withOpacity(0.3);
      canvas.drawCircle(Offset(cx, cy), 15, itemPaint);
      canvas.drawCircle(Offset(cx, cy), 30, itemPaint);
    } else if (style == "audio_knobs") {
      itemPaint.color = VaultTheme.electricViolet.withOpacity(0.4);
      canvas.drawLine(Offset(cx - 15, 10), Offset(cx - 15, size.height - 10), itemPaint);
      canvas.drawLine(Offset(cx + 15, 10), Offset(cx + 15, size.height - 10), itemPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx - 15, cy - 10), width: 12, height: 6), Paint()..color = VaultTheme.electricViolet..style = PaintingStyle.fill);
    } else if (style == "neon_palm") {
      itemPaint.color = VaultTheme.hotPink;
      canvas.drawLine(Offset(cx, size.height - 10), Offset(cx, cy), itemPaint);
      canvas.drawCircle(Offset(cx, cy), 12, Paint()..color = VaultTheme.neonCyan.withOpacity(0.3)..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _GridThumbPainter oldDelegate) {
    return oldDelegate.style != style;
  }
}
