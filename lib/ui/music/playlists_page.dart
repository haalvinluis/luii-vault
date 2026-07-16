import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../models/music_model.dart';
import '../../services/storage_service.dart';
import '../../audio/binaural_engine.dart';

class PlaylistsPage extends StatefulWidget {
  final Function(int) onTabSwitch;

  const PlaylistsPage({super.key, required this.onTabSwitch});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _MusicPlaylistDetail {
  final String name;
  final String emoji;
  final Color themeColor;

  _MusicPlaylistDetail(this.name, this.emoji, this.themeColor);
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  final StorageService _storage = StorageService();
  final BinauralEngine _binaural = BinauralEngine();

  final List<SongModel> _defaultSongs = [];
  final List<_MusicPlaylistDetail> _playlists = [];
  String _playlistSearchQuery = "";

  @override
  void initState() {
    super.initState();
    _storage.addListener(_onStorageChanged);
    _loadPlaylists();
  }

  void _onStorageChanged() {
    if (mounted) {
      _loadPlaylists();
    }
  }

  @override
  void dispose() {
    _storage.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _loadPlaylists() {
    final metaList = _storage.loadCustomPlaylists();
    setState(() {
      _playlists.clear();
      for (var item in metaList) {
        final name = item['name'] as String? ?? 'Playlist';
        final emoji = item['emoji'] as String? ?? '🎵';
        final colorValueStr = item['color'] as String? ?? '4278241248';
        final colorValue = int.tryParse(colorValueStr) ?? 4278241248;
        _playlists.add(_MusicPlaylistDetail(name, emoji, Color(colorValue)));
      }
      if (!_playlists.any((p) => p.name == _selectedImportPlaylist)) {
        _selectedImportPlaylist = _playlists.isNotEmpty ? _playlists.first.name : "Playlist";
      }
    });
  }

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = "🎵";
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: VaultTheme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              title: const Text("CREATE PLAYLIST", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter playlist name...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      enabledBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                         borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                      ),
                      focusedBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                         borderSide: const BorderSide(color: VaultTheme.neonCyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Select Emoji Icon:", style: TextStyle(color: VaultTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ["🎵", "🎸", "🎹", "🎧", "⚡", "🔥", "🔮", "🌅"].map((emoji) {
                      final isSelected = selectedEmoji == emoji;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedEmoji = emoji;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? VaultTheme.neonCyan.withOpacity(0.15) : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? VaultTheme.neonCyan : Colors.transparent),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 18)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VaultTheme.neonCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Playlist name cannot be empty! ❌")),
                      );
                      return;
                    }
                    final playlists = _storage.loadCustomPlaylists();
                    if (!playlists.any((p) => p['name'].toString().toLowerCase() == name.toLowerCase())) {
                        playlists.add({
                          'name': name,
                          'emoji': selectedEmoji,
                          'color': '4278241248',
                        });
                        _storage.saveCustomPlaylists(playlists);
                        _loadPlaylists();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Created playlist '$name'! 🎉")),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("A playlist with that name already exists! ❌")),
                        );
                      }
                  },
                  child: const Text("CREATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String playlistName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: VaultTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Text("DELETE PLAYLIST", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to delete the playlist '$playlistName'? Any files in this playlist will be moved back to the default Playlist.", style: const TextStyle(color: Colors.white70, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white30, fontSize: 11)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                final playlists = _storage.loadCustomPlaylists();
                playlists.removeWhere((p) => p['name'] == playlistName);
                _storage.saveCustomPlaylists(playlists);
                
                // Move songs
                final songs = _storage.loadDownloadedSongs();
                bool updated = false;
                for (var s in songs) {
                  if (s['playlistName'] == playlistName) {
                    s['playlistName'] = 'Playlist';
                    updated = true;
                  }
                }
                if (updated) {
                  _storage.saveDownloadedSongs(songs);
                }
                
                _loadPlaylists();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Playlist '$playlistName' deleted!")),
                );
              },
              child: const Text("DELETE", style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ],
        );
      },
    );
  }

  String _selectedImportPlaylist = "Playlist";
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final TextEditingController _audioLinkController = TextEditingController();

  List<File> _localAudioFiles = [];
  bool _isScanningStorage = false;

  Future<void> _scanLocalStorage() async {
    setState(() {
      _isScanningStorage = true;
      _localAudioFiles.clear();
    });

    String errorReason = "";
    try {
      int sdkVersion = 33;
      const platform = MethodChannel('com.example.luii_vault/media_query');
      try {
        sdkVersion = await platform.invokeMethod<int>('getSDKVersion') ?? 33;
      } catch (e) {
        debugPrint("Error fetching SDK version: $e");
      }

      PermissionStatus status;
      if (Platform.isAndroid && sdkVersion >= 33) {
        status = await Permission.audio.request();
      } else {
        status = await Permission.storage.request();
      }

      if (!status.isGranted) {
        errorReason = "Permission Denied: Please enable audio/storage permissions in device settings.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorReason),
            action: SnackBarAction(
              label: "SETTINGS",
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        setState(() {
          _isScanningStorage = false;
        });
        return;
      }

      if (Platform.isAndroid) {
        try {
          final List<dynamic>? mediaStoreFiles = await platform.invokeMethod<List<dynamic>>('queryAudioFiles');
          if (mediaStoreFiles != null) {
            for (var fileData in mediaStoreFiles) {
              if (fileData is Map) {
                final path = fileData['path'] as String? ?? '';
                if (path.isNotEmpty) {
                  final file = File(path);
                  if (file.existsSync()) {
                    if (!_localAudioFiles.any((f) => f.path == file.path)) {
                      _localAudioFiles.add(file);
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint("MediaStore scan exception: $e");
        }
      }

      final List<String> pathsToScan = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Documents',
        '/sdcard/Download',
        '/sdcard/Music',
      ];

      final storageDir = Directory('/storage');
      if (storageDir.existsSync()) {
        for (var entity in storageDir.listSync()) {
          if (entity is Directory) {
            final name = entity.path.split('/').last;
            if (name != 'self' && name != 'emulated') {
              final sdDownload = Directory("${entity.path}/Download");
              if (sdDownload.existsSync()) pathsToScan.add(sdDownload.path);
              final sdMusic = Directory("${entity.path}/Music");
              if (sdMusic.existsSync()) pathsToScan.add(sdMusic.path);
            }
          }
        }
      }

      final supportedExtensions = {'.mp3', '.wav', '.m4a', '.ogg', '.aac', '.flac'};

      for (var path in pathsToScan) {
        final dir = Directory(path);
        if (dir.existsSync()) {
          try {
            final List<FileSystemEntity> entities = dir.listSync();
            for (var entity in entities) {
              if (entity is File) {
                final extIndex = entity.path.lastIndexOf('.');
                if (extIndex != -1) {
                  final ext = entity.path.substring(extIndex).toLowerCase();
                  if (supportedExtensions.contains(ext)) {
                    if (!_localAudioFiles.any((f) => f.path == entity.path)) {
                      _localAudioFiles.add(entity);
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint("Directory scan error for $path: $e");
          }
        }
      }

      if (_localAudioFiles.isEmpty) {
        errorReason = "No supported audio files found on device (.mp3, .wav, .aac, .m4a, .flac, .ogg).";
      } else {
        int importCount = 0;
        final savedSongs = _storage.loadDownloadedSongs();
        for (var file in _localAudioFiles) {
          final meta = _extractMetadataFromFilename(file);
          final title = meta["title"]!;
          
          final isDuplicate = savedSongs.any((s) => s['title'].toString().toLowerCase() == title.toLowerCase() || s['audioUrl'] == file.path);
          if (isDuplicate) continue;

          try {
            final directory = await getApplicationDocumentsDirectory();
            final songsDir = Directory("${directory.path}/imported_songs");
            if (!songsDir.existsSync()) {
              songsDir.createSync(recursive: true);
            }
            
            final filename = file.path.split('/').last.split('\\').last;
            final destFile = File("${songsDir.path}/$filename");
            
            if (!destFile.existsSync()) {
              await file.copy(destFile.path);
            }

            final index = savedSongs.length + 1;
            final leftF = 100.0 + (index * 17) % 110.0;

            final newSong = SongModel(
              id: "song_${DateTime.now().millisecondsSinceEpoch}_$importCount",
              title: title,
              artist: meta["artist"]!,
              album: meta["album"]!,
              playlistName: 'Playlist',
              duration: '3:00',
              audioUrl: destFile.path,
              leftFreq: leftF,
              rightFreq: leftF + 6.0,
            );

            _storage.saveDownloadedSong(newSong.toJson());
            importCount++;
          } catch (e) {
            debugPrint("Auto import error: $e");
          }
        }

        if (importCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Successfully scanned and imported $importCount songs! 📥🛡️")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("All scanned files are already in your Music Library. 📁")),
          );
        }
      }
    } catch (e) {
      debugPrint("Storage scan failed: $e");
      errorReason = "Scan Failed: $e";
    }

    setState(() {
      _isScanningStorage = false;
    });

    if (_localAudioFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorReason.isNotEmpty ? errorReason : "No audio files found. 📁")),
      );
    }
  }

  Map<String, String> _extractMetadataFromFilename(File file) {
    String filename = file.path.split('/').last.split('\\').last;
    try {
      filename = Uri.decodeComponent(filename);
    } catch (_) {}
    final dotIndex = filename.lastIndexOf('.');
    String baseName = (dotIndex != -1) ? filename.substring(0, dotIndex) : filename;
    String title = baseName;
    String artist = "Local Artist";
    String album = "Local Album";

    if (baseName.contains(" - ")) {
      final parts = baseName.split(" - ");
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts[1].trim();
      }
    } else if (baseName.contains("-")) {
      final parts = baseName.split("-");
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts[1].trim();
      }
    }
    title = title.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isNotEmpty) {
      title = title.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');
    } else {
      title = "Unknown Song";
    }
    artist = artist.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (artist.isNotEmpty) {
      artist = artist.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');
    } else {
      artist = "Local Artist";
    }
    return {
      "title": title,
      "artist": artist,
      "album": album,
    };
  }

  Future<void> _handleFileImport(File file, String playlistName) async {
    try {
      final meta = _extractMetadataFromFilename(file);
      final title = meta["title"]!;
      
      final savedSongs = _storage.loadDownloadedSongs();
      final existingIndex = savedSongs.indexWhere((s) => s['title'].toString().toLowerCase() == title.toLowerCase() || s['audioUrl'] == file.path);
      if (existingIndex != -1) {
        savedSongs[existingIndex]['playlistName'] = playlistName;
        _storage.saveDownloadedSongs(savedSongs);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Added '$title' to playlist '$playlistName'! 📥🛡️")),
        );
        return;
      }

      // Copy file to local vault directory
      final directory = await getApplicationDocumentsDirectory();
      final songsDir = Directory("${directory.path}/imported_songs");
      if (!songsDir.existsSync()) {
        songsDir.createSync(recursive: true);
      }
      
      // Clean filename
      final filename = file.path.split('/').last.split('\\').last;
      final destFile = File("${songsDir.path}/$filename");
      
      // Perform the copy operation
      await file.copy(destFile.path);

      // Extract duration dynamically using video_player
      String durationText = "3:00";
      final controller = VideoPlayerController.file(destFile);
      try {
        await controller.initialize();
        final duration = controller.value.duration;
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        durationText = "$minutes:${seconds.toString().padLeft(2, '0')}";
        await controller.dispose();
      } catch (e) {
        debugPrint("Error loading duration: $e");
        try { await controller.dispose(); } catch (_) {}
      }

      // Calculate file size
      final sizeInBytes = destFile.lengthSync();
      final sizeInMB = (sizeInBytes / (1024 * 1024)).toStringAsFixed(2);

      final index = savedSongs.length + 1;
      final leftF = 100.0 + (index * 17) % 110.0;

      final newSong = SongModel(
        id: "song_${DateTime.now().millisecondsSinceEpoch}",
        title: title,
        artist: meta["artist"]!,
        album: meta["album"]!,
        playlistName: playlistName,
        duration: durationText,
        audioUrl: destFile.path, // Save the copied path!
        leftFreq: leftF,
        rightFreq: leftF + 6.0,
      );

      _storage.saveDownloadedSong(newSong.toJson());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Imported '$title' ($sizeInMB MB, $durationText) successfully! 📥🛡️")),
      );

      setState(() {
        _localAudioFiles.removeWhere((f) => f.path == file.path);
      });

    } catch (e) {
      debugPrint("Import failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to import song: $e ❌")),
      );
    }
  }

  Future<void> _importScannedFile(File file) async {
    await _handleFileImport(file, _selectedImportPlaylist);
    _loadPlaylists();
    _openPlaylistDetails(_playlists.firstWhere((p) => p.name == _selectedImportPlaylist));
  }

  void _showLocalPickerForPlaylist(BuildContext context, String category, StateSetter parentSetState) async {
    await _scanLocalStorage();
    
    if (_localAudioFiles.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: VaultTheme.bgDeep,
          title: const Text("No Audio Files Found", style: TextStyle(color: Colors.white, fontSize: 16)),
          content: const Text(
            "Please make sure you have audio files in your phone's 'Download' or 'Music' folder.",
            style: TextStyle(color: VaultTheme.textMuted, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: VaultTheme.neonCyan)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: VaultTheme.bgDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "CHOOSE FILE TO ADD TO ${category.toUpperCase()}",
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _localAudioFiles.length,
                  itemBuilder: (context, index) {
                    final file = _localAudioFiles[index];
                    final filename = file.path.split('/').last.split('\\').last;
                    return ListTile(
                      dense: true,
                      title: Text(filename, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(file.path, style: const TextStyle(color: VaultTheme.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: VaultTheme.neonCyan, size: 20),
                      onTap: () async {
                        await _importScannedFileToCategory(file, category);
                        Navigator.pop(context);
                        parentSetState(() {});
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importScannedFileToCategory(File file, String category) async {
    await _handleFileImport(file, category);
    _loadPlaylists();
  }

  List<SongModel> _getSongsForPlaylist(String playlistName) {
    final savedData = _storage.loadDownloadedSongs();
    return savedData
        .map((item) => SongModel.fromJson(item))
        .where((song) => song.playlistName == playlistName)
        .toList();
  }

  void _startAudioDownload(String url) {
    if (url.isEmpty) return;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _downloadProgress += 0.1;
        if (_downloadProgress >= 1.0) {
          _downloadProgress = 1.0;
          timer.cancel();
          _finalizeAudioDownload(url);
        }
      });
    });
  }

  void _finalizeAudioDownload(String url) {
    final list = _getSongsForPlaylist(_selectedImportPlaylist);
    final index = list.length + 1;
    final leftF = 100.0 + (index * 17) % 110.0;
    
    // Extract filename if local path or url
    String title = "Audio Stream #$index";
    if (url.contains("/")) {
      final parts = url.split("/");
      if (parts.isNotEmpty) {
        final last = parts.last.split("?").first;
        if (last.isNotEmpty) title = last;
      }
    }

    final newSong = SongModel(
      id: "song_${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      artist: "imported_pulse_vault",
      playlistName: _selectedImportPlaylist,
      duration: "3:10",
      audioUrl: url,
      leftFreq: leftF,
      rightFreq: leftF + 6.0,
    );

    _storage.saveDownloadedSong(newSong.toJson());

    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _audioLinkController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved '$title' to $_selectedImportPlaylist! 📥🛡️")),
    );
    
    // Switch to playlist list details automatically
    _openPlaylistDetails(_playlists.firstWhere((p) => p.name == _selectedImportPlaylist));
  }

  String _calculatePlaylistDuration(List<SongModel> songsList) {
    int totalSeconds = 0;
    for (var song in songsList) {
      final parts = song.duration.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        totalSeconds += (minutes * 60) + seconds;
      }
    }
    final totalMinutes = totalSeconds ~/ 60;
    final remainingSeconds = totalSeconds % 60;
    return "$totalMinutes min ${remainingSeconds.toString().padLeft(2, '0')} s";
  }

  void _showRenamePlaylistDialog(String oldName) {
    final nameController = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: VaultTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Text("RENAME PLAYLIST", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter new name...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              enabledBorder: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: const BorderSide(color: VaultTheme.neonCyan),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VaultTheme.neonCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  if (newName.toLowerCase() == oldName.toLowerCase()) {
                    Navigator.pop(context);
                    return;
                  }
                  
                  final playlists = _storage.loadCustomPlaylists();
                  final isDuplicate = playlists.any((p) => p['name'].toString().toLowerCase() == newName.toLowerCase());
                  if (isDuplicate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("A playlist with that name already exists! ❌")),
                    );
                    return;
                  }
                  
                  final index = playlists.indexWhere((p) => p['name'] == oldName);
                  if (index != -1) {
                    playlists[index]['name'] = newName;
                    _storage.saveCustomPlaylists(playlists);
                  }

                  final songs = _storage.loadDownloadedSongs();
                  bool songsUpdated = false;
                  for (var s in songs) {
                    if (s['playlistName'] == oldName) {
                      s['playlistName'] = newName;
                      songsUpdated = true;
                    }
                  }
                  if (songsUpdated) {
                    _storage.saveDownloadedSongs(songs);
                  }

                  _loadPlaylists();
                  Navigator.pop(context); // Close rename dialog
                  Navigator.pop(context); // Close sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Playlist renamed to '$newName'! 🎉")),
                  );
                }
              },
              child: const Text("SAVE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveOrDeleteDialog(SongModel song, StateSetter setSheetState) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: VaultTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Text("MANAGE SONG", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          content: Text("Do you want to remove '${song.title}' from this playlist, or delete it permanently from the Vault?", style: const TextStyle(color: Colors.white70, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white30, fontSize: 11)),
            ),
            if (song.playlistName != "Playlist")
              TextButton(
                onPressed: () {
                  final songs = _storage.loadDownloadedSongs();
                  final index = songs.indexWhere((s) => s['id'] == song.id);
                  if (index != -1) {
                    songs[index]['playlistName'] = 'Playlist';
                    _storage.saveDownloadedSongs(songs);
                  }
                  _loadPlaylists();
                  setSheetState(() {});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Removed '${song.title}' from this playlist.")),
                  );
                },
                child: const Text("REMOVE ONLY", style: TextStyle(color: VaultTheme.neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                _storage.deleteDownloadedSong(song.id);
                try {
                  final f = File(song.audioUrl);
                  if (f.existsSync()) f.deleteSync();
                } catch (_) {}
                
                _loadPlaylists();
                setSheetState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Track deleted permanently from vault.")),
                );
              },
              child: const Text("DELETE PERMANENTLY", style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ],
        );
      },
    );
  }

  void _openPlaylistDetails(_MusicPlaylistDetail playlist) {
    String songSearchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final songs = _getSongsForPlaylist(playlist.name);
            final filteredSongs = songs.where((s) => 
              s.title.toLowerCase().contains(songSearchQuery.toLowerCase()) || 
              s.artist.toLowerCase().contains(songSearchQuery.toLowerCase())
            ).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: VaultTheme.bgDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: Color(0x20FFFFFF), width: 1.5)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (playlist.name != "Playlist")
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: VaultTheme.neonCyan, size: 18),
                            onPressed: () {
                              _showRenamePlaylistDialog(playlist.name);
                            },
                          )
                        else
                          const SizedBox(width: 40),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(playlist.emoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "${playlist.name.toUpperCase()} PLAYLIST",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (playlist.name != "Playlist")
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              _showDeleteConfirmationDialog(playlist.name);
                            },
                          )
                        else
                          const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${songs.length} audio tracks • ${_calculatePlaylistDuration(songs)}",
                    style: const TextStyle(color: VaultTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  
                  // Play All & Shuffle Buttons
                  if (songs.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: playlist.themeColor.withOpacity(0.15),
                            foregroundColor: playlist.themeColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: playlist.themeColor, width: 1),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text("PLAY ALL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            _binaural.setQueue(songs, songs.first);
                            Navigator.pop(context);
                            widget.onTabSwitch(3);
                          },
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.05),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
                            ),
                          ),
                          icon: const Icon(Icons.shuffle_rounded, size: 16),
                          label: const Text("SHUFFLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            final shuffledSongs = List<SongModel>.from(songs)..shuffle();
                            _binaural.setQueue(shuffledSongs, shuffledSongs.first);
                            Navigator.pop(context);
                            widget.onTabSwitch(3);
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: playlist.themeColor.withOpacity(0.15),
                      foregroundColor: playlist.themeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: playlist.themeColor, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text("IMPORT AUDIO TO THIS PLAYLIST", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    onPressed: () {
                      _showLocalPickerForPlaylist(context, playlist.name, setSheetState);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Search songs field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: "Search songs inside playlist...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        prefixIcon: const Icon(Icons.search_rounded, color: VaultTheme.textMuted, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: VaultTheme.neonCyan, width: 1),
                        ),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          songSearchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: filteredSongs.isEmpty
                        ? const Center(
                            child: Text(
                              "No tracks match your search query.",
                              style: TextStyle(color: VaultTheme.textMuted, fontSize: 13),
                            ),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredSongs.length,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              setSheetState(() {
                                final song = filteredSongs.removeAt(oldIndex);
                                filteredSongs.insert(newIndex, song);

                                final allSongs = _storage.loadDownloadedSongs();
                                final otherSongs = allSongs.where((s) => s['playlistName'] != playlist.name).toList();
                                
                                final playlistSongs = _getSongsForPlaylist(playlist.name);
                                final reorderedSong = playlistSongs.removeAt(oldIndex);
                                playlistSongs.insert(newIndex, reorderedSong);
                                
                                final updatedSongs = playlistSongs.map((s) => s.toJson()).toList();
                                final combined = [...updatedSongs, ...otherSongs];
                                _storage.saveDownloadedSongs(combined);
                              });
                              setState(() {});
                            },
                            itemBuilder: (context, index) {
                              final song = filteredSongs[index];
                              return Container(
                                key: ValueKey(song.id),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: playlist.themeColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: playlist.themeColor,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    song.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    style: const TextStyle(color: VaultTheme.textMuted, fontSize: 11),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white30, size: 20),
                                        onPressed: () {
                                          _showRemoveOrDeleteDialog(song, setSheetState);
                                        },
                                      ),
                                      const Icon(Icons.drag_handle_rounded, color: Colors.white30, size: 18),
                                    ],
                                  ),
                                  onTap: () {
                                    _binaural.setQueue(filteredSongs, song);
                                    Navigator.pop(context);
                                    widget.onTabSwitch(3);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.library_music_rounded, color: VaultTheme.electricViolet, size: 22),
            SizedBox(width: 8),
            Text(
              "PLAYLIST VAULT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dashboard Downloader Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VaultTheme.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.download_rounded, color: VaultTheme.neonCyan, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "ADD SONG BY LINK OR PATH",
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isDownloading)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(VaultTheme.neonCyan),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Caching sound track file to vault... ${(_downloadProgress * 100).toInt()}%",
                          style: const TextStyle(color: VaultTheme.textMuted, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _audioLinkController,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "Paste song URL or file path...",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: VaultTheme.neonCyan),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VaultTheme.neonCyan.withOpacity(0.1),
                            foregroundColor: VaultTheme.neonCyan,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: VaultTheme.neonCyan),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            final url = _audioLinkController.text.trim();
                            if (url.isNotEmpty) {
                              _startAudioDownload(url);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Path or URL cannot be empty! ❌")),
                              );
                            }
                          },
                          child: const Text("IMPORT AUDIO TO VAULT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Local Storage Scanner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VaultTheme.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder_open_rounded, color: VaultTheme.electricViolet, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "SCAN DEVICE DOWNLOADS / MUSIC",
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isScanningStorage)
                    const Column(
                      children: [
                        CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(VaultTheme.electricViolet)),
                        SizedBox(height: 8),
                        Text("Scanning local directories...", style: TextStyle(color: VaultTheme.textMuted, fontSize: 11)),
                      ],
                    )
                  else ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VaultTheme.electricViolet.withOpacity(0.1),
                        foregroundColor: VaultTheme.electricViolet,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: VaultTheme.electricViolet),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.radar_rounded, size: 16),
                      label: const Text("SCAN PHONE FOR MUSIC FILES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _scanLocalStorage,
                    ),
                    if (_localAudioFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "FOUND FILES (TAP TO IMPORT):",
                        style: TextStyle(color: VaultTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _localAudioFiles.length,
                          itemBuilder: (context, index) {
                            final file = _localAudioFiles[index];
                            final filename = file.path.split('/').last.split('\\').last;
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.04)),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text(filename, style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(file.path, style: const TextStyle(color: VaultTheme.textMuted, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: VaultTheme.neonCyan.withOpacity(0.15),
                                    foregroundColor: VaultTheme.neonCyan,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: VaultTheme.neonCyan),
                                    ),
                                  ),
                                  onPressed: () => _importScannedFile(file),
                                  child: const Text("IMPORT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              "YOUR PLAYLISTS",
              style: TextStyle(color: VaultTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: "Search playlists...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                prefixIcon: const Icon(Icons.search_rounded, color: VaultTheme.textMuted, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: VaultTheme.neonCyan),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _playlistSearchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final filteredPlaylists = _playlists.where((p) => p.name.toLowerCase().contains(_playlistSearchQuery.toLowerCase())).toList();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: filteredPlaylists.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filteredPlaylists.length) {
                      return GestureDetector(
                        onTap: _showCreatePlaylistDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.01),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_rounded, color: Colors.white54, size: 22),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Create Playlist",
                                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final playlist = filteredPlaylists[index];
                    final songs = _getSongsForPlaylist(playlist.name);
                    return GestureDetector(
                      onTap: () => _openPlaylistDetails(playlist),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: VaultTheme.bgCard,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: playlist.themeColor.withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: playlist.themeColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(playlist.emoji, style: const TextStyle(fontSize: 16)),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlist.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${songs.length} Tracks",
                                  style: const TextStyle(color: VaultTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}
