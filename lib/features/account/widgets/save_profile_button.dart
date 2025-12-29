import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../providers/edit_profile_provider.dart';

class SaveProfileButton extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;

  const SaveProfileButton({
    super.key,
    required this.formKey,
    required this.fullNameController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileState = ref.watch(editProfileProvider);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: profileState.isLoading
            ? null
            : () => _saveProfile(context, ref),
        icon: profileState.isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(profileState.isLoading
            ? ref.tr(context, 'saving')
            : ref.tr(context, 'save_changes')),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: profileState.hasChanges || profileState.isLoading
              ? null
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: profileState.hasChanges || profileState.isLoading
              ? null
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _saveProfile(BuildContext context, WidgetRef ref) async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final profileNotifier = ref.read(editProfileProvider.notifier);

    final success = await profileNotifier.saveProfile(
      fullName: fullNameController.text,
      phone: phoneController.text,
      ref: ref,
    );

    if (context.mounted) {
      final error = ref.read(editProfileProvider).error;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr(context, 'profile_updated_successfully')),
            backgroundColor: Colors.green,
          ),
        );
      } else if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr(context, error)),
            backgroundColor: Colors.red,
          ),
        );
        profileNotifier.clearError();
      }
    }
  }
}
