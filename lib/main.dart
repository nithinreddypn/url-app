import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'providers/app_providers.dart';
import 'services/error_handler.dart';
import 'services/deep_link_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch and suppress the Flutter Web keyboard assertion error globally
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains(
          'ViewInsets cannot be negative',
        )) {
          return;
        }
        if (kDebugMode) FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (error.toString().contains('ViewInsets cannot be negative')) {
          return true; // Suppress assertion error
        }
        ErrorHandler.handle(error, stack);
        return true;
      };

      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      if (error.toString().contains('ViewInsets cannot be negative')) {
        // Suppress keyboard resize assertion error
        return;
      }
      ErrorHandler.handle(error, stack);
    },
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deepLinkServiceProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);

    final lightTheme = AppTheme.lightTheme.copyWith(
      primaryColor: accentColor,
      colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
        primary: accentColor,
      ),
    );

    final darkTheme = AppTheme.darkTheme.copyWith(
      primaryColor: accentColor,
      colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
        primary: accentColor,
      ),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
