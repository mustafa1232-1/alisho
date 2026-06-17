import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_locale.dart';
import 'core/app_theme.dart';
import 'core/auth_controller.dart';
import 'core/router.dart';

class AlishoApp extends ConsumerWidget {
  const AlishoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    ref.watch(authControllerProvider);

    return MaterialApp.router(
      title: 'Alisho Library',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(locale),
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final strings = context.strings;
        return Directionality(
          textDirection: strings.direction,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
