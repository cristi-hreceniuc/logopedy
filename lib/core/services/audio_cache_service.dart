import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for caching audio files locally
/// Downloads audio from URLs and stores them in the app's cache directory
class AudioCacheService {
  AudioCacheService(Dio dio) {
    // Create a separate Dio instance for S3 downloads without interceptors
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
      validateStatus: (status) => status != null && status < 500,
    ));
  }
  
  late final Dio _dio;
  Directory? _cacheDir;
  final Map<String, String> _urlToPathCache = {}; // In-memory cache of URL -> local path
  
  /// Initialize the cache directory
  Future<void> initialize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/audio_cache');
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
        debugPrint('[AudioCache] Created cache directory: ${_cacheDir!.path}');
      } else {
        debugPrint('[AudioCache] Cache directory exists: ${_cacheDir!.path}');
      }
    } catch (e) {
      debugPrint('[AudioCache] Failed to initialize cache directory: $e');
    }
  }
  
  /// Get the local file path for a URL, downloading if necessary
  /// Returns null if download fails
  Future<String?> getLocalPath(String url) async {
    if (url.isEmpty) return null;
    
    // Check in-memory cache first
    if (_urlToPathCache.containsKey(url)) {
      final cachedPath = _urlToPathCache[url]!;
      if (await File(cachedPath).exists()) {
        debugPrint('[AudioCache] Found in memory cache: $url');
        return cachedPath;
      }
    }
    
    // Ensure cache directory is initialized
    if (_cacheDir == null) {
      await initialize();
      if (_cacheDir == null) {
        debugPrint('[AudioCache] Failed to initialize cache directory');
        return null;
      }
    }
    
    // Generate filename from URL hash
    final filename = _generateFilename(url);
    final localPath = '${_cacheDir!.path}/$filename';
    final localFile = File(localPath);
    
    // Check if file already exists
    if (await localFile.exists()) {
      debugPrint('[AudioCache] Found cached file: $filename');
      _urlToPathCache[url] = localPath;
      return localPath;
    }
    
    // Download the file
    try {
      debugPrint('[AudioCache] Downloading: ${url.substring(0, 100)}...');
      
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data as List<int>;
        
        // Validate we got data
        if (bytes.isEmpty) {
          debugPrint('[AudioCache] ❌ Downloaded file is empty');
          return null;
        }
        
        // Write to file
        await localFile.writeAsBytes(bytes);
        
        // Verify file was written
        if (!await localFile.exists()) {
          debugPrint('[AudioCache] ❌ File was not written to disk');
          return null;
        }
        
        final fileSize = await localFile.length();
        if (fileSize == 0) {
          debugPrint('[AudioCache] ❌ Written file is empty');
          await localFile.delete();
          return null;
        }
        
        _urlToPathCache[url] = localPath;
        debugPrint('[AudioCache] ✅ Downloaded and cached: $filename ($fileSize bytes)');
        debugPrint('[AudioCache] ✅ File path: $localPath');
        return localPath;
      } else {
        debugPrint('[AudioCache] ❌ Failed to download: ${response.statusCode} - ${response.statusMessage}');
        return null;
      }
    } catch (e, stack) {
      debugPrint('[AudioCache] ❌ Download error: $e');
      debugPrint('[AudioCache] Stack: $stack');
      return null;
    }
  }
  
  /// Generate a unique filename from URL using hash
  String _generateFilename(String url) {
    // Extract file extension from URL (before query parameters)
    final uri = Uri.parse(url);
    final path = uri.path;
    final extension = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.mp3';
    
    // Create hash of full URL (including query params for unique presigned URLs)
    final hash = md5.convert(utf8.encode(url)).toString();
    
    return '$hash$extension';
  }
  
  /// Clear all cached audio files
  Future<void> clearCache() async {
    if (_cacheDir == null) return;
    
    try {
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
        _urlToPathCache.clear();
        debugPrint('[AudioCache] Cache cleared');
      }
    } catch (e) {
      debugPrint('[AudioCache] Failed to clear cache: $e');
    }
  }
  
  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) return 0;
    
    try {
      int totalSize = 0;
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('[AudioCache] Failed to calculate cache size: $e');
      return 0;
    }
  }
}
