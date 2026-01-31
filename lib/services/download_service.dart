import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
// import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
// import 'package:ffmpeg_kit_flutter_full_gpl/statistics.dart';

class DownloadTask {
  final String id;
  final String animeId;
  final String animeTitle;
  final String episodeTitle;
  final String url;
  final String filePath;
  double progress;
  String status; // 'pending' | 'downloading' | 'converting' | 'completed' | 'failed'
  String? errorMessage;
  int? totalSize; // in bytes
  bool isHLS;

  DownloadTask({
    required this.id,
    required this.animeId,
    required this.animeTitle,
    required this.episodeTitle,
    required this.url,
    required this.filePath,
    this.progress = 0,
    this.status = 'pending',
    this.errorMessage,
    this.totalSize,
    this.isHLS = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'animeId': animeId,
    'animeTitle': animeTitle,
    'episodeTitle': episodeTitle,
    'url': url,
    'filePath': filePath,
    'progress': progress,
    'status': status,
    'errorMessage': errorMessage,
    'totalSize': totalSize,
    'isHLS': isHLS,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    id: json['id'],
    animeId: json['animeId'],
    animeTitle: json['animeTitle'],
    episodeTitle: json['episodeTitle'],
    url: json['url'],
    filePath: json['filePath'],
    progress: (json['progress'] ?? 0).toDouble(),
    status: json['status'],
    errorMessage: json['errorMessage'],
    totalSize: json['totalSize'],
    isHLS: json['isHLS'] ?? false,
  );
}

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final Map<String, DownloadTask> _tasks = {};
  
  List<DownloadTask> get tasks => _tasks.values.toList();
  
  Future<void> init() async {
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('download_tasks');
    if (data != null) {
      final Map<String, dynamic> decoded = json.decode(data);
      decoded.forEach((key, value) {
        _tasks[key] = DownloadTask.fromJson(value);
      });
      notifyListeners();
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = json.encode(_tasks.map((key, value) => MapEntry(key, value.toJson())));
    await prefs.setString('download_tasks', data);
  }

  /// Check if URL is HLS stream
  bool _isHLSUrl(String url) {
    return url.contains('.m3u8') || url.contains('m3u8');
  }

  /// Estimate size in MB (only works for direct downloads)
  Future<double?> estimateSize(String url) async {
    try {
      final response = await _dio.head(url);
      final length = response.headers.value('content-length');
      if (length != null) {
        return int.parse(length) / (1024 * 1024);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Size estimation error: $e');
    }
    return null;
  }

  Future<void> startDownload({
    required String animeId,
    required String animeTitle,
    required String episodeTitle,
    required String episodeUrl,
    String? subtitleUrl,
    String? subtitleLabel,
  }) async {
    final taskId = '${animeId}_${episodeTitle.hashCode}';
    
    if (_tasks.containsKey(taskId) && _tasks[taskId]!.status == 'completed') {
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final isHLS = _isHLSUrl(episodeUrl);
    // HLS will be converted to MP4, direct downloads keep original extension
    final filePath = '${downloadDir.path}/$taskId.mp4';

    final task = DownloadTask(
      id: taskId,
      animeId: animeId,
      animeTitle: animeTitle,
      episodeTitle: episodeTitle,
      url: episodeUrl,
      filePath: filePath,
      status: 'downloading',
      isHLS: isHLS,
    );

    _tasks[taskId] = task;
    notifyListeners();
    await _saveTasks();

    try {
      if (isHLS) {
        // Use FFmpeg for HLS streams
        if (kDebugMode) print('📥 Starting HLS download with FFmpeg...');
        await _downloadHLS(task, episodeUrl, filePath);
      } else {
        // Use Dio for direct MP4 downloads
        if (kDebugMode) print('📥 Starting direct download...');
        await _downloadDirect(task, episodeUrl, filePath);
      }

      // Download subtitle if provided
      if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
        try {
          final subtitlePath = '${downloadDir.path}/$taskId.vtt';
          await _dio.download(subtitleUrl, subtitlePath);
          if (kDebugMode) print('✅ Subtitle downloaded: $subtitleLabel');
        } catch (e) {
          if (kDebugMode) print('⚠️ Subtitle download failed: $e');
        }
      }

      task.status = 'completed';
      task.progress = 1.0;
      if (kDebugMode) print('✅ Download completed: ${task.episodeTitle}');
    } catch (e) {
      task.status = 'failed';
      task.errorMessage = e.toString();
      if (kDebugMode) print('❌ Download failed: $e');
    }

    notifyListeners();
    await _saveTasks();
  }

  /// Download HLS stream using FFmpeg (DISABLED)
  Future<void> _downloadHLS(DownloadTask task, String url, String outputPath) async {
    task.status = 'failed';
    task.errorMessage = 'HLS downloads are temporarily disabled due to Android build issues with FFmpegKit.';
    notifyListeners();
    if (kDebugMode) print('❌ _downloadHLS: ${task.errorMessage}');
    
    // FFmpeg Logic Removed
  }

  /// Download direct MP4 file using Dio
  Future<void> _downloadDirect(DownloadTask task, String url, String outputPath) async {
    await _dio.download(
      url,
      outputPath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          task.progress = received / total;
          task.totalSize = total;
          notifyListeners();
        }
      },
    );
  }

  Future<void> removeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task != null) {
      // Delete video file
      final file = File(task.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      // Delete subtitle file if exists
      final subtitleFile = File(task.filePath.replaceAll('.mp4', '.vtt'));
      if (await subtitleFile.exists()) {
        await subtitleFile.delete();
      }
      _tasks.remove(taskId);
      notifyListeners();
      await _saveTasks();
    }
  }

  /// Cancel ongoing download
  Future<void> cancelDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task != null && task.status == 'downloading' || task?.status == 'converting') {
      // FFmpegKit.cancel(); // DISABLED
      task!.status = 'failed';
      task.errorMessage = 'Cancelled by user';
      notifyListeners();
      await _saveTasks();
    }
  }

  bool isDownloaded(String taskId) {
    return _tasks.containsKey(taskId) && _tasks[taskId]!.status == 'completed';
  }

  DownloadTask? getTask(String taskId) {
    return _tasks[taskId];
  }
}
