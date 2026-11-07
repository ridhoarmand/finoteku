import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../services/user_service.dart';
import '../providers/language_preference_provider.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    // Get current locale if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentLocale = Localizations.localeOf(context).languageCode;
      setState(() {
        _selectedLanguage = currentLocale == 'id' ? 'id' : 'en';
      });
    });
  }

  // Update language selection and immediately change locale
  Future<void> _selectLanguage(String languageCode) async {
    if (_selectedLanguage == languageCode) return;

    setState(() {
      _selectedLanguage = languageCode;
    });

    // Immediately update the locale provider for real-time language change
    await ref.read(appLocaleProvider.notifier).setLanguage(languageCode);

    debugPrint('Language updated to: $languageCode');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // App Logo
              Center(
                child: Image.asset(
                  'assets/icon_transparent.png',
                  width: 100,
                  height: 100,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                ref.tr(context, 'choose_language_title'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                ref.tr(context, 'choose_language_subtitle'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Language Options
              _buildLanguageOption(
                context: context,
                languageCode: 'en',
                languageName: ref.tr(context, 'language_english'),
                flag: '🇺🇸',
                isSelected: _selectedLanguage == 'en',
                onTap: () => _selectLanguage('en'),
              ),

              const SizedBox(height: 16),

              _buildLanguageOption(
                context: context,
                languageCode: 'id',
                languageName: ref.tr(context, 'language_indonesian'),
                flag: '🇮🇩',
                isSelected: _selectedLanguage == 'id',
                onTap: () => _selectLanguage('id'),
              ),

              const Spacer(),

              // Continue Button
              FilledButton(
                onPressed: () => _saveLanguageAndContinue(),
                child: Text(ref.tr(context, 'continue_button')),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String languageCode,
    required String languageName,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isSelected ? 8 : 2,
      shadowColor: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  languageName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  PhFill.checkCircle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveLanguageAndContinue() async {
    try {
      // Save language preference to user service (for onboarding tracking)
      final userService = ref.read(userServiceProvider);
      await userService.saveLanguagePreference(_selectedLanguage);
      debugPrint('Language preference saved: $_selectedLanguage');

      // Refresh the language preference provider to update router logic
      ref.invalidate(hasLanguagePreferenceProvider);
      debugPrint('Language preference provider invalidated');

      // Small delay to ensure provider refresh is processed
      await Future.delayed(const Duration(milliseconds: 200));

      // Navigate to onboarding
      if (mounted) {
        debugPrint('Navigating to onboarding...');
        context.pushReplacement('/onboarding');
      }
    } catch (e) {
      debugPrint('Error in _saveLanguageAndContinue: $e');
    }
  }
}
