import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/edit_profile_provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/localization/app_localizations.dart';

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
                    : (profileState.avatarUrl != null &&
                              profileState.avatarUrl!.isNotEmpty
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
                                errorWidget: (context, url, error) {
                                  debugPrint('Avatar load error: $error');
                                  return Text(
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
                                  );
                                },
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
                    tooltip: ref.tr(context, 'change_photo'),
                    icon: Icon(
                      PhRegular.camera,
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
                ? ref.tr(context, 'photo_new_selected')
                : ref.tr(context, 'photo_tap_to_change'),
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
                ref.trRead('photo_select_title'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(PhRegular.camera),
              title: Text(ref.trRead('photo_camera')),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(PhRegular.images),
              title: Text(ref.trRead('photo_gallery')),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            if (profileState.imageFile != null ||
                profileState.avatarUrl != null)
              ListTile(
                leading: const Icon(PhRegular.trash, color: Colors.red),
                title: Text(
                  ref.trRead('photo_remove'),
                  style: const TextStyle(color: Colors.red),
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
            SnackBar(
              content: Text(ref.trRead('photo_permission_required')),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
}
