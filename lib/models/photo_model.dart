class PhotoModel {
  final String id;
  final String title;
  final String category; // Faces, Places, Vibes
  final List<String> tags;
  final Map<String, double> aiConfidence; // e.g. {"sunset": 0.98, "beach": 0.92}
  final String visualStyle; // Custom painting style identifier
  final String creationDate;
  bool isFavorite;

  // Custom file properties
  final String? localFilePath;
  final String? thumbnailPath;
  final int? fileSize;
  final String? originalName;

  PhotoModel({
    required this.id,
    required this.title,
    required this.category,
    required this.tags,
    required this.aiConfidence,
    required this.visualStyle,
    required this.creationDate,
    this.isFavorite = false,
    this.localFilePath,
    this.thumbnailPath,
    this.fileSize,
    this.originalName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'tags': tags,
      'aiConfidence': aiConfidence,
      'visualStyle': visualStyle,
      'creationDate': creationDate,
      'isFavorite': isFavorite,
      'localFilePath': localFilePath,
      'thumbnailPath': thumbnailPath,
      'fileSize': fileSize,
      'originalName': originalName,
    };
  }

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      tags: List<String>.from(json['tags'] ?? []),
      aiConfidence: (json['aiConfidence'] as Map<dynamic, dynamic>? ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      visualStyle: json['visualStyle'] as String,
      creationDate: json['creationDate'] as String,
      isFavorite: json['isFavorite'] as bool? ?? false,
      localFilePath: json['localFilePath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      fileSize: json['fileSize'] as int?,
      originalName: json['originalName'] as String?,
    );
  }
}
