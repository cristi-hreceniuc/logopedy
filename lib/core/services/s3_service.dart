import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../network/dio_client.dart';
import '../../features/content/content_api.dart';
import 'audio_cache_service.dart';

/// Service for handling S3 media assets
/// Backend returns pre-signed URLs for secure access to private S3 assets
class S3Service {
  S3Service(this._dioClient);
  
  final DioClient _dioClient;
  bool _isPrefetching = false;
  
  /// Returns the URL as-is since backend provides pre-signed URLs
  /// Pre-signed URLs are full URLs with temporary authentication tokens
  /// Example: "https://bucket.s3.region.amazonaws.com/path/to/file.jpg?X-Amz-Algorithm=..."
  String getFullUrl(String url) {
    if (url.isEmpty) return '';
    
    // Backend returns full pre-signed URLs, use them as-is
    // Also handles local assets that still use "assets/" paths
    return url;
  }
  
  /// Prefetch all lesson images and audio for a profile in the background
  /// Call this when the app detects internet connection
  Future<void> prefetchAllLessonImages(int profileId) async {
    if (_isPrefetching) {
      debugPrint('[S3Service] Prefetch already in progress, skipping');
      return;
    }
    
    _isPrefetching = true;
    debugPrint('[S3Service] Starting media prefetch for profile $profileId');
    
    try {
      final contentApi = ContentApi(_dioClient.dio);
      final audioCache = GetIt.I<AudioCacheService>();
      
      // Get all modules for the profile
      final modules = await contentApi.listModules(profileId);
      
      int totalImages = 0;
      int cachedImages = 0;
      int totalAudio = 0;
      int cachedAudio = 0;
      
      // Iterate through modules to get all lessons
      for (final moduleData in modules) {
        final moduleId = moduleData['id'] as int?;
        if (moduleId == null) continue;
        
        try {
          final moduleDetails = await contentApi.getModule(profileId, moduleId);
          final submodules = moduleDetails['submodules'] as List? ?? [];
          
          for (final submoduleData in submodules) {
            final submoduleId = submoduleData['id'] as int?;
            if (submoduleId == null) continue;
            
            try {
              final submoduleDetails = await contentApi.getSubmodule(profileId, submoduleId);
              final lessons = submoduleDetails['lessons'] as List? ?? [];
              
              for (final lessonData in lessons) {
                final lessonId = lessonData['id'] as int?;
                if (lessonId == null) continue;
                
                try {
                  final lessonDetails = await contentApi.getLesson(profileId, lessonId);
                  final screens = lessonDetails['screens'] as List? ?? [];
                  
                  // Extract and prefetch images and audio from screens
                  for (final screen in screens) {
                    final payload = screen['payload'] as Map<String, dynamic>? ?? {};
                    
                    // Prefetch images
                    final imageKeys = _extractImageKeysFromPayload(payload);
                    for (final key in imageKeys) {
                      totalImages++;
                      final url = getFullUrl(key);
                      try {
                        await precacheImage(
                          CachedNetworkImageProvider(url),
                          NavigationService.navigatorKey.currentContext!,
                        );
                        cachedImages++;
                      } catch (e) {
                        debugPrint('[S3Service] Failed to cache image $url: $e');
                      }
                    }
                    
                    // Prefetch audio
                    final audioKeys = _extractAudioKeysFromPayload(payload);
                    for (final key in audioKeys) {
                      totalAudio++;
                      final url = getFullUrl(key);
                      try {
                        await audioCache.getLocalPath(url);
                        cachedAudio++;
                      } catch (e) {
                        debugPrint('[S3Service] Failed to cache audio $url: $e');
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('[S3Service] Failed to fetch lesson $lessonId: $e');
                }
              }
            } catch (e) {
              debugPrint('[S3Service] Failed to fetch submodule $submoduleId: $e');
            }
          }
        } catch (e) {
          debugPrint('[S3Service] Failed to fetch module $moduleId: $e');
        }
      }
      
      debugPrint('[S3Service] Prefetch complete: $cachedImages/$totalImages images cached, $cachedAudio/$totalAudio audio cached');
    } catch (e) {
      debugPrint('[S3Service] Error during prefetch: $e');
    } finally {
      _isPrefetching = false;
    }
  }
  
  /// Extract S3 image keys from a lesson screen payload
  List<String> _extractImageKeysFromPayload(Map<String, dynamic> payload) {
    final keys = <String>[];
    
    // Check for single image
    if (payload['s3ImageKey'] != null) {
      keys.add(payload['s3ImageKey'] as String);
    }
    
    if (payload['image'] != null) {
      final image = payload['image'];
      if (image is String) {
        keys.add(image);
      } else if (image is Map && image['s3Key'] != null) {
        keys.add(image['s3Key'] as String);
      }
    }
    
    // Check for multiple images
    if (payload['images'] != null) {
      final images = payload['images'] as List;
      for (final img in images) {
        if (img is Map) {
          if (img['s3Key'] != null) {
            keys.add(img['s3Key'] as String);
          } else if (img['uri'] != null) {
            keys.add(img['uri'] as String);
          }
        }
      }
    }
    
    return keys;
  }
  
  /// Extract S3 audio keys from a lesson screen payload
  List<String> _extractAudioKeysFromPayload(Map<String, dynamic> payload) {
    final keys = <String>[];
    
    // Check for single audio
    if (payload['s3AudioKey'] != null) {
      keys.add(payload['s3AudioKey'] as String);
    }
    
    // Check for audio in nested objects
    if (payload['audio'] != null) {
      final audio = payload['audio'];
      if (audio is String) {
        keys.add(audio);
      } else if (audio is Map) {
        if (audio['s3Key'] != null) {
          keys.add(audio['s3Key'] as String);
        } else if (audio['uri'] != null) {
          keys.add(audio['uri'] as String);
        }
      }
    }
    
    // Check for word audio
    if (payload['word'] != null && payload['word'] is Map) {
      final word = payload['word'] as Map;
      if (word['audio'] != null) {
        final audio = word['audio'];
        if (audio is String) {
          keys.add(audio);
        } else if (audio is Map) {
          if (audio['s3Key'] != null) {
            keys.add(audio['s3Key'] as String);
          } else if (audio['uri'] != null) {
            keys.add(audio['uri'] as String);
          }
        }
      }
    }
    
    // Check for syllables audio
    if (payload['syllables'] != null && payload['syllables'] is List) {
      final syllables = payload['syllables'] as List;
      for (final syllable in syllables) {
        if (syllable is Map && syllable['audio'] != null) {
          final audio = syllable['audio'];
          if (audio is String) {
            keys.add(audio);
          } else if (audio is Map) {
            if (audio['s3Key'] != null) {
              keys.add(audio['s3Key'] as String);
            } else if (audio['uri'] != null) {
              keys.add(audio['uri'] as String);
            }
          }
        }
      }
    }
    
    // Check for multiple audio files
    if (payload['audioFiles'] != null && payload['audioFiles'] is List) {
      final audioFiles = payload['audioFiles'] as List;
      for (final audio in audioFiles) {
        if (audio is String) {
          keys.add(audio);
        } else if (audio is Map) {
          if (audio['s3Key'] != null) {
            keys.add(audio['s3Key'] as String);
          } else if (audio['uri'] != null) {
            keys.add(audio['uri'] as String);
          }
        }
      }
    }
    
    return keys;
  }
  
  /// Clear all cached images and audio
  Future<void> clearCache() async {
    try {
      await CachedNetworkImage.evictFromCache('');
      await GetIt.I<AudioCacheService>().clearCache();
      debugPrint('[S3Service] Cache cleared');
    } catch (e) {
      debugPrint('[S3Service] Error clearing cache: $e');
    }
  }
  
  bool get isPrefetching => _isPrefetching;
}

/// Global navigation key for accessing context during prefetch
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

