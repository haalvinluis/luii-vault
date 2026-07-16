class ReelModel {
  final String id;
  final String creatorName;
  final String caption;
  int likesCount;
  final int commentsCount;
  final List<String> tags;
  final String visualType; // neon_matrix, binary_rain, pulsing_energy, sacred_geometry
  final String audioFrequencyName;
  bool isLiked;
  bool isSaved;
  String? localVideoPath;
  String? localThumbnailPath;
  final String? downloadDate;
  final String? duration;
  final String? fileSize;
  final String? resolution;

  ReelModel({
    required this.id,
    required this.creatorName,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.tags,
    required this.visualType,
    required this.audioFrequencyName,
    this.isLiked = false,
    this.isSaved = false,
    this.localVideoPath,
    this.localThumbnailPath,
    this.downloadDate,
    this.duration,
    this.fileSize,
    this.resolution,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorName': creatorName,
      'caption': caption,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'tags': tags,
      'visualType': visualType,
      'audioFrequencyName': audioFrequencyName,
      'isLiked': isLiked,
      'isSaved': isSaved,
      'localVideoPath': localVideoPath,
      'localThumbnailPath': localThumbnailPath,
      'downloadDate': downloadDate,
      'duration': duration,
      'fileSize': fileSize,
      'resolution': resolution,
    };
  }

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['id'] as String,
      creatorName: json['creatorName'] as String,
      caption: json['caption'] as String,
      likesCount: json['likesCount'] as int,
      commentsCount: json['commentsCount'] as int,
      tags: List<String>.from(json['tags'] as List),
      visualType: json['visualType'] as String,
      audioFrequencyName: json['audioFrequencyName'] as String,
      isLiked: json['isLiked'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
      localVideoPath: json['localVideoPath'] as String?,
      localThumbnailPath: json['localThumbnailPath'] as String?,
      downloadDate: json['downloadDate'] as String?,
      duration: json['duration'] as String?,
      fileSize: json['fileSize'] as String?,
      resolution: json['resolution'] as String?,
    );
  }
}
