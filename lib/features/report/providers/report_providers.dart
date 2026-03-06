import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../../transaction/providers/transaction_providers.dart';
import '../../../services/supabase_service.dart';

// Service provider
final reportServiceProvider = Provider<ReportService>((ref) {
  return const ReportService();
});

// State notifier untuk report state
class ReportStateNotifier extends Notifier<ReportState> {
  @override
  ReportState build() {
    return ReportState(
      selectedMonth: DateTime.now(),
      period: ReportPeriod.monthly,
      type: ReportType.expense,
      showDetailCategories: false,
    );
  }

  void updateState(ReportState newState) {
    state = newState;
  }

  void updateSelectedMonth(DateTime month) {
    state = state.copyWith(selectedMonth: month);
  }

  void toggleType() {
    final newType = state.type == ReportType.income
        ? ReportType.expense
        : ReportType.income;
    state = state.copyWith(type: newType);
  }

  void toggleDetailCategories() {
    state = state.copyWith(showDetailCategories: !state.showDetailCategories);
  }

  void updatePeriod(ReportPeriod period) {
    state = state.copyWith(period: period);
  }
}

final reportStateProvider = NotifierProvider<ReportStateNotifier, ReportState>(
  ReportStateNotifier.new,
);

final reportDataProvider = FutureProvider.autoDispose
    .family<ReportData, String>((ref, userId) async {
      // Watch transaction refresh trigger agar report auto-refresh
      ref.watch(transactionRefreshTriggerProvider);
      final reportService = ref.read(reportServiceProvider);
      final state = ref.watch(reportStateProvider);

      return await reportService.getReportData(
        userId: userId,
        period: state.selectedMonth,
        type: state.type,
        periodType: state.period,
        showDetailCategories: state.showDetailCategories,
      );
    });

// Helper providers untuk UI
final currentUserIdProvider = Provider<String?>((ref) {
  return SupabaseService.currentUserId;
});

// Period navigation providers
final canGoToPreviousPeriodProvider = Provider<bool>((ref) {
  final state = ref.watch(reportStateProvider);
  // Allow going back up to 2 years
  final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));

  return switch (state.period) {
    ReportPeriod.weekly =>
      state.selectedMonth
          .subtract(const Duration(days: 7))
          .isAfter(twoYearsAgo),
    ReportPeriod.monthly => DateTime(
      state.selectedMonth.year,
      state.selectedMonth.month - 1,
    ).isAfter(twoYearsAgo),
    ReportPeriod.yearly => DateTime(
      state.selectedMonth.year - 1,
    ).isAfter(twoYearsAgo),
  };
});

final canGoToNextPeriodProvider = Provider<bool>((ref) {
  final state = ref.watch(reportStateProvider);
  final now = DateTime.now();

  return switch (state.period) {
    ReportPeriod.weekly => () {
      final nextWeek = state.selectedMonth.add(const Duration(days: 7));
      return nextWeek.isBefore(now) || _isSameWeek(nextWeek, now);
    }(),
    ReportPeriod.monthly => () {
      final nextMonth = DateTime(
        state.selectedMonth.year,
        state.selectedMonth.month + 1,
      );
      // Compare using isAfter to properly handle year boundaries
      return !nextMonth.isAfter(DateTime(now.year, now.month));
    }(),
    ReportPeriod.yearly =>
      DateTime(state.selectedMonth.year + 1).year <= now.year,
  };
});

// Helper function to check if two dates are in the same week
bool _isSameWeek(DateTime date1, DateTime date2) {
  final startOfWeek1 = date1.subtract(Duration(days: date1.weekday - 1));
  final startOfWeek2 = date2.subtract(Duration(days: date2.weekday - 1));
  return startOfWeek1.year == startOfWeek2.year &&
      startOfWeek1.month == startOfWeek2.month &&
      startOfWeek1.day == startOfWeek2.day;
}

// Navigation functions
void goToPreviousPeriod(WidgetRef ref) {
  final state = ref.read(reportStateProvider);

  final newPeriod = switch (state.period) {
    ReportPeriod.weekly => state.selectedMonth.subtract(
      const Duration(days: 7),
    ),
    ReportPeriod.monthly => DateTime(
      state.selectedMonth.year,
      state.selectedMonth.month - 1,
    ),
    ReportPeriod.yearly => DateTime(state.selectedMonth.year - 1),
  };

  ref.read(reportStateProvider.notifier).updateSelectedMonth(newPeriod);
}

void goToNextPeriod(WidgetRef ref) {
  final state = ref.read(reportStateProvider);

  final newPeriod = switch (state.period) {
    ReportPeriod.weekly => state.selectedMonth.add(const Duration(days: 7)),
    ReportPeriod.monthly => DateTime(
      state.selectedMonth.year,
      state.selectedMonth.month + 1,
    ),
    ReportPeriod.yearly => DateTime(state.selectedMonth.year + 1),
  };

  ref.read(reportStateProvider.notifier).updateSelectedMonth(newPeriod);
}

void toggleReportType(WidgetRef ref) {
  ref.read(reportStateProvider.notifier).toggleType();
}

void toggleDetailCategories(WidgetRef ref) {
  ref.read(reportStateProvider.notifier).toggleDetailCategories();
}

void changePeriodType(WidgetRef ref, ReportPeriod newPeriod) {
  ref.read(reportStateProvider.notifier).updatePeriod(newPeriod);
}
