import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_provider.dart';
import '../../../core/localization/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<OnboardingPageData> _getPages(BuildContext context) {
    return [
      OnboardingPageData(
        title: ref.tr(context, 'onboarding_1_title'),
        description: ref.tr(context, 'onboarding_1_subtitle'),
        image: 'assets/onboardings/image1.png',
      ),
      OnboardingPageData(
        title: ref.tr(context, 'onboarding_2_title'),
        description: ref.tr(context, 'onboarding_2_subtitle'),
        image: 'assets/onboardings/image2.png',
      ),
      OnboardingPageData(
        title: ref.tr(context, 'onboarding_3_title'),
        description: ref.tr(context, 'onboarding_3_subtitle'),
        image: 'assets/onboardings/image3.png',
      ),
    ];
  }

  void _nextPage() {
    final pages = _getPages(context);
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    debugPrint('🚀 Onboarding: _completeOnboarding called');

    try {
      debugPrint('🚀 Onboarding: Setting onboarding complete...');
      await ref.read(onboardingProvider.notifier).setOnboardingComplete();
      debugPrint('🚀 Onboarding: Onboarding complete set successfully');

      if (mounted) {
        debugPrint('🚀 Onboarding: Waiting for provider to rebuild...');
        // Give provider time to rebuild before navigation
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          debugPrint('🚀 Onboarding: Navigating to login...');
          // Use go instead of pushReplacement to avoid router conflicts
          context.go('/login');
          debugPrint('🚀 Onboarding: Navigation to login completed');
        }
      }
    } catch (e) {
      debugPrint('❌ Error completing onboarding: $e');
      // Still try to navigate on error
      if (mounted) {
        debugPrint(
          '🚀 Onboarding: Error occurred, still trying to navigate...',
        );
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          context.go('/login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(ref.tr(context, 'skip_button')),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _getPages(context).length,
                itemBuilder: (context, index) {
                  final page = _getPages(context)[index];
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Image
                        Container(
                          width: 250,
                          height: 250,
                          decoration: const BoxDecoration(
                            shape: BoxShape.rectangle,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              page.image,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback jika image tidak ditemukan
                                return Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    PhRegular.imageBroken,
                                    size: 64,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          page.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          page.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _getPages(context).length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _getPages(context).length - 1
                        ? ref.tr(context, 'get_started_button')
                        : ref.tr(context, 'next_button'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final String image;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.image,
  });
}
