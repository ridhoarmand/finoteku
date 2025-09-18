import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/supabase_service.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../core/state/balance_visibility_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/monthly_summary_section.dart';
import '../widgets/recent_transactions_section.dart';
import '../../../widgets/user_avatar_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = SupabaseService.currentUser;
    final userId = currentUser?.id;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Builder(
                builder: (context) {
                  String greetingForLocale(DateTime now, String lang) {
                    final hour = now.hour;
                    final isMorning = hour >= 5 && hour <= 10;
                    final isNoon = hour >= 11 && hour <= 14;
                    final isAfternoon = hour >= 15 && hour <= 17;
                    if (isMorning) return ref.tr(context, 'greeting_morning');
                    if (isNoon) return ref.tr(context, 'greeting_afternoon');
                    if (isAfternoon) return ref.tr(context, 'greeting_evening');
                    return ref.tr(context, 'greeting_night');
                  }

                  final lang = Localizations.localeOf(context).languageCode;
                  final greeting = greetingForLocale(DateTime.now(), lang);
                  // Try to get a nicer display name from user metadata if available
                  final meta = currentUser?.userMetadata ?? {};
                  final name =
                      (meta['full_name'] ?? meta['name'] ?? meta['username'])
                          ?.toString();
                  final fallbackUser = ref.tr(context, 'user_fallback');
                  final displayName = (name != null && name.trim().isNotEmpty)
                      ? name.trim()
                      : (currentUser?.email?.split('@').first ?? fallbackUser);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            UserAvatarWidget(
                              user: currentUser,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    greeting,
                                    style: Theme.of(context).textTheme.titleMedium
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    displayName,
                                    style: Theme.of(context).textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Balance Card
              if (userId != null)
                Consumer(
                  builder: (context, ref, child) {
                    final totalBalanceAsync = ref.watch(
                      totalBalanceProvider(userId),
                    );
                    final isVisible = ref.watch(balanceVisibilityProvider);

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.tr(context, 'total_balance'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: totalBalanceAsync.when(
                                  data: (balance) => FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      isVisible
                                          ? CurrencyFormatter.format(
                                              balance,
                                              'IDR',
                                            )
                                          : '••••••••',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  loading: () => const Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox.square(
                                      dimension: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  error: (error, stackTrace) => Text(
                                    isVisible
                                        ? CurrencyFormatter.format(0, 'IDR')
                                        : '••••••••',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  final current = ref.read(
                                    balanceVisibilityProvider,
                                  );
                                  ref
                                          .read(
                                            balanceVisibilityProvider.notifier,
                                          )
                                          .state =
                                      !current;
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    isVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white70,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.tr(context, 'total_balance'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ref.tr(context, 'login_required_balance'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Monthly Summary
              if (userId != null) MonthlySummarySection(userId: userId),
              if (userId != null) const SizedBox(height: 8),

              // Recent Transactions header + See all
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ref.tr(context, 'recent_transactions'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/transaction'),
                    child: Text(ref.tr(context, 'see_all')),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recent Transactions list or placeholder
              Expanded(
                child: userId == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              ref.tr(context, 'login_required_short'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ref.tr(context, 'login_required_continue'),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RecentTransactionsSection(userId: userId),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
 
