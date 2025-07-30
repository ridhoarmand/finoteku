import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Provider untuk ImageCacheService
final imageCacheServiceProvider = Provider<ImageCacheService>((ref) {
  return ImageCacheService();
});

class ImageCacheService {
  static const String _cacheKeyPrefix = 'cached_image_';
  static const String _lastUpdatePrefix = 'last_update_';
  
  // Cache duration: 7 days
  static const Duration _cacheDuration = Duration(days: 7);

  /// Get cached image file or download and cache if not exists
  Future<File?> getCachedImage(String imageUrl, String userId) async {
    try {
      final cacheKey = _generateCacheKey(imageUrl, userId);
      final prefs = await SharedPreferences.getInstance();
      
      // Check if we have cached image path
      final cachedPath = prefs.getString('$_cacheKeyPrefix$cacheKey');
      if (cachedPath != null) {
        final cachedFile = File(cachedPath);
        
        // Check if file exists and is not expired
        if (await cachedFile.exists()) {
          final lastUpdate = prefs.getInt('$_lastUpdatePrefix$cacheKey') ?? 0;
          final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
          
          if (DateTime.now().difference(lastUpdateTime) < _cacheDuration) {
            if (kDebugMode) {
              print('✅ Using cached image: $cachedPath');
            }
            return cachedFile;
          } else {
            // Cache expired, delete old file
            await cachedFile.delete();
            await prefs.remove('$_cacheKeyPrefix$cacheKey');
            await prefs.remove('$_lastUpdatePrefix$cacheKey');
            if (kDebugMode) {
              print('🗑️ Cache expired, deleted: $cachedPath');
            }
          }
        }
      }

      // Download and cache new image
      return await _downloadAndCacheImage(imageUrl, cacheKey);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting cached image: $e');
      }
      return null;
    }
  }

  /// Download image from URL and save to cache
  Future<File?> _downloadAndCacheImage(String imageUrl, String cacheKey) async {
    try {
      if (kDebugMode) {
        print('📥 Downloading image: $imageUrl');
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Failed to download image: ${response.statusCode}');
        }
        return null;
      }

      // Get cache directory
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return null;

      // Create cache file
      final fileName = '$cacheKey.jpg';
      final cacheFile = File('${cacheDir.path}/$fileName');
      
      // Write image data to file
      await cacheFile.writeAsBytes(response.bodyBytes);

      // Save cache info to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cacheKeyPrefix$cacheKey', cacheFile.path);
      await prefs.setInt('$_lastUpdatePrefix$cacheKey', DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) {
        print('✅ Image cached successfully: ${cacheFile.path}');
      }

      return cacheFile;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error downloading and caching image: $e');
      }
      return null;
    }
  }

  /// Cache local image file (for newly uploaded images)
  Future<void> cacheLocalImage(File localFile, String imageUrl, String userId) async {
    try {
      final cacheKey = _generateCacheKey(imageUrl, userId);
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return;

      // Create cache file
      final fileName = '$cacheKey.jpg';
      final cacheFile = File('${cacheDir.path}/$fileName');
      
      // Copy local file to cache
      await localFile.copy(cacheFile.path);

      // Save cache info to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cacheKeyPrefix$cacheKey', cacheFile.path);
      await prefs.setInt('$_lastUpdatePrefix$cacheKey', DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) {
        print('✅ Local image cached successfully: ${cacheFile.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error caching local image: $e');
      }
    }
  }

  /// Clear all cached images for a user
  Future<void> clearUserCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix) && key.contains(userId)) {
          final cachedPath = prefs.getString(key);
          if (cachedPath != null) {
            final cachedFile = File(cachedPath);
            if (await cachedFile.exists()) {
              await cachedFile.delete();
            }
          }
          await prefs.remove(key);
          
          // Also remove last update key
          final updateKey = key.replaceFirst(_cacheKeyPrefix, _lastUpdatePrefix);
          await prefs.remove(updateKey);
        }
      }

      if (kDebugMode) {
        print('✅ Cleared cache for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing user cache: $e');
      }
    }
  }

  /// Clear all expired cache files
  Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final now = DateTime.now();
      
      for (final key in keys) {
        if (key.startsWith(_lastUpdatePrefix)) {
          final lastUpdate = prefs.getInt(key) ?? 0;
          final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
          
          if (now.difference(lastUpdateTime) >= _cacheDuration) {
            // Remove expired cache
            final cacheKey = key.replaceFirst(_lastUpdatePrefix, _cacheKeyPrefix);
            final cachedPath = prefs.getString(cacheKey);
            
            if (cachedPath != null) {
              final cachedFile = File(cachedPath);
              if (await cachedFile.exists()) {
                await cachedFile.delete();
              }
            }
            
            await prefs.remove(cacheKey);
            await prefs.remove(key);
          }
        }
      }

      if (kDebugMode) {
        print('✅ Cleared expired cache files');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing expired cache: $e');
      }
    }
  }

  /// Get cache directory
  Future<Directory?> _getCacheDirectory() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final imagesCacheDir = Directory('${cacheDir.path}/images');
      
      if (!await imagesCacheDir.exists()) {
        await imagesCacheDir.create(recursive: true);
      }
      
      return imagesCacheDir;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting cache directory: $e');
      }
      return null;
    }
  }

  /// Generate cache key from image URL and user ID
  String _generateCacheKey(String imageUrl, String userId) {
    final uri = Uri.parse(imageUrl);
    final fileName = uri.pathSegments.last;
    return '${userId}_$fileName';
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return 0;

      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }

      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating cache size: $e');
      }
      return 0;
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return;

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix) || key.startsWith(_lastUpdatePrefix)) {
          await prefs.remove(key);
        }
      }

      if (kDebugMode) {
        print('✅ Cleared all image cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing all cache: $e');
      }
    }
  }
}
