import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import '../router/app_router.dart';
import '../providers/app_providers.dart';

final deepLinkUrlProvider = StateProvider<String?>((ref) => null);

class DeepLinkService {
  static const _channel = MethodChannel('com.urldefenders/sharing');
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final Ref _ref;

  DeepLinkService(this._ref);

  void init() {
    // 1. Listen for incoming App Links (VIEW intents) while running (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleIncomingUri(uri);
      },
      onError: (err) {
        debugPrint('AppLinks stream error: $err');
      },
    );

    // 2. Check initial deep link (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleIncomingUri(uri);
      }
    });

    // 3. Check for shared text from native ACTION_SEND (Share Sheet)
    _checkSharedText();
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  Future<void> _checkSharedText() async {
    try {
      final sharedText = await _channel.invokeMethod<String>('getSharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        _handleSharedText(sharedText);
      }
    } catch (e) {
      debugPrint('MethodChannel getSharedText error: $e');
    }
  }

  void _handleIncomingUri(Uri uri) {
    final urlString = uri.toString();
    _processIncomingUrl(urlString);
  }

  void _handleSharedText(String text) {
    final regExp = RegExp(
      r'https?://[^\s/$.?#].[^\s]*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(text);
    if (match != null) {
      final url = match.group(0);
      if (url != null) {
        _processIncomingUrl(url);
      }
    }
  }

  void _processIncomingUrl(String url) {
    final cleanUrl = url.trim();
    if (!_isValidUrl(cleanUrl)) return;

    final user = _ref.read(userProvider);
    if (user == null) {
      _ref.read(deepLinkUrlProvider.notifier).state = cleanUrl;
      return;
    }

    _ref.read(deepLinkUrlProvider.notifier).state = cleanUrl;
    _ref.read(tabIndexProvider.notifier).state = 1;
    appRouter.go('/dashboard');
  }

  bool _isValidUrl(String url) {
    final input = url.trim();
    if (input.isEmpty || input.length > 2048 || input.contains(' ')) {
      return false;
    }
    final candidate =
        input.startsWith('http://') || input.startsWith('https://')
        ? input
        : 'https://$input';
    final uri = Uri.tryParse(candidate);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
