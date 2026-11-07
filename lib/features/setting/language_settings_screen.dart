import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/localization/app_localizations.dart';

class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends ConsumerState<LanguageSettingsScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(appLocaleProvider).contentLanguageCode;
  }

  @override
  Widget build(BuildContext context) {
  String t(String key) => ref.tr(context, key);
    return Scaffold(
  appBar: AppBar(title: Text(t('language_settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t('select_language'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildOption(context, t('english'), 'en'),
          _buildOption(context, t('indonesian'), 'id'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(appLocaleProvider.notifier).setLanguage(_selected);
                    Navigator.of(context).pop();
                  },
                  child: Text(t('save')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String label, String code) {
    final selected = _selected == code;
    return Card(
      child: ListTile(
        onTap: () => setState(() => _selected = code),
        title: Text(label),
        trailing: selected ? Icon(PhFill.checkCircle, color: Theme.of(context).colorScheme.primary) : null,
      ),
    );
  }
}
