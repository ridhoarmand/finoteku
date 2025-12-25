import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/edit_profile_provider.dart';
import '../../../../core/services/permission_service.dart';

class ProfileAvatarWidget extends ConsumerWidget {
  final TextEditingController fullNameController;

  const ProfileAvatarWidget({super.key, required this.fullNameController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileState = ref.watch(editProfileProvider);

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: theme.colorScheme.primary,
                child: profileState.imageFile != null
                    ? ClipOval(
                        child: Image.file(
                          profileState.imageFile!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      )
                    : (profileState.avatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: profileState.avatarUrl!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                errorWidget: (context, url, error) => Text(
                                  fullNameController.text.isNotEmpty
                                      ? fullNameController.text
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              fullNameController.text.isNotEmpty
                                  ? fullNameController.text
                                        .substring(0, 1)
                                        .toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                              ),
                            )),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: theme.colorScheme.onSecondary,
                    ),
                    onPressed: () => _showImagePickerModal(context, ref),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profileState.imageFile != null
                ? 'New photo selected'
                : 'Tap camera icon to change photo',
            style: theme.textTheme.bodySmall?.copyWith(
              color: profileState.imageFile != null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: profileState.imageFile != null
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImagePickerModal(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final profileState = ref.read(editProfileProvider);
    final profileNotifier = ref.read(editProfileProvider.notifier);

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Photo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            if (profileState.imageFile != null ||
                profileState.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  profileNotifier.removePhoto();
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source != null) {
      bool hasPermission = false;

      if (source == ImageSource.camera) {
        hasPermission = await PermissionService().requestCameraPermission();
      } else if (source == ImageSource.gallery) {
        hasPermission = await PermissionService().requestStoragePermissions();
      }

      if (hasPermission) {
        await profileNotifier.pickImage(source);

        // Show error if any
        final error = ref.read(editProfileProvider).error;
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
          profileNotifier.clearError();
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin diperlukan untuk mengakses foto/kamera'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
}
