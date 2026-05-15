import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_mode_provider.dart';

class CofiPointeApp extends ConsumerWidget {
  const CofiPointeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
