import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/supabase_service.dart';
import '../providers/edit_profile_provider.dart';
import '../widgets/profile_avatar_widget.dart';
import '../widgets/profile_form_widget.dart';
import '../widgets/save_profile_button.dart';
import '../widgets/account_settings_widget.dart';
import '../../../core/localization/app_localizations.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Just populate the controllers, don't update provider state yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _populateControllers();
    });
  }

  void _populateControllers() {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        _fullNameController.text = user.userMetadata?['full_name'] ?? '';
        _emailController.text = user.email ?? '';
        _phoneController.text = user.userMetadata?['phone'] ?? '';
      }
    } catch (e) {
      // Handle error silently or show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(editProfileProvider);

    // Show error if any
    if (profileState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileState.error!),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: ref.tr(context, 'dismiss'),
              onPressed: () {
                ref.read(editProfileProvider.notifier).clearError();
              },
            ),
          ),
        );
      });
    }

    return PopScope(
      canPop: !profileState.hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && profileState.hasChanges) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop && context.mounted) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(ref.tr(context, 'edit_profile')),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _handleBackPress(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Avatar Section
              ProfileAvatarWidget(fullNameController: _fullNameController),
              const SizedBox(height: 12),

              // Profile Form
              ProfileFormWidget(
                formKey: _formKey,
                fullNameController: _fullNameController,
                emailController: _emailController,
                phoneController: _phoneController,
              ),
              const SizedBox(height: 12),

              // Save Button
              SaveProfileButton(
                formKey: _formKey,
                fullNameController: _fullNameController,
                phoneController: _phoneController,
              ),
              const SizedBox(height: 10),

              // Account Settings Section
              const AccountSettingsWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBackPress() async {
    final profileState = ref.read(editProfileProvider);
    if (profileState.hasChanges) {
      final shouldDiscard = await _showDiscardDialog();
      if (shouldDiscard) {
        if (mounted) {
          context.pop();
        }
      }
    } else {
      if (mounted) {
        context.pop();
      }
    }
  }

  Future<bool> _showDiscardDialog() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }
}
