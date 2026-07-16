class BinauralPreset {
  final String name;
  final double leftFreq;
  final double rightFreq;
  final String description;
  final String category; // Focus, Meditation, Energy, Sleep

  BinauralPreset({
    required this.name,
    required this.leftFreq,
    required this.rightFreq,
    required this.description,
    required this.category,
  });

  double get beatFreq => (rightFreq - leftFreq).abs();
}

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String playlistName; // Calm, Focus, Chill, Imports
  final String duration;
  final double leftFreq;
  final double rightFreq;
  final String audioUrl;
  final String? album;
  final String? thumbnail;
  
  // Listening statistics fields (Part 3)
  final int playCount;
  final int dateAdded;
  final int lastPlayed;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.playlistName,
    required this.duration,
    required this.audioUrl,
    this.leftFreq = 200.0,
    this.rightFreq = 210.0,
    this.album = "Local Album",
    this.thumbnail,
    this.playCount = 0,
    int? dateAdded,
    this.lastPlayed = 0,
  }) : this.dateAdded = dateAdded ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'playlistName': playlistName,
      'duration': duration,
      'leftFreq': leftFreq,
      'rightFreq': rightFreq,
      'audioUrl': audioUrl,
      'album': album,
      'thumbnail': thumbnail,
      'playCount': playCount,
      'dateAdded': dateAdded,
      'lastPlayed': lastPlayed,
    };
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      playlistName: json['playlistName'] as String,
      duration: json['duration'] as String,
      leftFreq: (json['leftFreq'] as num?)?.toDouble() ?? 200.0,
      rightFreq: (json['rightFreq'] as num?)?.toDouble() ?? 210.0,
      audioUrl: json['audioUrl'] as String? ?? "",
      album: json['album'] as String? ?? "Local Album",
      thumbnail: json['thumbnail'] as String?,
      playCount: json['playCount'] as int? ?? 0,
      dateAdded: json['dateAdded'] as int?,
      lastPlayed: json['lastPlayed'] as int? ?? 0,
    );
  }
}
