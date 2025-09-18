import 'package:flutter/material.dart';
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
                child: Image.asset('assets/icon.png', width: 100, height: 100),
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
                onTap: () => setState(() => _selectedLanguage = 'en'),
              ),

              const SizedBox(height: 16),

              _buildLanguageOption(
                context: context,
                languageCode: 'id',
                languageName: ref.tr(context, 'language_indonesian'),
                flag: '🇮🇩',
                isSelected: _selectedLanguage == 'id',
                onTap: () => setState(() => _selectedLanguage = 'id'),
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
                  Icons.check_circle,
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
      // Save language preference
      final userService = ref.read(userServiceProvider);
      await userService.saveLanguagePreference(_selectedLanguage);
      debugPrint('Language preference saved: $_selectedLanguage');

      // Update the locale provider to reflect the new language immediately
      await ref.read(appLocaleProvider.notifier).setLanguage(_selectedLanguage);
      debugPrint('Locale provider updated');

      // Refresh the language preference provider to update router logic
      ref.invalidate(hasLanguagePreferenceProvider);
      debugPrint('Language preference provider invalidated');

      // Small delay to ensure provider refresh is processed
      await Future.delayed(const Duration(milliseconds: 200));

      // Try using pushReplacement instead of go to avoid conflicts
      if (mounted) {
        debugPrint('Navigating to onboarding...');
        context.pushReplacement('/onboarding');
      }
    } catch (e) {
      debugPrint('Error in _saveLanguageAndContinue: $e');
    }
  }
}
