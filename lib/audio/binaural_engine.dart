import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/constants.dart';
import '../models/music_model.dart';
import '../services/storage_service.dart';

enum BinauralRepeatMode { off, one, all }

class BinauralEngine extends ChangeNotifier {
  static final BinauralEngine _instance = BinauralEngine._internal();
  factory BinauralEngine() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentAudioUrl;
  String? _currentPlayingUrl;

  late BinauralPreset _currentPreset;
  double _baseFreq = 200.0;
  double _beatFreq = 10.0;
  bool _isPlaying = false;
  Timer? _hapticTimer;

  // Custom playback controller states
  SongModel? _activeSong;
  List<SongModel> _queue = [];
  int _currentIndex = -1;
  bool _isShuffle = false;
  final Set<String> _shuffledPlayedIds = {};
  BinauralRepeatMode _repeatMode = BinauralRepeatMode.off;
  double _volume = 1.0;
  double _preMuteVolume = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  BinauralEngine._internal() {
    _currentPreset = VaultConstants.binauralPresets.first;
    _baseFreq = _currentPreset.leftFreq;
    _beatFreq = _currentPreset.beatFreq;

    // Listen to player state changes to keep states in sync
    _audioPlayer.onPlayerStateChanged.listen((state) {
      final playing = (state == PlayerState.playing);
      if (playing != _isPlaying) {
        _isPlaying = playing;
        if (_isPlaying) {
          _startHapticPulse();
        } else {
          _stopHapticPulse();
        }
        notifyListeners();
      }
    });

    // Seek bar tracking in real time
    _audioPlayer.onDurationChanged.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
      // Periodically persist playback state every 5 seconds
      if (_activeSong != null && pos.inSeconds % 5 == 0) {
        StorageService().saveLastPlayedState(_activeSong!.id, pos.inMilliseconds);
      }
    });

    // Auto next / repeat handler on song completion
    _audioPlayer.onPlayerComplete.listen((_) {
      _handlePlaybackComplete();
    });

    // Load last played state after initialization
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadPersistedPlaybackState();
    });
  }

  // Getters
  BinauralPreset get currentPreset => _currentPreset;
  double get baseFreq => _baseFreq;
  double get beatFreq => _beatFreq;
  bool get isPlaying => _isPlaying;
  double get leftFreq => _baseFreq;
  double get rightFreq => _baseFreq + _beatFreq;

  SongModel? get activeSong => _activeSong;
  List<SongModel> get queue => _queue;
  bool get isShuffle => _isShuffle;
  BinauralRepeatMode get repeatMode => _repeatMode;
  double get volume => _volume;
  Duration get position => _position;
  Duration get duration => _duration;

  Future<void> play() async {
    _isPlaying = true;
    _startHapticPulse();
    notifyListeners();

    if (_currentAudioUrl != null && _currentAudioUrl!.isNotEmpty) {
      try {
        final sourceChanged = (_currentPlayingUrl != _currentAudioUrl);
        if (_audioPlayer.state == PlayerState.paused && !sourceChanged) {
          await _audioPlayer.resume();
        } else {
          await _audioPlayer.stop();
          _currentPlayingUrl = _currentAudioUrl;
          if (_currentAudioUrl!.startsWith("http")) {
            await _audioPlayer.play(UrlSource(_currentAudioUrl!));
          } else {
            await _audioPlayer.play(DeviceFileSource(_currentAudioUrl!));
          }
        }
        await _audioPlayer.setVolume(_volume);
      } catch (e) {
        debugPrint("Error playing audio: $e");
        _isPlaying = false;
        _stopHapticPulse();
        notifyListeners();
      }
    }
  }

  Future<void> fadeIn({Duration duration = const Duration(milliseconds: 1500)}) async {
    if (_currentAudioUrl == null || _currentAudioUrl!.isEmpty) return;
    
    _isPlaying = true;
    _startHapticPulse();
    notifyListeners();

    final double targetVolume = _volume;
    try {
      await _audioPlayer.setVolume(0.0);
      final sourceChanged = (_currentPlayingUrl != _currentAudioUrl);
      if (_audioPlayer.state == PlayerState.paused && !sourceChanged) {
        await _audioPlayer.resume();
      } else {
        await _audioPlayer.stop();
        _currentPlayingUrl = _currentAudioUrl;
        if (_currentAudioUrl!.startsWith("http")) {
          await _audioPlayer.play(UrlSource(_currentAudioUrl!));
        } else {
          await _audioPlayer.play(DeviceFileSource(_currentAudioUrl!));
        }
      }

      // Smooth step fade in
      const steps = 15;
      final stepDuration = duration.inMilliseconds ~/ steps;
      final volumeStep = targetVolume / steps;

      double currentVol = 0.0;
      for (int i = 0; i < steps; i++) {
        await Future.delayed(Duration(milliseconds: stepDuration));
        currentVol = (currentVol + volumeStep).clamp(0.0, targetVolume);
        await _audioPlayer.setVolume(currentVol);
      }
      await _audioPlayer.setVolume(targetVolume);
    } catch (e) {
      debugPrint("Error in fadeIn audio: $e");
    }
  }

  void stop() async {
    _isPlaying = false;
    _stopHapticPulse();
    _position = Duration.zero;
    notifyListeners();
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint("Error stopping audio: $e");
    }
  }

  void pause() async {
    _isPlaying = false;
    _stopHapticPulse();
    notifyListeners();
    try {
      await _audioPlayer.pause();
      if (_activeSong != null) {
        StorageService().saveLastPlayedState(_activeSong!.id, _position.inMilliseconds);
      }
    } catch (e) {
      debugPrint("Error pausing audio: $e");
    }
  }

  void togglePlay() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void setAudioUrl(String? url) {
    _currentAudioUrl = url;
    if (_isPlaying) {
      play();
    }
  }

  void setBaseFreq(double freq) {
    _baseFreq = freq;
    _updateHapticPulse();
    notifyListeners();
  }

  void setBeatFreq(double freq) {
    _beatFreq = freq;
    _updateHapticPulse();
    notifyListeners();
  }

  void selectPreset(BinauralPreset preset) {
    _currentPreset = preset;
    _baseFreq = preset.leftFreq;
    _beatFreq = preset.beatFreq;
    _updateHapticPulse();
    notifyListeners();
  }

  void selectPresetByName(String name) {
    final match = VaultConstants.binauralPresets.firstWhere(
      (p) => p.name.toLowerCase().contains(name.toLowerCase()),
      orElse: () => VaultConstants.binauralPresets.first,
    );
    selectPreset(match);
  }

  // Playback queue & seek controllers
  Future<void> setQueue(List<SongModel> songs, SongModel active) async {
    _queue = List.from(songs);
    _activeSong = active;
    _currentIndex = _queue.indexWhere((s) => s.id == active.id);
    _currentAudioUrl = active.audioUrl;
    _baseFreq = active.leftFreq;
    _beatFreq = (active.rightFreq - active.leftFreq).abs();
    StorageService().incrementPlayStats(active.id);
    await play();
  }

  Future<void> playSong(SongModel song) async {
    _activeSong = song;
    _currentAudioUrl = song.audioUrl;
    _baseFreq = song.leftFreq;
    _beatFreq = (song.rightFreq - song.leftFreq).abs();
    _shuffledPlayedIds.add(song.id);

    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
    }
    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    StorageService().incrementPlayStats(song.id);
    await play();
  }

  void _loadPersistedPlaybackState() {
    final state = StorageService().loadLastPlayedState();
    if (state != null) {
      final songId = state['songId'] as String?;
      final positionMs = state['positionMs'] as int? ?? 0;
      if (songId != null) {
        final songs = StorageService().loadDownloadedSongs();
        final songMatch = songs.firstWhere((s) {
          return s['id'] == songId;
        }, orElse: () => <String, dynamic>{});
        if (songMatch.isNotEmpty) {
          final song = SongModel.fromJson(songMatch);
          _activeSong = song;
          _currentAudioUrl = song.audioUrl;
          _baseFreq = song.leftFreq;
          _beatFreq = (song.rightFreq - song.leftFreq).abs();
          _position = Duration(milliseconds: positionMs);
          
          final source = song.audioUrl.startsWith("http")
              ? UrlSource(song.audioUrl)
              : DeviceFileSource(song.audioUrl);
          _audioPlayer.setSource(source).then((_) {
            _currentPlayingUrl = song.audioUrl;
            _audioPlayer.seek(Duration(milliseconds: positionMs));
          }).catchError((e) {
            debugPrint("Error restoring persisted audio source: $e");
          });
          notifyListeners();
        }
      }
    }
  }

  void next() {
    if (_queue.isEmpty) return;
    if (_isShuffle) {
      final unplayed = _queue.where((s) => !_shuffledPlayedIds.contains(s.id)).toList();
      if (unplayed.isEmpty) {
        if (_repeatMode == BinauralRepeatMode.all) {
          _shuffledPlayedIds.clear();
          final randomIdx = Random().nextInt(_queue.length);
          _currentIndex = randomIdx;
          playSong(_queue[_currentIndex]);
        } else {
          stop();
        }
        return;
      }
      final nextSong = unplayed[Random().nextInt(unplayed.length)];
      _currentIndex = _queue.indexWhere((s) => s.id == nextSong.id);
      playSong(nextSong);
    } else {
      if (_repeatMode == BinauralRepeatMode.all) {
        _currentIndex = (_currentIndex + 1) % _queue.length;
      } else {
        if (_currentIndex < _queue.length - 1) {
          _currentIndex = _currentIndex + 1;
        } else {
          stop();
          return;
        }
      }
      playSong(_queue[_currentIndex]);
    }
  }

  void previous() {
    if (_queue.isEmpty) return;
    if (_isShuffle) {
      if (_shuffledPlayedIds.isNotEmpty) {
        _shuffledPlayedIds.remove(_activeSong?.id);
      }
      final randomIdx = Random().nextInt(_queue.length);
      _currentIndex = randomIdx;
      playSong(_queue[_currentIndex]);
    } else {
      if (_repeatMode == BinauralRepeatMode.all) {
        _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
      } else {
        if (_currentIndex > 0) {
          _currentIndex = _currentIndex - 1;
        } else {
          _currentIndex = 0;
        }
      }
      playSong(_queue[_currentIndex]);
    }
  }

  void seek(Duration pos) async {
    try {
      await _audioPlayer.seek(pos);
    } catch (e) {
      debugPrint("Seek failed: $e");
    }
  }

  void setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      await _audioPlayer.setVolume(_volume);
    } catch (e) {
      debugPrint("Set volume failed: $e");
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    if (_repeatMode == BinauralRepeatMode.off) {
      _repeatMode = BinauralRepeatMode.one;
    } else if (_repeatMode == BinauralRepeatMode.one) {
      _repeatMode = BinauralRepeatMode.all;
    } else {
      _repeatMode = BinauralRepeatMode.off;
    }
    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    _activeSong = null;
    _currentAudioUrl = null;
    notifyListeners();
  }

  void setRepeatMode(BinauralRepeatMode mode) {
    _repeatMode = mode;
    notifyListeners();
  }

  void mute() {
    _preMuteVolume = _volume;
    setVolume(0.0);
  }

  void unmute() {
    setVolume(_preMuteVolume);
  }

  void _handlePlaybackComplete() {
    if (_repeatMode == BinauralRepeatMode.one) {
      play();
    } else {
      next();
    }
  }

  // Haptic feedbacks pulses
  void _startHapticPulse() {
    _hapticTimer?.cancel();
    if (!_isPlaying) return;

    double pulseHz = _beatFreq;
    if (pulseHz > 4.0) {
      pulseHz = pulseHz / 4.0;
    }
    pulseHz = pulseHz.clamp(0.5, 3.0);
    final intervalMs = (1000 / pulseHz).round();

    _hapticTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (_isPlaying) {
        HapticFeedback.selectionClick();
      }
    });
  }

  void _stopHapticPulse() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
  }

  void _updateHapticPulse() {
    if (_isPlaying) {
      _startHapticPulse();
    }
  }

  @override
  void dispose() {
    _stopHapticPulse();
    _audioPlayer.dispose();
    super.dispose();
  }
}
