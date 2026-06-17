import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_locale.dart';

class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final locale = ref.watch(appLocaleProvider);

    return PopupMenuButton<String>(
      tooltip: strings.switchLanguage,
      onSelected: (value) {
        ref.read(appLocaleProvider.notifier).setLocale(Locale(value));
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'ar',
          child: Row(
            children: [
              Icon(
                locale.languageCode == 'ar'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(strings.arabic),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              Icon(
                locale.languageCode == 'en'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(strings.english),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.translate_rounded),
      ),
    );
  }
}
