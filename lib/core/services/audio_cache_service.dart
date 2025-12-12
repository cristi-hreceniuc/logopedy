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
      // Don't encode the URI - it's already encoded by the backend presigner
      listFormat: ListFormat.multi,
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
    
    // Generate temporary filename for checking if already exists
    final tempFilename = _generateFilename(url);
    final tempPath = '${_cacheDir!.path}/$tempFilename';
    
    // Check if any file with this hash exists (regardless of extension)
    final hash = md5.convert(utf8.encode(url)).toString();
    final cacheFiles = await _cacheDir!.list().toList();
    for (final file in cacheFiles) {
      if (file is File && file.path.contains(hash)) {
        debugPrint('[AudioCache] Found existing cached file: ${file.path}');
        _urlToPathCache[url] = file.path;
        return file.path;
      }
    }
    
    final localFile = File(tempPath);
    
    // This check is now done above when looking for any existing file with the same hash
    
    // Download the file
    try {
      // Log the URL (truncated for readability, but show key parts)
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final filename = pathSegments.isNotEmpty ? pathSegments.last : 'unknown';
      debugPrint('[AudioCache] Downloading: $filename');
      debugPrint('[AudioCache] Full URL path: ${uri.path}');
      
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          // Preserve special characters in the URL
          followRedirects: true,
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data as List<int>;
        
        // Validate we got data
        if (bytes.isEmpty) {
          debugPrint('[AudioCache] ❌ Downloaded file is empty');
          return null;
        }
        
        // Detect actual audio format from file headers
        String actualExtension = '.mp3'; // default
        
        if (bytes.length >= 12) {
          // MP3 formats
          if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) || // ID3
              (bytes[0] == 0xFF && (bytes[1] == 0xFB || bytes[1] == 0xF3 || bytes[1] == 0xF2))) {
            actualExtension = '.mp3';
            debugPrint('[AudioCache] ✅ Detected MP3 format');
          }
          // M4A/MP4 format (ftyp at offset 4)
          else if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
            actualExtension = '.m4a';
            debugPrint('[AudioCache] ✅ Detected M4A/AAC format');
          }
          // WAV format
          else if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
            actualExtension = '.wav';
            debugPrint('[AudioCache] ✅ Detected WAV format');
          }
          // OGG format
          else if (bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53) {
            actualExtension = '.ogg';
            debugPrint('[AudioCache] ✅ Detected OGG format');
          }
          else {
            debugPrint('[AudioCache] ⚠️  Unknown audio format, using as-is');
            debugPrint('[AudioCache] First bytes: ${bytes.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          }
        }
        
        // Generate final filename with correct extension
        final finalFilename = _generateFilename(url, detectedExtension: actualExtension);
        final finalPath = '${_cacheDir!.path}/$finalFilename';
        final finalFile = File(finalPath);
        
        // Write to file with correct extension
        await finalFile.writeAsBytes(bytes);
        
        // Verify file was written
        if (!await finalFile.exists()) {
          debugPrint('[AudioCache] ❌ File was not written to disk');
          return null;
        }
        
        final fileSize = await finalFile.length();
        if (fileSize == 0) {
          debugPrint('[AudioCache] ❌ Written file is empty');
          await finalFile.delete();
          return null;
        }
        
        _urlToPathCache[url] = finalPath;
        debugPrint('[AudioCache] ✅ Downloaded and cached: $finalFilename ($fileSize bytes)');
        debugPrint('[AudioCache] ✅ File path: $finalPath');
        return finalPath;
      } else {
        debugPrint('[AudioCache] ❌ Failed to download: ${response.statusCode} - ${response.statusMessage}');
        debugPrint('[AudioCache] Response headers: ${response.headers}');
        return null;
      }
    } catch (e, stack) {
      debugPrint('[AudioCache] ❌ Download error: $e');
      debugPrint('[AudioCache] Error type: ${e.runtimeType}');
      if (e is DioException) {
        debugPrint('[AudioCache] Dio error type: ${e.type}');
        debugPrint('[AudioCache] Response: ${e.response?.statusCode} - ${e.response?.statusMessage}');
        debugPrint('[AudioCache] Request URL: ${e.requestOptions.uri}');
      }
      debugPrint('[AudioCache] Stack: $stack');
      return null;
    }
  }
  
  /// Generate a unique filename from URL using hash
  String _generateFilename(String url, {String? detectedExtension}) {
    // Use detected extension if provided, otherwise extract from URL
    String extension;
    if (detectedExtension != null) {
      extension = detectedExtension;
    } else {
      final uri = Uri.parse(url);
      final path = uri.path;
      extension = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.mp3';
    }
    
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
