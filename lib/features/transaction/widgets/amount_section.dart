import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AmountSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback onTapOutside;
  const AmountSection({super.key, required this.controller, required this.focusNode, required this.onSubmitted, required this.onTapOutside});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Amount', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            TextFormField(
              focusNode: focusNode,
              controller: controller,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey),
                prefixText: 'Rp ',
                prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmitted(),
              onTapOutside: (_) => onTapOutside(),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Please enter an amount';
                final amount = double.tryParse(value!); if (amount == null || amount <= 0) return 'Please enter a valid amount';
                return null;
              },
            ),
          ]),
        ),
      );
}
