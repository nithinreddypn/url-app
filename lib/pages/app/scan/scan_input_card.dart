import 'package:flutter/material.dart';
import '../../../models/url_lookup_result.dart';
import '../../../theme/app_theme.dart';
import 'scan_theme.dart';
import 'typewriter_hint.dart';

/// The URL input card — always renders unconditionally.
/// Contains: label row, input field, status messages.
class ScanInputCard extends StatefulWidget {
  final TextEditingController urlController;
  final bool isScanning;
  final bool hasResult;
  final UrlLookupResult? lookupResult;
  final bool showLookupProgress;
  final bool lookupFailed;
  final int? remainingScans;
  final ValueChanged<String> onUrlChanged;
  final VoidCallback onScan;
  final VoidCallback onClear;

  const ScanInputCard({
    super.key,
    required this.urlController,
    required this.isScanning,
    required this.hasResult,
    required this.lookupResult,
    required this.showLookupProgress,
    required this.lookupFailed,
    required this.remainingScans,
    required this.onUrlChanged,
    required this.onScan,
    required this.onClear,
  });

  @override
  State<ScanInputCard> createState() => _ScanInputCardState();
}

class _ScanInputCardState extends State<ScanInputCard> {
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasText = false;
  String _typewriterHint = '';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.urlController.addListener(_onTextChange);
    _hasText = widget.urlController.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.urlController.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _onTextChange() {
    final hasText = widget.urlController.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    // Clear validation when user starts typing
    if (_validationError != null && hasText) {
      setState(() => _validationError = null);
    }
  }

  String? _validate() {
    final text = widget.urlController.text.trim();
    if (text.isEmpty) return 'Please enter a URL to scan';
    if (text.length > 2048) return 'URL is too long (max 2048 characters)';
    if (text.contains(' ')) return 'URL cannot contain spaces';
    final candidate = text.startsWith('http://') || text.startsWith('https://')
        ? text
        : 'https://$text';
    final uri = Uri.tryParse(candidate);
    if (uri == null) return 'Invalid URL format';
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Only http:// and https:// URLs are supported';
    }
    if (uri.host.isEmpty) return 'URL must have a valid domain';
    if (!uri.host.contains('.')) return 'URL must have a top-level domain';
    return null;
  }

  void _handleScan() {
    final error = _validate();
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    setState(() => _validationError = null);
    widget.onScan();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cardBg = context.cardBg;
    final border = context.border;
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 640;

    // Determine if typewriter should be paused
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final typewriterPaused =
        _isFocused || _hasText || widget.isScanning || reduceMotion;

    // Border color
    Color borderColor = border;
    List<BoxShadow>? glowShadow;
    if (_validationError != null) {
      borderColor = ScanTokens.errorRed;
      glowShadow = [
        BoxShadow(
          color: ScanTokens.errorRedBg,
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ];
    } else if (_isFocused) {
      borderColor = ScanTokens.focusBlue;
      glowShadow = [
        BoxShadow(
          color: ScanTokens.focusBlueBg,
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ];
    }

    return Container(
      padding: EdgeInsets.all(isCompact ? 20 : 28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(ScanTokens.cardRadius),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── LABEL ROW ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'URL TO SCAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  color: textMuted,
                ),
              ),
              if (widget.remainingScans != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.remainingScans}',
                      style: ScanTokens.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      ' / 50',
                      style: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── INPUT GROUP ───
          // Invisible typewriter driver
          TypewriterHint(
            paused: typewriterPaused,
            onHintChanged: (hint) {
              if (mounted) setState(() => _typewriterHint = hint);
            },
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ScanTokens.innerRadius),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: glowShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ScanTokens.innerRadius),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    // Globe icon
                    SizedBox(
                      width: 44,
                      height: 48,
                      child: Center(
                        child: Icon(
                          Icons.language_rounded,
                          size: 20,
                          color: _isFocused
                              ? ScanTokens.focusBlue
                              : textMuted,
                        ),
                      ),
                    ),
                    // TextField
                    Expanded(
                      child: Semantics(
                        textField: true,
                        label: 'URL input',
                        child: TextField(
                          controller: widget.urlController,
                          focusNode: _focusNode,
                          enabled: !widget.isScanning,
                          onChanged: widget.onUrlChanged,
                          onSubmitted: (_) => _handleScan(),
                          style: TextStyle(
                            fontSize: 14,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: _hasText
                                ? null
                                : (_typewriterHint.isEmpty
                                    ? 'Enter URL...'
                                    : _typewriterHint),
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: textMuted.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            filled: false,
                          ),
                        ),
                      ),
                    ),
                    // Clear button
                    if (_hasText && !widget.isScanning)
                      SizedBox(
                        width: 36,
                        height: 48,
                        child: IconButton(
                          onPressed: widget.onClear,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: textMuted,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 18,
                        ),
                      ),
                    // Scan button
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          key: const ValueKey('scan_button'),
                          onPressed:
                              widget.isScanning ? null : _handleScan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            foregroundColor:
                                isDark ? Colors.black : Colors.white,
                            disabledBackgroundColor: isDark
                                ? Colors.white.withOpacity(0.3)
                                : const Color(0xFF0F172A).withOpacity(0.5),
                            disabledForegroundColor: isDark
                                ? Colors.black.withOpacity(0.5)
                                : Colors.white.withOpacity(0.7),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ScanTokens.inputRadius,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isScanning) ...[
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark
                                        ? Colors.black.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.isScanning
                                    ? 'Scanning'
                                    : 'Scan Now',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── VALIDATION ERROR ───
          if (_validationError != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: ScanTokens.errorRed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _validationError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ScanTokens.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ─── STATUS MESSAGE ───
          _buildStatusMessage(textMuted),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(Color textMuted) {
    // 1. Loading (checking DB)
    if (widget.showLookupProgress) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Checking previous scans…',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
        ],
      );
    }

    // 2. Error (lookup failed)
    if (widget.lookupFailed) {
      return Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: ScanTokens.errorRed,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Could not check previous scans. You can still start a new scan.',
                style: TextStyle(
                  fontSize: 12,
                  color: ScanTokens.errorRed.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Found — existing analysis
    if (widget.lookupResult != null && widget.lookupResult!.exists) {
      return Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: ScanTokens.emerald,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Analysis available — results shown below.',
              style: TextStyle(
                fontSize: 12,
                color: ScanTokens.emerald,
              ),
            ),
          ),
        ],
      );
    }

    // 4. Not found
    if (widget.lookupResult != null && !widget.lookupResult!.exists) {
      return Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'No analysis available yet. You can start a new scan.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
        ],
      );
    }

    // 5. Idle — privacy note
    return Row(
      children: [
        Icon(
          Icons.shield_outlined,
          size: 16,
          color: textMuted.withOpacity(0.6),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Your scans are private. We never share the URLs you submit.',
            style: TextStyle(
              fontSize: 12,
              color: textMuted.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }
}
