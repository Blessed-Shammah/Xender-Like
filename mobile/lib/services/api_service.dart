import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../models/file_model.dart';

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  String get _apiBase => '$baseUrl/api';

  // --- Fetch all files ---
  Future<List<FileModel>> getFiles({
    String? search,
    String? category,
    String? sort,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (category != null && category != 'all') params['category'] = category;
    if (sort != null) params['sort'] = sort;

    final uri = Uri.parse('$_apiBase/files').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['files'] as List)
          .map((f) => FileModel.fromJson(f))
          .toList();
    }
    throw Exception('Failed to load files: ${response.statusCode}');
  }

  // --- Get stats ---
  Future<StatsModel> getStats() async {
    final response = await http.get(Uri.parse('$_apiBase/stats')).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return StatsModel.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to load stats');
  }

  // --- Upload files ---
  Future<void> uploadFiles(List<File> files) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_apiBase/upload'));

    for (final file in files) {
      request.files.add(
        await http.MultipartFile.fromPath('files', file.path),
      );
    }

    final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 201) {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  }

  // --- Download file ---
  Future<String?> downloadFile(String fileId, String fileName) async {
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
    } else {
      downloadsDir = await getDownloadsDirectory();
      downloadsDir ??= await getApplicationDocumentsDirectory();
    }

    if (!downloadsDir.existsSync()) {
      try {
        downloadsDir.createSync(recursive: true);
      } catch (_) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }
    }

    String downloadUrl = '$_apiBase/files/$fileId/download';

    try {
      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: downloadsDir.path,
        fileName: fileName,
        showNotification: true, // show download progress in status bar
        openFileFromNotification: true, // click on notification to open downloaded file
        saveInPublicStorage: true,
      );
      return taskId;
    } catch (e) {
      throw Exception('Download failed to start: $e');
    }
  }

  // --- Delete file ---
  Future<void> deleteFile(String fileId) async {
    final response = await http
        .delete(Uri.parse('$_apiBase/files/$fileId'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.statusCode}');
    }
  }

  // --- Get preview URL ---
  String getPreviewUrl(String fileId) {
    return '$_apiBase/files/$fileId/preview';
  }

  // --- Test connection ---
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_apiBase/stats'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
