import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';

class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodProvider);
    void setPeriod(String p) => ref.read(analyticsPeriodProvider.notifier).state = p;
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'week', label: Text('Minggu')),
        ButtonSegment(value: 'month', label: Text('Bulan')),
        ButtonSegment(value: 'year', label: Text('Tahun')),
      ],
      selected: {period},
      onSelectionChanged: (s) => setPeriod(s.first),
    );
  }
}
