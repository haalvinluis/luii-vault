import 'package:flutter/material.dart';
import '../../audio/binaural_engine.dart';
import '../../core/theme.dart';
import '../../models/music_model.dart';
import '../../services/storage_service.dart';
import 'immersive_player.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final BinauralEngine _binaural = BinauralEngine();
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _binaural.addListener(_onEngineUpdate);
  }

  void _onEngineUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _binaural.removeListener(_onEngineUpdate);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "$minutes:${twoDigits(seconds)}";
  }

  @override
  Widget build(BuildContext context) {
    final song = _binaural.activeSong;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.headphones_rounded, color: VaultTheme.electricViolet, size: 22),
            SizedBox(width: 8),
            Text(
              "PLAYER",
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
            // Wave visualizer
            ImmersivePlayer(
              leftFreq: _binaural.leftFreq,
              rightFreq: _binaural.rightFreq,
              isPlaying: _binaural.isPlaying,
            ),
            const SizedBox(height: 16),

            // Album cover layout representation
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [VaultTheme.bgCard, Color(0x30FFFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    )
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.album_rounded,
                        size: 160,
                        color: Colors.white.withOpacity(0.12),
                      ),
                      Icon(
                        Icons.music_note_rounded,
                        size: 40,
                        color: _binaural.isPlaying ? VaultTheme.neonCyan : Colors.white30,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Song Details Card
            if (song != null) ...[
              Text(
                song.title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "${song.artist} • ${song.album ?? 'Local Album'}",
                style: const TextStyle(color: VaultTheme.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: VaultTheme.electricViolet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VaultTheme.electricViolet.withOpacity(0.3)),
                  ),
                  child: Text(
                    "${song.playlistName.toUpperCase()} PLAYLIST",
                    style: const TextStyle(color: VaultTheme.electricViolet, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
              ),

              // Seek Bar & Duration Label
              const SizedBox(height: 16),
              Slider(
                value: _binaural.position.inSeconds.toDouble().clamp(0.0, _binaural.duration.inSeconds.toDouble() > 0.0 ? _binaural.duration.inSeconds.toDouble() : 1.0),
                min: 0.0,
                max: _binaural.duration.inSeconds.toDouble() > 0.0 ? _binaural.duration.inSeconds.toDouble() : 1.0,
                activeColor: VaultTheme.neonCyan,
                inactiveColor: Colors.white.withOpacity(0.05),
                onChanged: (val) {
                  _binaural.seek(Duration(seconds: val.toInt()));
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_binaural.position), style: const TextStyle(color: VaultTheme.textMuted, fontSize: 11)),
                    Text(_formatDuration(_binaural.duration), style: const TextStyle(color: VaultTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                "No Audio Track Selected",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Import your audio files in Playlists page to begin!",
                style: TextStyle(color: VaultTheme.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 28),

            // Playback Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded, 
                    color: _binaural.isShuffle ? VaultTheme.neonCyan : Colors.white30, 
                    size: 20
                  ),
                  onPressed: _binaural.toggleShuffle,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 30),
                  onPressed: _binaural.previous,
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _binaural.togglePlay,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _binaural.isPlaying ? VaultTheme.electricViolet : Colors.white.withOpacity(0.06),
                      boxShadow: _binaural.isPlaying
                          ? [
                              BoxShadow(
                                color: VaultTheme.electricViolet.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Icon(
                      _binaural.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 30),
                  onPressed: _binaural.next,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _binaural.repeatMode == BinauralRepeatMode.one 
                        ? Icons.repeat_one_rounded 
                        : Icons.repeat_rounded,
                    color: _binaural.repeatMode != BinauralRepeatMode.off ? VaultTheme.neonCyan : Colors.white30,
                    size: 20,
                  ),
                  onPressed: _binaural.toggleRepeat,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Volume Controller Slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.volume_down_rounded, color: VaultTheme.textMuted, size: 16),
                  Expanded(
                    child: Slider(
                      value: _binaural.volume,
                      min: 0.0,
                      max: 1.0,
                      activeColor: VaultTheme.electricViolet,
                      inactiveColor: Colors.white.withOpacity(0.05),
                      onChanged: (val) {
                        _binaural.setVolume(val);
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, color: VaultTheme.textMuted, size: 16),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Tune Settings Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VaultTheme.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  const Text(
                    "AUDIO ENVELOPE MODULATOR",
                    style: TextStyle(color: VaultTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Left Freq (Base)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text("${_binaural.baseFreq.toStringAsFixed(0)} Hz", style: const TextStyle(color: VaultTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _binaural.baseFreq,
                    min: 100.0,
                    max: 500.0,
                    activeColor: VaultTheme.neonCyan,
                    inactiveColor: Colors.white.withOpacity(0.05),
                    onChanged: (val) {
                      _binaural.setBaseFreq(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Right Offset (Beat)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text("+${_binaural.beatFreq.toStringAsFixed(1)} Hz", style: const TextStyle(color: VaultTheme.electricViolet, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _binaural.beatFreq,
                    min: 1.0,
                    max: 50.0,
                    activeColor: VaultTheme.electricViolet,
                    inactiveColor: Colors.white.withOpacity(0.05),
                    onChanged: (val) {
                      _binaural.setBeatFreq(val);
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Audio Path Display Card
            if (song != null && song.audioUrl.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: VaultTheme.neonCyan, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Source Path: ${song.audioUrl}",
                        style: const TextStyle(color: VaultTheme.textMuted, fontSize: 10, fontFamily: "monospace"),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
