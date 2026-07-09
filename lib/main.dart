import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'providers/app_providers.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch and suppress the Flutter Web keyboard assertion error globally
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('ViewInsets cannot be negative')) {
        return;
      }
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (error.toString().contains('ViewInsets cannot be negative')) {
        return true; // Suppress assertion error
      }
      return false;
    };

    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  }, (error, stack) {
    if (error.toString().contains('ViewInsets cannot be negative')) {
      // Suppress keyboard resize assertion error
      return;
    }
    FlutterError.onError?.call(FlutterErrorDetails(exception: error, stack: stack));
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
