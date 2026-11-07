import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/edit_profile_provider.dart';
import '../../../core/localization/app_localizations.dart';

class ProfileFormWidget extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  const ProfileFormWidget({
    super.key,
    required this.formKey,
    required this.fullNameController,
    required this.emailController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Information Section
          Text(
            ref.tr(context, 'personal_info'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Full Name Field
          TextFormField(
            controller: fullNameController,
            decoration: InputDecoration(
              labelText: ref.tr(context, 'full_name'),
              hintText: ref.tr(context, 'full_name_hint'),
              prefixIcon: const Icon(PhRegular.user),
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => ref.read(editProfileProvider.notifier).setHasChanges(true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return ref.tr(context, 'full_name_required');
              }
              if (value.trim().length < 2) {
                return ref.tr(context, 'full_name_min_length');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email Field (Read-only)
          TextFormField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: ref.tr(context, 'email_address'),
              hintText: ref.tr(context, 'email_address_hint'),
              prefixIcon: const Icon(PhRegular.envelopeSimple),
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(PhRegular.lock),
            ),
            readOnly: true,
            enabled: false,
          ),
          const SizedBox(height: 4),
          Text(
            ref.tr(context, 'email_locked_note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Phone Field
          TextFormField(
            controller: phoneController,
            decoration: InputDecoration(
              labelText: ref.tr(context, 'phone_number'),
              hintText: ref.tr(context, 'phone_number_hint'),
              prefixIcon: const Icon(PhRegular.phone),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onChanged: (_) => ref.read(editProfileProvider.notifier).setHasChanges(true),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                // Basic phone validation
                final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
                if (!phoneRegex.hasMatch(value.trim())) {
                  return ref.tr(context, 'phone_invalid');
                }
                if (value.trim().length < 10) {
                  return ref.tr(context, 'phone_too_short');
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
