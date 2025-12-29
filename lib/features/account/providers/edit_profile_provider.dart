import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../../services/supabase_service.dart';
import '../../../services/image_cache_service.dart';

class EditProfileState {
  final bool isLoading;
  final bool hasChanges;
  final File? imageFile;
  final String? avatarUrl;
  final String? error;

  const EditProfileState({
    this.isLoading = false,
    this.hasChanges = false,
    this.imageFile,
    this.avatarUrl,
    this.error,
  });

  EditProfileState copyWith({
    bool? isLoading,
    bool? hasChanges,
    File? imageFile,
    String? avatarUrl,
    String? error,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      hasChanges: hasChanges ?? this.hasChanges,
      imageFile: imageFile ?? this.imageFile,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      error: error ?? this.error,
    );
  }
}

class EditProfileNotifier extends Notifier<EditProfileState> {
  final _imagePicker = ImagePicker();

  @override
  EditProfileState build() {
    // Initialize data after build
    Future.microtask(() => loadUserData());
    return const EditProfileState();
  }

  void setHasChanges(bool hasChanges) {
    state = state.copyWith(hasChanges: hasChanges);
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setAvatarUrl(String? avatarUrl) {
    state = state.copyWith(avatarUrl: avatarUrl);
  }

  void loadUserData() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        final avatarUrl = user.userMetadata?['avatar_url'];

        state = state.copyWith(
          avatarUrl: avatarUrl,
          error: null, // Clear any previous errors
        );

        // Pre-cache avatar if exists and not in offline mode
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          _precacheAvatar(avatarUrl, user.id);
        }
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load user data: ${e.toString()}',
      );
    }
  }

  // Pre-cache avatar image for offline use
  Future<void> _precacheAvatar(String avatarUrl, String userId) async {
    try {
      // Don't await this - run in background
      Future.microtask(() async {
        final imageCacheService = ImageCacheService();
        await imageCacheService.getCachedImage(avatarUrl, userId);
        if (kDebugMode) {
          print('✅ Avatar pre-cached for offline use');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to pre-cache avatar: $e');
      }
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (image != null) {
        state = state.copyWith(imageFile: File(image.path), hasChanges: true);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick image: ${e.toString()}');
    }
  }

  void removePhoto() {
    state = state.copyWith(imageFile: null, avatarUrl: null, hasChanges: true);
  }

  Future<String?> uploadAvatar(WidgetRef ref) async {
    if (state.imageFile == null) return state.avatarUrl;

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;

      // Delete old avatar if exists
      if (state.avatarUrl != null) {
        try {
          // Extract filename from URL to delete old avatar
          final uri = Uri.parse(state.avatarUrl!);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length >= 3) {
            // URL format: .../storage/v1/object/public/avatars/{user_id}/filename
            final oldFileName =
                '${pathSegments[pathSegments.length - 2]}/${pathSegments.last}';
            await SupabaseService.client.storage.from('avatars').remove([
              oldFileName,
            ]);
          }
        } catch (e) {
          // Continue if deletion fails - not critical
          debugPrint('Failed to delete old avatar: $e');
        }
      }

      // Use folder structure: {user_id}/avatar_{timestamp}.jpg
      final fileName =
          '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await SupabaseService.client.storage
          .from('avatars')
          .upload(fileName, state.imageFile!);

      final String publicUrl = SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // Cache the uploaded image
      final imageCacheService = ref.read(imageCacheServiceProvider);
      await imageCacheService.cacheLocalImage(
        state.imageFile!,
        publicUrl,
        user.id,
      );

      return publicUrl;
    } catch (e) {
      String errorMessage = 'Failed to upload image: ${e.toString()}';

      // Provide more specific error messages
      if (e.toString().contains('StorageException')) {
        if (e.toString().contains('403') ||
            e.toString().contains('Unauthorized')) {
          errorMessage =
              'Upload failed: Please check if the avatars bucket exists and has correct permissions in Supabase Dashboard';
        } else if (e.toString().contains('404')) {
          errorMessage =
              'Upload failed: The avatars bucket does not exist. Please create it in Supabase Dashboard';
        } else if (e.toString().contains('413')) {
          errorMessage =
              'Upload failed: Image file is too large. Please choose a smaller image';
        }
      }

      state = state.copyWith(error: errorMessage);
      return null;
    }
  }

  Future<bool> saveProfile({
    required String fullName,
    required String phone,
    required WidgetRef ref,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('user_not_found');
      }

      // Upload avatar if image is selected
      String? avatarUrl = state.avatarUrl;
      if (state.imageFile != null) {
        avatarUrl = await uploadAvatar(ref);
      }

      // Update user metadata
      await SupabaseService.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': fullName.trim(),
            'phone': phone.trim(),
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
        ),
      );

      state = state.copyWith(
        isLoading: false,
        hasChanges: false,
        imageFile: null,
        avatarUrl: avatarUrl,
      );

      // Refresh the current user provider
      ref.invalidate(currentUserProvider);

      return true;
    } catch (e) {
      // Try to localize known error messages
      String errorMsg = e.toString();
      if (errorMsg.contains('user_not_found')) {
        errorMsg = 'error_loading_user';
      } else if (errorMsg.contains('StorageException')) {
        if (errorMsg.contains('403') || errorMsg.contains('Unauthorized')) {
          errorMsg = 'avatar_upload_permission_error';
        } else if (errorMsg.contains('404')) {
          errorMsg = 'avatar_upload_not_found_error';
        } else if (errorMsg.contains('413')) {
          errorMsg = 'avatar_upload_too_large_error';
        }
      } else {
        errorMsg = 'error_saving_profile';
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final editProfileProvider =
    NotifierProvider<EditProfileNotifier, EditProfileState>(
      EditProfileNotifier.new,
    );
