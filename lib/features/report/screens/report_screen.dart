import 'package:flutter/material.dart';
import '../../budget/providers/budget_providers.dart';
import '../../budget/widgets/budget_view.dart';
import '../widgets/category_donut.dart';
import '../../../widgets/amount_text.dart';
import '../../../theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../providers/report_providers.dart';
import '../widgets/report_header.dart';
import '../widgets/income_expense_toggle.dart';
import '../widgets/category_list_tile.dart';
import '../widgets/category_transactions_sheet.dart';
import '../../transaction/screens/transaction_detail_screen.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../wallet/widgets/wallet_picker_sheet.dart';
import '../../../widgets/filter_chip_button.dart';
import '../../../core/localization/app_localizations.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId != null) {
      ref.invalidate(reportDataProvider(currentUserId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final reportState = ref.watch(reportStateProvider);

    if (currentUserId == null) {
      return Scaffold(
        body: Center(child: Text(ref.tr(context, 'login_required_short'))),
      );
    }

    final reportDataAsync = ref.watch(reportDataProvider(currentUserId));
    final tab = ref.watch(reportTabProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Invalidate report data provider to reload data
            ref.invalidate(reportDataProvider(currentUserId));
            ref.read(budgetRefreshProvider.notifier).bump();
          },
          child: Column(
            children: [
              // Header
              const ReportHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ReportTab>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: ReportTab.report, icon: const Icon(PhRegular.chartPieSlice), label: Text(ref.tr(context, 'budget_tab_report'))),
                      ButtonSegment(value: ReportTab.budget, icon: const Icon(PhRegular.piggyBank), label: Text(ref.tr(context, 'budget_tab_budget'))),
                    ],
                    selected: {tab},
                    onSelectionChanged: (s) => ref.read(reportTabProvider.notifier).show(s.first),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: tab == ReportTab.budget
                    ? BudgetView(userId: currentUserId, month: reportState.selectedMonth)
                    : reportDataAsync.when(
                  data: (data) => _buildContent(data, reportState),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhRegular.warningCircle,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ref.tr(context, 'report_load_failed'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(reportDataProvider(currentUserId));
                          },
                          child: Text(ref.tr(context, 'retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ReportData data, ReportState reportState) {
    final theme = Theme.of(context);
    final muted = context.colors.muted;
    final isExpense = data.type == ReportType.expense;
    String change() {
      if (data.previousPeriodAmount == 0) return ref.tr(context, 'report_no_previous');
      final p = data.changePercentage.abs().round();
      if (p == 0) return ref.tr(context, 'report_change_same');
      return ref
          .tr(context, data.changePercentage > 0 ? 'report_change_up' : 'report_change_down')
          .replaceAll('{p}', '$p');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const IncomeExpenseToggle(),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: _WalletFilter(reportState)),
        const SizedBox(height: 20),
        // The period total is the focal number; the ranked list below explains it.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr(context, isExpense ? 'report_total_expense' : 'report_total_income'),
                    style: theme.textTheme.labelLarge?.copyWith(color: muted),
                  ),
                  AmountText(data.totalAmount, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(change(), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                ],
              ),
            ),
            if (data.categories.isNotEmpty) ...[
              const SizedBox(width: 16),
              CategoryDonut(categories: data.categories),
            ],
          ],
        ),
        const SizedBox(height: 20),
        if (data.categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(PhRegular.chartPieSlice, size: 40, color: muted),
                const SizedBox(height: 12),
                Text(
                  ref.tr(context, 'report_empty_title').replaceAll('{type}', ref.tr(context, isExpense ? 'expense' : 'income').toLowerCase()),
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(ref.tr(context, 'report_empty_body'), style: theme.textTheme.bodyMedium?.copyWith(color: muted), textAlign: TextAlign.center),
              ],
            ),
          )
        else
          Card(clipBehavior: Clip.antiAlias, child: _buildCategoryList(data, reportState)),
      ],
    );
  }

  Widget _buildCategoryList(ReportData data, ReportState reportState) {
    final theme = Theme.of(context);
    final categories = data.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhRegular.chartPieSlice,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              reportState.type == ReportType.income
                  ? 'Belum ada data pemasukan'
                  : 'Belum ada data pengeluaran',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ref.tr(context, 'start_recording'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Tampilkan maksimal 6 kategori (sesuai dengan chart) + Others jika ada
    final displayCategories = categories.take(6).toList();
    final hasOthers = categories.length > 6;

    final totalAmount = categories.fold<double>(
      0,
      (sum, cat) => sum + cat.amount,
    );

    final maxAmount = displayCategories.isEmpty ? 1.0 : displayCategories.first.amount;
    // lives inside the screen's ListView: no own scrolling
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      separatorBuilder: (_, _) => const Divider(indent: 68),
      itemCount: displayCategories.length + (hasOthers ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < displayCategories.length) {
          final category = displayCategories[index];
          return CategoryListTile(
            category: category,
            index: index,
            relativeToMax: maxAmount > 0 ? category.amount / maxAmount : 0,
            onTap: () => _handleCategoryTap(category, reportState),
          );
        } else {
          // Others category
          final othersAmount = categories
              .skip(6)
              .fold<double>(0, (sum, cat) => sum + cat.amount);
          final othersPercentage = totalAmount > 0
              ? (othersAmount / totalAmount * 100).toDouble()
              : 0.0;

          final othersCategory = CategoryReportItem(
            id: 'others',
            name: 'Lainnya',
            amount: othersAmount,
            percentage: othersPercentage,
            transactionCount: categories
                .skip(6)
                .fold<int>(0, (sum, cat) => sum + cat.transactionCount),
            type: categories.first.type,
            icon: PhRegular.dotsThree,
            parentId: null,
            children: [],
          );

          return CategoryListTile(
            category: othersCategory,
            index: 6, // Grey color index
            onTap: () =>
                _showOthersDetail(categories.skip(6).toList(), reportState),
          );
        }
      },
    );
  }

  void _handleCategoryTap(
    CategoryReportItem category,
    ReportState state,
  ) async {
    if (category.hasChildren) {
      await _showSubcategoryDetail(category, state);
    } else {
      _showCategoryTransactions(category, state);
    }
  }

  Future<void> _showSubcategoryDetail(
    CategoryReportItem parentCategory,
    ReportState state,
  ) async {
    final theme = Theme.of(context);
    final children = parentCategory.children ?? [];

    final selectedCategory = await showModalBottomSheet<CategoryReportItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ref
                          .tr(context, 'report_subcategory_of')
                          .replaceAll('{name}', parentCategory.name),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(PhRegular.x),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Subcategory list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Parent category option (Semua)
                  CategoryListTile(
                    category: CategoryReportItem(
                      id: parentCategory.id,
                      name: 'Semua ${parentCategory.name}',
                      icon: parentCategory.icon,
                      type: parentCategory.type,
                      amount: parentCategory.amount,
                      percentage: parentCategory.percentage,
                      transactionCount: parentCategory.transactionCount,
                    ),
                    index: 9,
                    onTap: () {
                      Navigator.pop(context, parentCategory);
                    },
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text(
                          ref.tr(context, 'report_subcategory_detail'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: context.colors.muted,
                          ),
                        ),
                        Expanded(child: Divider(indent: 8)),
                      ],
                    ),
                  ),

                  ...children.asMap().entries.map((entry) {
                    final index = entry.key;
                    final child = entry.value;
                    return CategoryListTile(
                      category: child,
                      index: index % 10,
                      onTap: () {
                        Navigator.pop(context, child);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedCategory != null && mounted) {
      await Future.delayed(Duration.zero);
      _showCategoryTransactions(selectedCategory, state);
    }
  }

  Future<void> _showCategoryTransactions(
    CategoryReportItem category,
    ReportState state,
  ) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final startTime = DateTime.now();

    // Show loading dialog safely
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final transactions = await const ReportService()
          .getTransactionsByCategory(
            userId: currentUserId,
            categoryId: category.id,
            period: state.selectedMonth,
            periodType: state.period,
            walletId: state.walletId,
          );

      if (!mounted) return;

      // Ensure the dialog has been open for at least 150ms to avoid transition conflicts
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 150) {
        await Future.delayed(Duration(milliseconds: 150 - elapsed));
      }

      if (!mounted) return;

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else {
        Navigator.of(context).pop();
      }

      // Wait a brief moment for the dialog's closing transition to settle
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      // Show sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => CategoryTransactionsSheet(
          category: category,
          transactions: transactions,
          onTransactionTap: (transactionId) async {
            // Navigate to detail
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TransactionDetailScreen(transactionId: transactionId),
              ),
            );

            // If transaction changed/deleted, refresh report and close sheet
            if (result == true && mounted) {
              Navigator.of(context).pop();
              ref.invalidate(reportDataProvider(currentUserId));
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Ensure dialog is closed on error
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref
                .tr(context, 'error_loading_transactions')
                .replaceAll('{error}', '$e'),
          ),
        ),
      );
    }
  }

  void _showOthersDetail(
    List<CategoryReportItem> otherCategories,
    ReportState state,
  ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ref.tr(context, 'report_other_category_detail'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(PhRegular.x),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Category list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: otherCategories.length,
                itemBuilder: (context, index) {
                  final category = otherCategories[index];
                  return CategoryListTile(
                    category: category,
                    index: (index + 6) % 10, // Continue color pattern
                    onTap: () => _handleCategoryTap(category, state),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Narrows the report to one wallet. Uses [walletsProvider] (hidden wallets included):
/// their past transactions still belong in a report.
class _WalletFilter extends ConsumerWidget {
  final ReportState state;
  const _WalletFilter(this.state);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();
    final wallets = ref.watch(walletsProvider(userId)).value ?? const [];
    final wallet = wallets.where((w) => w.id == state.walletId).firstOrNull;
    final n = ref.read(reportStateProvider.notifier);
    final all = ref.tr(context, 'all_wallets');
    return FilterChipButton(
      icon: PhRegular.wallet,
      label: wallet?.name ?? all,
      active: wallet != null,
      onTap: () async {
        final pick = await showWalletPicker(context, wallets: wallets, selectedId: state.walletId);
        if (pick != null) n.updateState(ref.read(reportStateProvider).copyWith(walletId: pick.walletId));
      },
      onClear: () => n.updateState(ref.read(reportStateProvider).copyWith(walletId: null)),
      clearTooltip: all,
    );
  }
}
