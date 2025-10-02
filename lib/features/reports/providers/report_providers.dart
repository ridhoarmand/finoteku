import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../../../services/supabase_service.dart';

// Service provider
final reportServiceProvider = Provider<ReportService>((ref) {
  return const ReportService();
});

// State provider untuk report state
final reportStateProvider = StateProvider<ReportState>((ref) {
  return ReportState(
    selectedMonth: DateTime.now(),
    period: ReportPeriod.monthly,
    type: ReportType.expense,
    showDetailCategories: false,
  );
});

// Report data provider
final reportDataProvider = FutureProvider.family<ReportData, String>((
  ref,
  userId,
) async {
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

  switch (state.period) {
    case ReportPeriod.weekly:
      final previousWeek = state.selectedMonth.subtract(
        const Duration(days: 7),
      );
      return previousWeek.isAfter(twoYearsAgo);
    case ReportPeriod.monthly:
      final previousMonth = DateTime(
        state.selectedMonth.year,
        state.selectedMonth.month - 1,
      );
      return previousMonth.isAfter(twoYearsAgo);
    case ReportPeriod.yearly:
      final previousYear = DateTime(state.selectedMonth.year - 1);
      return previousYear.isAfter(twoYearsAgo);
  }
});

final canGoToNextPeriodProvider = Provider<bool>((ref) {
  final state = ref.watch(reportStateProvider);
  final now = DateTime.now();

  switch (state.period) {
    case ReportPeriod.weekly:
      final nextWeek = state.selectedMonth.add(const Duration(days: 7));
      return nextWeek.isBefore(now) || _isSameWeek(nextWeek, now);
    case ReportPeriod.monthly:
      final nextMonth = DateTime(
        state.selectedMonth.year,
        state.selectedMonth.month + 1,
      );
      return nextMonth.month <= now.month && nextMonth.year <= now.year;
    case ReportPeriod.yearly:
      final nextYear = DateTime(state.selectedMonth.year + 1);
      return nextYear.year <= now.year;
  }
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
  DateTime newPeriod;

  switch (state.period) {
    case ReportPeriod.weekly:
      newPeriod = state.selectedMonth.subtract(const Duration(days: 7));
      break;
    case ReportPeriod.monthly:
      newPeriod = DateTime(
        state.selectedMonth.year,
        state.selectedMonth.month - 1,
      );
      break;
    case ReportPeriod.yearly:
      newPeriod = DateTime(state.selectedMonth.year - 1);
      break;
  }

  ref.read(reportStateProvider.notifier).state = state.copyWith(
    selectedMonth: newPeriod,
  );
}

void goToNextPeriod(WidgetRef ref) {
  final state = ref.read(reportStateProvider);
  DateTime newPeriod;

  switch (state.period) {
    case ReportPeriod.weekly:
      newPeriod = state.selectedMonth.add(const Duration(days: 7));
      break;
    case ReportPeriod.monthly:
      newPeriod = DateTime(
        state.selectedMonth.year,
        state.selectedMonth.month + 1,
      );
      break;
    case ReportPeriod.yearly:
      newPeriod = DateTime(state.selectedMonth.year + 1);
      break;
  }

  ref.read(reportStateProvider.notifier).state = state.copyWith(
    selectedMonth: newPeriod,
  );
}

void toggleReportType(WidgetRef ref) {
  final state = ref.read(reportStateProvider);
  final newType = state.type == ReportType.income
      ? ReportType.expense
      : ReportType.income;

  ref.read(reportStateProvider.notifier).state = state.copyWith(type: newType);
}

void toggleDetailCategories(WidgetRef ref) {
  final state = ref.read(reportStateProvider);
  ref.read(reportStateProvider.notifier).state = state.copyWith(
    showDetailCategories: !state.showDetailCategories,
  );
}

void changePeriodType(WidgetRef ref, ReportPeriod newPeriod) {
  final state = ref.read(reportStateProvider);
  ref.read(reportStateProvider.notifier).state = state.copyWith(
    period: newPeriod,
  );
}
