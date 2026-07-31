import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Catches build-time exceptions inside [child] and shows a visible
/// error+retry UI instead of a blank screen.
class ScanPageErrorBoundary extends StatefulWidget {
  final Widget child;
  const ScanPageErrorBoundary({super.key, required this.child});

  @override
  State<ScanPageErrorBoundary> createState() => _ScanPageErrorBoundaryState();
}

class _ScanPageErrorBoundaryState extends State<ScanPageErrorBoundary> {
  Object? _error;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _ErrorFallbackView(
        error: _error,
        onRetry: () => setState(() {
          _hasError = false;
          _error = null;
        }),
      );
    }
    return _ErrorCatcher(
      onError: (error) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _error = error;
              });
            }
          });
        }
      },
      child: widget.child,
    );
  }
}

class _ErrorCatcher extends StatefulWidget {
  final Widget child;
  final void Function(Object error) onError;
  const _ErrorCatcher({required this.child, required this.onError});

  @override
  State<_ErrorCatcher> createState() => _ErrorCatcherState();
}

class _ErrorCatcherState extends State<_ErrorCatcher> {
  FlutterExceptionHandler? _previousHandler;

  @override
  void initState() {
    super.initState();
    _previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      widget.onError(details.exception);
      _previousHandler?.call(details);
    };
  }

  @override
  void dispose() {
    if (FlutterError.onError != _previousHandler) {
      FlutterError.onError = _previousHandler;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ErrorFallbackView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _ErrorFallbackView({this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The scan page encountered an error. Tap retry to reload.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
