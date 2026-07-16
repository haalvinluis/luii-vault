import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static String _documentsPath = "";

  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _documentsPath = directory.path;
      debugPrint("Storage Service initialized with dynamic documents path: $_documentsPath");
      StorageService().startWatchingDirectories();
    } catch (e) {
      debugPrint("Failed to initialize Storage Service documents path: $e");
    }
  }

  String get _reelsPath => '$_documentsPath/downloaded_reels.json';
  String get _songsPath => '$_documentsPath/custom_songs.json';
  String get _playlistsMetaPath => '$_documentsPath/custom_playlists.json';
  String get _customPhotosPath => '$_documentsPath/custom_photos.json';
  String get _instagramTokenPath => '$_documentsPath/instagram_token.json';

  String? loadInstagramToken() {
    try {
      final file = File(_instagramTokenPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final json = jsonDecode(content);
        return json['access_token'] as String?;
      }
    } catch (e) {
      debugPrint("Error loading instagram token: $e");
    }
    return null;
  }

  void saveInstagramToken(String? token) {
    try {
      final file = File(_instagramTokenPath);
      if (token == null) {
        if (file.existsSync()) file.deleteSync();
      } else {
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        file.writeAsStringSync(jsonEncode({'access_token': token}));
      }
    } catch (e) {
      debugPrint("Error saving instagram token: $e");
    }
  }

  final Set<String> _likedReels = {};
  final Set<String> _savedReels = {};
  final Set<String> _favoritePhotos = {};
  final Set<String> _favoritePresets = {};
  String _pinCode = "1337"; // default pin for secure vault grid

  // Persistent Custom Reels Storage
  final List<Map<String, dynamic>> _downloadedReels = [];

  List<Map<String, dynamic>> loadDownloadedReels() {
    if (_downloadedReels.isNotEmpty) return _downloadedReels;
    try {
      final file = File(_reelsPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content);
        _downloadedReels.clear();
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            _downloadedReels.add(item);
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading persistent reels: $e");
    }
    return List<Map<String, dynamic>>.from(_downloadedReels);
  }

  void saveDownloadedReel(Map<String, dynamic> reelJson) {
    _downloadedReels.insert(0, reelJson);
    try {
      final file = File(_reelsPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(_downloadedReels));
      notifyListeners();
    } catch (e) {
      debugPrint("Error saving persistent reel: $e");
    }
  }

  void deleteDownloadedReel(String id) {
    _downloadedReels.removeWhere((item) => item['id'] == id);
    try {
      final file = File(_reelsPath);
      if (file.existsSync()) {
        file.writeAsStringSync(jsonEncode(_downloadedReels));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error deleting persistent reel: $e");
    }
  }

  // Persistent Custom Songs Storage
  final List<Map<String, dynamic>> _downloadedSongs = [];

  List<Map<String, dynamic>> loadDownloadedSongs() {
    try {
      final file = File(_songsPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content);
        _downloadedSongs.clear();
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            _downloadedSongs.add(item);
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading persistent songs: $e");
    }
    return List<Map<String, dynamic>>.from(_downloadedSongs);
  }

  void saveDownloadedSong(Map<String, dynamic> songJson) {
    _downloadedSongs.insert(0, songJson);
    try {
      final file = File(_songsPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(_downloadedSongs));
      notifyListeners();
      deduplicateSongs();
    } catch (e) {
      debugPrint("Error saving persistent song: $e");
    }
  }

  void saveDownloadedSongs(List<Map<String, dynamic>> songs) {
    _downloadedSongs.clear();
    _downloadedSongs.addAll(songs);
    try {
      final file = File(_songsPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(_downloadedSongs));
      notifyListeners();
      deduplicateSongs();
    } catch (e) {
      debugPrint("Error saving persistent songs list: $e");
    }
  }

  String get _lastPlayedStatePath => '$_documentsPath/last_played_state.json';

  void saveLastPlayedState(String? songId, int positionMs) {
    try {
      final file = File(_lastPlayedStatePath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode({
        'songId': songId,
        'positionMs': positionMs,
      }));
    } catch (e) {
      debugPrint("Error saving last played state: $e");
    }
  }

  Map<String, dynamic>? loadLastPlayedState() {
    try {
      final file = File(_lastPlayedStatePath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        return jsonDecode(content) as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("Error loading last played state: $e");
    }
    return null;
  }

  void deleteDownloadedSong(String id) {
    _downloadedSongs.removeWhere((item) => item['id'] == id);
    try {
      final file = File(_songsPath);
      if (file.existsSync()) {
        file.writeAsStringSync(jsonEncode(_downloadedSongs));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error deleting persistent song: $e");
    }
  }

  bool isReelLiked(String id) => _likedReels.contains(id);
  void toggleReelLike(String id) {
    if (_likedReels.contains(id)) {
      _likedReels.remove(id);
    } else {
      _likedReels.add(id);
    }
  }

  bool isReelSaved(String id) => _savedReels.contains(id);
  void toggleReelSave(String id) {
    if (_savedReels.contains(id)) {
      _savedReels.remove(id);
    } else {
      _savedReels.add(id);
    }
  }

  bool isPhotoFavorite(String id) => _favoritePhotos.contains(id);
  void togglePhotoFavorite(String id) {
    if (_favoritePhotos.contains(id)) {
      _favoritePhotos.remove(id);
    } else {
      _favoritePhotos.add(id);
    }
  }

  bool isPresetFavorite(String name) => _favoritePresets.contains(name);
  void togglePresetFavorite(String name) {
    if (_favoritePresets.contains(name)) {
      _favoritePresets.remove(name);
    } else {
      _favoritePresets.add(name);
    }
  }

  bool verifyPin(String pin) => _pinCode == pin;
  void updatePin(String newPin) => _pinCode = newPin;

  // Persistent Playlists Metadata Storage
  final List<Map<String, dynamic>> _customPlaylistsList = [];

  List<Map<String, dynamic>> loadCustomPlaylists() {
    if (_customPlaylistsList.isNotEmpty) return _customPlaylistsList;
    
    final defaultList = [
      {'name': 'Playlist', 'emoji': '🎵', 'color': '4278241248'} // 0xFF00FFE0 color value
    ];
    
    try {
      final file = File(_playlistsMetaPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content);
        _customPlaylistsList.clear();
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            _customPlaylistsList.add(item);
          }
        }
      } else {
        _customPlaylistsList.addAll(defaultList);
      }
    } catch (e) {
      debugPrint("Error loading persistent playlists meta: $e");
      _customPlaylistsList.addAll(defaultList);
    }
    return List<Map<String, dynamic>>.from(_customPlaylistsList);
  }

  void saveCustomPlaylists(List<Map<String, dynamic>> playlists) {
    _customPlaylistsList.clear();
    _customPlaylistsList.addAll(playlists);
    try {
      final file = File(_playlistsMetaPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(_customPlaylistsList));
      notifyListeners();
    } catch (e) {
      debugPrint("Error saving persistent playlists: $e");
    }
  }

  void incrementPlayStats(String songId) {
    loadDownloadedSongs();
    final index = _downloadedSongs.indexWhere((s) => s['id'] == songId);
    if (index != -1) {
      final currentPlayCount = _downloadedSongs[index]['playCount'] as int? ?? 0;
      _downloadedSongs[index]['playCount'] = currentPlayCount + 1;
      _downloadedSongs[index]['lastPlayed'] = DateTime.now().millisecondsSinceEpoch;
      try {
        final file = File(_songsPath);
        file.writeAsStringSync(jsonEncode(_downloadedSongs));
      } catch (e) {
        debugPrint("Error updating playing stats on disk: $e");
      }
    }
  }

  // Persistent Custom Photos Storage
  final List<Map<String, dynamic>> _customPhotos = [];

  List<Map<String, dynamic>> loadCustomPhotos() {
    try {
      final file = File(_customPhotosPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content);
        _customPhotos.clear();
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            _customPhotos.add(item);
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading persistent photos: $e");
    }
    return _customPhotos;
  }

  void saveCustomPhoto(Map<String, dynamic> photoJson) {
    _customPhotos.insert(0, photoJson);
    try {
      final file = File(_customPhotosPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(_customPhotos));
    } catch (e) {
      debugPrint("Error saving persistent photo: $e");
    }
  }

  void deleteCustomPhoto(String id) {
    _customPhotos.removeWhere((item) => item['id'] == id);
    try {
      final file = File(_customPhotosPath);
      if (file.existsSync()) {
        file.writeAsStringSync(jsonEncode(_customPhotos));
      }
    } catch (e) {
      debugPrint("Error deleting persistent photo: $e");
    }
  }

  StreamSubscription<FileSystemEvent>? _importedSongsSubscription;
  StreamSubscription<FileSystemEvent>? _downloadsSubscription;
  StreamSubscription<FileSystemEvent>? _musicDirSubscription;

  void startWatchingDirectories() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final songsDir = Directory("${directory.path}/imported_songs");
      if (!songsDir.existsSync()) {
        songsDir.createSync(recursive: true);
      }
      
      _importedSongsSubscription?.cancel();
      _importedSongsSubscription = songsDir.watch().listen((event) {
        debugPrint("File watcher event in imported_songs: ${event.type} -> ${event.path}");
        _handleFileSystemEvent(event);
      });
    } catch (e) {
      debugPrint("Failed to watch imported_songs directory: $e");
    }

    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (dir.existsSync()) {
        _downloadsSubscription?.cancel();
        _downloadsSubscription = dir.watch().listen((event) {
          debugPrint("File watcher event in Download: ${event.type} -> ${event.path}");
          _handlePublicFileSystemEvent(event);
        });
      }
    } catch (_) {}

    try {
      final dir = Directory('/storage/emulated/0/Music');
      if (dir.existsSync()) {
        _musicDirSubscription?.cancel();
        _musicDirSubscription = dir.watch().listen((event) {
          debugPrint("File watcher event in Music: ${event.type} -> ${event.path}");
          _handlePublicFileSystemEvent(event);
        });
      }
    } catch (_) {}
    deduplicateSongs();
  }

  void _handleFileSystemEvent(FileSystemEvent event) async {
    final path = event.path;
    final fileName = path.split('/').last.split('\\').last;
    final ext = fileName.toLowerCase();
    if (!ext.endsWith('.mp3') && !ext.endsWith('.wav') && !ext.endsWith('.m4a') && 
        !ext.endsWith('.ogg') && !ext.endsWith('.aac') && !ext.endsWith('.flac')) {
      return;
    }

    if (event.type == FileSystemEvent.delete) {
      final file = File(_songsPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content);
        final lengthBefore = jsonList.length;
        jsonList.removeWhere((s) => s['audioUrl'] == path);
        if (jsonList.length != lengthBefore) {
          _downloadedSongs.clear();
          for (var item in jsonList) {
            if (item is Map<String, dynamic>) {
              _downloadedSongs.add(item);
            }
          }
          file.writeAsStringSync(jsonEncode(_downloadedSongs));
          notifyListeners();
        }
      }
    } else if (event.type == FileSystemEvent.create) {
      final file = File(_songsPath);
      final List<Map<String, dynamic>> songs = [];
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content);
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            songs.add(item);
          }
        }
      }
      final meta = _extractMetadataFromFilename(fileName);
      final exists = songs.any((s) {
        final t = (s['title'] as String? ?? '').toLowerCase().trim();
        final a = (s['artist'] as String? ?? '').toLowerCase().trim();
        final p = (s['audioUrl'] as String? ?? '').toLowerCase().trim();
        return p == path.toLowerCase().trim() || (t == meta['title']?.toLowerCase().trim() && a == meta['artist']?.toLowerCase().trim());
      });
      if (!exists) {
        final newSong = {
          'id': "song_${DateTime.now().millisecondsSinceEpoch}",
          'title': meta['title'],
          'artist': meta['artist'],
          'album': meta['album'],
          'playlistName': 'Playlist',
          'duration': '3:00',
          'audioUrl': path,
          'leftFreq': 200.0,
          'rightFreq': 210.0,
          'dateAdded': DateTime.now().millisecondsSinceEpoch,
          'playCount': 0,
          'lastPlayed': 0
        };
        songs.insert(0, newSong);
        saveDownloadedSongs(songs);
      }
    }
  }

  void _handlePublicFileSystemEvent(FileSystemEvent event) async {
    if (event.type != FileSystemEvent.create) return;
    
    final path = event.path;
    final file = File(path);
    final fileName = path.split('/').last.split('\\').last;
    final ext = fileName.toLowerCase();
    if (!ext.endsWith('.mp3') && !ext.endsWith('.wav') && !ext.endsWith('.m4a') && 
        !ext.endsWith('.ogg') && !ext.endsWith('.aac') && !ext.endsWith('.flac')) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!file.existsSync()) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final songsDir = Directory("${directory.path}/imported_songs");
      if (!songsDir.existsSync()) {
        songsDir.createSync(recursive: true);
      }
      final destFile = File("${songsDir.path}/$fileName");
      if (!destFile.existsSync()) {
        await file.copy(destFile.path);
      }
    } catch (e) {
      debugPrint("Failed to auto-copy public file: $e");
    }
  }

  Map<String, String> _extractMetadataFromFilename(String filename) {
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

  void deduplicateSongs() {
    try {
      final file = File(_songsPath);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);
      if (jsonList.isEmpty) return;

      final List<Map<String, dynamic>> uniqueSongs = [];
      final List<String> deletedPaths = [];
      bool modified = false;

      for (var item in jsonList) {
        if (item is! Map<String, dynamic>) continue;

        final title = (item['title'] as String? ?? '').toLowerCase().trim();
        final artist = (item['artist'] as String? ?? '').toLowerCase().trim();
        final duration = (item['duration'] as String? ?? '').trim();
        final path = (item['audioUrl'] as String? ?? '').toLowerCase().trim();

        int existingIdx = uniqueSongs.indexWhere((s) {
          final t = (s['title'] as String? ?? '').toLowerCase().trim();
          final a = (s['artist'] as String? ?? '').toLowerCase().trim();
          final d = (s['duration'] as String? ?? '').trim();
          final p = (s['audioUrl'] as String? ?? '').toLowerCase().trim();

          return (t == title && a == artist) || p == path;
        });

        if (existingIdx == -1) {
          uniqueSongs.add(item);
        } else {
          modified = true;
          final existingPlaylist = uniqueSongs[existingIdx]['playlistName'] as String? ?? 'Playlist';
          final duplicatePlaylist = item['playlistName'] as String? ?? 'Playlist';
          if (existingPlaylist == 'Playlist' && duplicatePlaylist != 'Playlist') {
            uniqueSongs[existingIdx]['playlistName'] = duplicatePlaylist;
          }

          try {
            final dupPath = item['audioUrl'] as String? ?? '';
            final keptPath = uniqueSongs[existingIdx]['audioUrl'] as String? ?? '';
            if (dupPath.isNotEmpty && dupPath != keptPath && !deletedPaths.contains(dupPath)) {
              final dupFile = File(dupPath);
              if (dupFile.existsSync()) {
                dupFile.deleteSync();
                deletedPaths.add(dupPath);
                debugPrint("Removed duplicate physical song file: $dupPath");
              }
            }
          } catch (e) {
            debugPrint("Failed to delete physical duplicate file: $e");
          }
        }
      }

      if (modified) {
        _downloadedSongs.clear();
        _downloadedSongs.addAll(uniqueSongs);
        file.writeAsStringSync(jsonEncode(_downloadedSongs));
        notifyListeners();
        debugPrint("Deduplication complete: cleaned up duplicate records.");
      }
    } catch (e) {
      debugPrint("Deduplication error: $e");
    }
  }
}
