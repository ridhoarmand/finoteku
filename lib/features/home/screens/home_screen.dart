import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/supabase_service.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/monthly_summary_section.dart';
import '../widgets/recent_transactions_section.dart';
import '../widgets/home_balance_card.dart';
import '../../../widgets/user_avatar_widget.dart';
import '../../transaction/screens/add_edit_transaction_screen.dart';
import '../../transaction/providers/transaction_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = SupabaseService.currentUser;
    final userId = currentUser?.id;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Invalidate all relevant providers
            if (userId != null) {
              ref.invalidate(walletsProvider(userId));
              ref.invalidate(activeWalletsProvider(userId));
              ref.invalidate(totalBalanceProvider(userId));
              ref.read(transactionRefreshTriggerProvider.notifier).bump();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                  child: Builder(
                    builder: (context) {
                      String greetingForLocale(DateTime now, String lang) {
                        final hour = now.hour;
                        final isMorning = hour >= 5 && hour <= 10;
                        final isNoon = hour >= 11 && hour <= 14;
                        final isAfternoon = hour >= 15 && hour <= 17;
                        if (isMorning) {
                          return ref.tr(context, 'greeting_morning');
                        }
                        if (isNoon) {
                          return ref.tr(context, 'greeting_afternoon');
                        }
                        if (isAfternoon) {
                          return ref.tr(context, 'greeting_evening');
                        }
                        return ref.tr(context, 'greeting_night');
                      }

                      final lang = Localizations.localeOf(context).languageCode;
                      final greeting = greetingForLocale(DateTime.now(), lang);
                      // Try to get a nicer display name from user metadata if available
                      final meta = currentUser?.userMetadata ?? {};
                      final name =
                          (meta['full_name'] ??
                                  meta['name'] ??
                                  meta['username'])
                              ?.toString();
                      final fallbackUser = ref.tr(context, 'user_fallback');
                      final displayName =
                          (name != null && name.trim().isNotEmpty)
                          ? name.trim()
                          : (currentUser?.email?.split('@').first ??
                                fallbackUser);

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                UserAvatarWidget(user: currentUser, radius: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        greeting,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                      Text(
                                        displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
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
                ),
                const SizedBox(height: 16),

                // Balance Card
                if (userId != null)
                  Consumer(
                    builder: (context, ref, child) {
                      final walletsAsync = ref.watch(walletsProvider(userId));
                      return HomeBalanceCard(walletsAsync: walletsAsync);
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.88),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                ref.tr(context, 'total_balance'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ref.tr(context, 'login_required_balance'),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  fontSize: 28,
                                ),
                          ),
                        ],
                      ),
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
      ),
      floatingActionButton: userId != null
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddEditTransactionScreen(),
                  ),
                );

                // Refresh data if transaction was added successfully
                if (result == true) {
                  // Trigger refresh for wallets and transactions
                  ref.invalidate(activeWalletsProvider(userId));
                  ref.invalidate(totalBalanceProvider(userId));
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
