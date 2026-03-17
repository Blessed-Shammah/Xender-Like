class FileModel {
  final String id;
  final String originalName;
  final String storedName;
  final int size;
  final String sizeFormatted;
  final String mimeType;
  final String category;
  final String extension;
  final DateTime uploadedAt;

  FileModel({
    required this.id,
    required this.originalName,
    required this.storedName,
    required this.size,
    required this.sizeFormatted,
    required this.mimeType,
    required this.category,
    required this.extension,
    required this.uploadedAt,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id'] ?? '',
      originalName: json['originalName'] ?? '',
      storedName: json['storedName'] ?? '',
      size: json['size'] ?? 0,
      sizeFormatted: json['sizeFormatted'] ?? '0 B',
      mimeType: json['mimeType'] ?? '',
      category: json['category'] ?? 'other',
      extension: json['extension'] ?? '',
      uploadedAt: DateTime.tryParse(json['uploadedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class StatsModel {
  final int totalFiles;
  final int totalSize;
  final String totalSizeFormatted;
  final Map<String, int> categories;

  StatsModel({
    required this.totalFiles,
    required this.totalSize,
    required this.totalSizeFormatted,
    required this.categories,
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      totalFiles: json['totalFiles'] ?? 0,
      totalSize: json['totalSize'] ?? 0,
      totalSizeFormatted: json['totalSizeFormatted'] ?? '0 B',
      categories: Map<String, int>.from(json['categories'] ?? {}),
    );
  }
}
