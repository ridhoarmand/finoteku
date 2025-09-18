import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';

class AmountSection extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback onTapOutside;
  const AmountSection({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onTapOutside,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.tr(context, 'amount_title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          TextFormField(
            focusNode: focusNode,
            controller: controller,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: ref.tr(context, 'amount_hint'),
              hintStyle: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmitted(),
            onTapOutside: (_) => onTapOutside(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return ref.tr(context, 'amount_validation_empty');
              }
              final amount = double.tryParse(value!);
              if (amount == null || amount <= 0) {
                return ref.tr(context, 'amount_validation_invalid');
              }
              return null;
            },
          ),
        ],
      ),
    ),
  );
}
