import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../services/supabase_service.dart';

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

class EditProfileNotifier extends StateNotifier<EditProfileState> {
  EditProfileNotifier() : super(const EditProfileState());

  final _imagePicker = ImagePicker();

  void setHasChanges(bool hasChanges) {
    state = state.copyWith(hasChanges: hasChanges);
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setAvatarUrl(String? avatarUrl) {
    state = state.copyWith(avatarUrl: avatarUrl);
  }

  void loadUserData() {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      state = state.copyWith(
        avatarUrl: user.userMetadata?['avatar_url'],
      );
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
        state = state.copyWith(
          imageFile: File(image.path),
          hasChanges: true,
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick image: ${e.toString()}');
    }
  }

  void removePhoto() {
    state = state.copyWith(
      imageFile: null,
      avatarUrl: null,
      hasChanges: true,
    );
  }

  Future<String?> uploadAvatar() async {
    if (state.imageFile == null) return state.avatarUrl;

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;

      final fileName = 'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await SupabaseService.client.storage
          .from('avatars')
          .upload(fileName, state.imageFile!);

      final String publicUrl = SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      state = state.copyWith(error: 'Failed to upload image: ${e.toString()}');
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
        throw Exception('User not found');
      }

      // Upload avatar if image is selected
      String? avatarUrl = state.avatarUrl;
      if (state.imageFile != null) {
        avatarUrl = await uploadAvatar();
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
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update profile: ${e.toString()}',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final editProfileProvider = StateNotifierProvider<EditProfileNotifier, EditProfileState>((ref) {
  return EditProfileNotifier();
});
