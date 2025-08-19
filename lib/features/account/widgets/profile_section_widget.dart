import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/localization/app_localizations.dart';

class ProfileSectionWidget extends ConsumerWidget {
  final User? user;

  const ProfileSectionWidget({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primary,
              child: user?.userMetadata?['avatar_url'] != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: user!.userMetadata!['avatar_url'],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                        errorWidget: (context, url, error) => Text(
                          (user?.userMetadata?['full_name'] as String?)
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              'U',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      (user?.userMetadata?['full_name'] as String?)
                              ?.substring(0, 1)
                              .toUpperCase() ??
                          'U',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user?.userMetadata?['full_name'] != null)
                    Text(
                      user!.userMetadata!['full_name'],
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    user?.email ?? ref.tr(context, 'unknown_user'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      context.push('/account/edit-profile');
                    },
                    child: Text(ref.tr(context, 'edit_profile')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
