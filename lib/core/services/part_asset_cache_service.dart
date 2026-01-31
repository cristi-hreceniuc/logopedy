// lib/core/services/part_asset_cache_service.dart
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Information about a single asset from the API.
class AssetInfo {
  final String url;
  final String type;
  final String key;

  AssetInfo({required this.url, required this.type, required this.key});

  factory AssetInfo.fromJson(Map<String, dynamic> json) {
    return AssetInfo(
      url: json['url'] as String,
      type: json['type'] as String,
      key: json['key'] as String,
    );
  }
}

/// Response from the part assets endpoint.
class PartAssetsResponse {
  final List<AssetInfo> assets;
  final int totalCount;

  PartAssetsResponse({required this.assets, required this.totalCount});

  factory PartAssetsResponse.fromJson(Map<String, dynamic> json) {
    final assetsList = (json['assets'] as List)
        .map((a) => AssetInfo.fromJson(a as Map<String, dynamic>))
        .toList();
    return PartAssetsResponse(
      assets: assetsList,
      totalCount: json['totalCount'] as int,
    );
  }
}

/// Service for session-based asset caching.
/// Downloads all assets for a Part when user enters it,
/// stores them in temp folder, and cleans up when leaving.
class PartAssetCacheService extends ChangeNotifier {
  PartAssetCacheService(this._dio);

  final Dio _dio;

  int? _currentPartId;
  final Map<String, String> _urlToLocalPath = {};
  DateTime? _cacheCreatedAt;
  bool _isLoading = false;
  String? _error;

  static const _cacheTimeoutMinutes = 30;

  /// Whether assets are currently being downloaded.
  bool get isLoading => _isLoading;

  /// Error message if prefetch failed.
  String? get error => _error;

  /// The currently cached part ID.
  int? get currentPartId => _currentPartId;

  /// Number of cached assets.
  int get cachedAssetCount => _urlToLocalPath.length;

  /// Load and cache all assets for a part.
  /// Call this when user enters a Part screen.
  Future<void> loadPartAssets(int profileId, int partId) async {
    // If same part and cache not expired, reuse existing cache
    if (_currentPartId == partId && !_isCacheExpired()) {
      return;
    }

    // Clear previous part's cache
    await clearCache();

    _currentPartId = partId;
    _cacheCreatedAt = DateTime.now();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch asset list from backend
      final response = await _dio.get(
        '/api/profiles/$profileId/parts/$partId/assets',
      );

      final partAssets = PartAssetsResponse.fromJson(response.data);

      if (partAssets.assets.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Create temp folder for this part
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/part_$partId');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // Download all assets to temp folder
      await Future.wait(
        partAssets.assets.map((asset) => _downloadAsset(asset, cacheDir.path)),
      );

      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('[PartAssetCache] Loaded ${_urlToLocalPath.length} assets for part $partId');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('[PartAssetCache] Error loading assets: $e');
      }
    }
  }

  Future<void> _downloadAsset(AssetInfo asset, String cacheDir) async {
    try {
      // Generate filename from key hash
      final fileName = asset.key.hashCode.abs().toString();
      final extension = asset.type == 'AUDIO' ? '.mp3' : '.png';
      final localPath = '$cacheDir/$fileName$extension';

      // Download file
      await _dio.download(asset.url, localPath);

      // Store mapping
      _urlToLocalPath[asset.url] = localPath;
    } catch (e) {
      // Fail silently - will fall back to network loading
      if (kDebugMode) {
        print('[PartAssetCache] Failed to download ${asset.key}: $e');
      }
    }
  }

  /// Get local file path for a URL, or return original URL if not cached.
  String getLocalPathOrUrl(String url) {
    return _urlToLocalPath[url] ?? url;
  }

  /// Check if we have this URL cached locally.
  bool isCached(String url) {
    return _urlToLocalPath.containsKey(url);
  }

  /// Check if local file exists for a URL.
  Future<bool> hasLocalFile(String url) async {
    final localPath = _urlToLocalPath[url];
    if (localPath == null) return false;
    return File(localPath).exists();
  }

  bool _isCacheExpired() {
    if (_cacheCreatedAt == null) return true;
    return DateTime.now().difference(_cacheCreatedAt!).inMinutes >
        _cacheTimeoutMinutes;
  }

  /// Clear the cache. Call when user leaves Part or app goes to background.
  Future<void> clearCache() async {
    if (_currentPartId == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/part_$_currentPartId');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
      if (kDebugMode) {
        print('[PartAssetCache] Error clearing cache: $e');
      }
    }

    _currentPartId = null;
    _urlToLocalPath.clear();
    _cacheCreatedAt = null;
    _error = null;
    notifyListeners();
  }

  /// Clear all part caches (cleanup on app start or logout).
  Future<void> clearAllCaches() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final entries = tempDir.listSync();
      for (final entry in entries) {
        if (entry is Directory && entry.path.contains('/part_')) {
          await entry.delete(recursive: true);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PartAssetCache] Error clearing all caches: $e');
      }
    }

    _currentPartId = null;
    _urlToLocalPath.clear();
    _cacheCreatedAt = null;
    _error = null;
    notifyListeners();
  }
}

