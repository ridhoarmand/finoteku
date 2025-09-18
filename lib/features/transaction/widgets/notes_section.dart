import 'package:flutter/material.dart';

class NotesSection extends StatelessWidget {
  final TextEditingController controller;
  const NotesSection({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notes (Optional)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Add transaction details...'),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ]),
        ),
      );
}
