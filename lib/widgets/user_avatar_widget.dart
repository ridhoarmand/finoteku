import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserAvatarWidget extends StatelessWidget {
  final User? user;
  final double radius;

  const UserAvatarWidget({
    super.key,
    required this.user,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary,
      child: user?.userMetadata?['avatar_url'] != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: user!.userMetadata!['avatar_url'],
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => SizedBox(
                  width: radius * 0.8,
                  height: radius * 0.8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                errorWidget: (context, url, error) => Text(
                  (user?.userMetadata?['full_name'] as String?)
                          ?.substring(0, 1)
                          .toUpperCase() ??
                      'U',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.8,
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
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}