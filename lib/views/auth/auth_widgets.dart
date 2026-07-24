import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/google_continue_button.dart';
import '../../services/google_sign_in_service.dart';

/// ────────────────────────────────────────────────────────
/// Design Token Helper — single source for dark/light colors
/// ────────────────────────────────────────────────────────

class _AuthTokens {
  final bool isDark;
  _AuthTokens(this.isDark);

  // Backgrounds
  Color get bgBase =>
      isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC);
  Color get bgSurface =>
      isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9);
  Color get bgCard =>
      isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);

  // Borders
  Color get border =>
      isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);

  // Text
  Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

  // Accents
  Color get accentGreen =>
      isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);
  Color get accentBlue =>
      isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  Color get danger =>
      isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  Color get warning =>
      isDark ? const Color(0xFFFACC15) : const Color(0xFFD97706);

  // Hover/surface
  Color get hoverSurface =>
      isDark ? const Color(0xFF1F2430) : const Color(0xFFF1F5F9);

  // Input fill (slightly darker than card for inset feel)
  Color get inputFill =>
      isDark ? const Color(0xFF111318) : const Color(0xFFF8FAFC);
}

/// ────────────────────────────────────────────────────────
/// Reusable Auth Components for URL Defender
/// ────────────────────────────────────────────────────────

/// 1. AuthScaffold: Premium cybersecurity background with network nodes,
/// grid texture, radial gradients, keyboard avoidance.
class AuthScaffold extends ConsumerWidget {
  final Widget child;
  final Widget? topSection;

  const AuthScaffold({super.key, required this.child, this.topSection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    return Scaffold(
      backgroundColor: t.bgBase,
      body: Stack(
        children: [
          // Custom Painter Background
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberBackgroundPainter(isDark: isDark),
            ),
          ),

          // Content
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (topSection != null) ...[
                          topSection!,
                          const SizedBox(height: 28),
                        ],
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. SectionTitle: Logo, heading, subtitle, trust indicator.
class SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trustIndicatorText;

  const SectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.trustIndicatorText = '🛡 Privacy First',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    return Column(
      children: [
        // Hero shield logo
        Hero(
          tag: 'auth_logo_hero',
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accentGreen.withValues(alpha: 0.1),
              border: Border.all(
                color: t.accentGreen.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: t.accentGreen.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(48),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Title
        Text(
          title,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          subtitle,
          style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Trust Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: t.accentGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.accentGreen.withValues(alpha: 0.2)),
          ),
          child: Text(
            trustIndicatorText,
            style: TextStyle(
              color: t.accentGreen,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// 3. AuthCard: Animated panel with soft shadow & rounded corners.
class AuthCard extends StatefulWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  State<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<AuthCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, childWidget) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0.0, _slideAnimation.value),
            child: childWidget,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: t.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// 4. CustomTextField: Floating Label, leading icon, focus/success/error states.
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.focusNode,
    this.onChanged,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _isValid = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    _validate();
  }

  void _validate() {
    if (widget.validator != null) {
      final error = widget.validator!(widget.controller.text);
      setState(() {
        _hasError = error != null;
        _isValid = error == null && widget.controller.text.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    Color getBorderColor() {
      if (_hasError) return t.danger;
      if (_isValid) return t.accentGreen;
      if (_isFocused) return t.accentGreen;
      return t.border;
    }

    Color getIconLabelColor() {
      if (_hasError) return t.danger;
      if (_isValid) return t.accentGreen;
      if (_isFocused) return t.accentGreen;
      return t.textSecondary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (_) => _validate(),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            onChanged: (val) {
              _validate();
              widget.onChanged?.call(val);
            },
            style: TextStyle(color: t.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: widget.labelText,
              labelStyle: TextStyle(color: getIconLabelColor(), fontSize: 14),
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: t.textSecondary.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                widget.prefixIcon,
                color: getIconLabelColor(),
                size: 20,
              ),
              suffixIcon: _isValid
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: t.accentGreen,
                      size: 20,
                    )
                  : null,
              filled: true,
              fillColor: t.inputFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor()),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor()),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.danger, width: 1.5),
              ),
              errorStyle: TextStyle(
                color: t.danger,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 5. PasswordField: Visibility toggle, floating label, validation.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.validator,
    this.focusNode,
    this.onChanged,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _isValid = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    _validate();
  }

  void _validate() {
    if (widget.validator != null) {
      final error = widget.validator!(widget.controller.text);
      setState(() {
        _hasError = error != null;
        _isValid = error == null && widget.controller.text.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    Color getBorderColor() {
      if (_hasError) return t.danger;
      if (_isValid) return t.accentGreen;
      if (_isFocused) return t.accentGreen;
      return t.border;
    }

    Color getIconLabelColor() {
      if (_hasError) return t.danger;
      if (_isValid) return t.accentGreen;
      if (_isFocused) return t.accentGreen;
      return t.textSecondary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (_) => _validate(),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: _obscure,
            validator: widget.validator,
            onChanged: (val) {
              _validate();
              widget.onChanged?.call(val);
            },
            style: TextStyle(color: t.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: widget.labelText,
              labelStyle: TextStyle(color: getIconLabelColor(), fontSize: 14),
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: t.textSecondary.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: getIconLabelColor(),
                size: 20,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        key: ValueKey<bool>(_obscure),
                        color: t.textSecondary,
                        size: 20,
                      ),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                  ),
                  if (_isValid) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: t.accentGreen,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
              filled: true,
              fillColor: t.inputFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor()),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor()),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.danger, width: 1.5),
              ),
              errorStyle: TextStyle(
                color: t.danger,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 6. PrimaryButton: Full-width green gradient button with loading, disabled states.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);
    final bool isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isEnabled
              ? LinearGradient(
                  colors: [
                    t.accentGreen,
                    t.accentGreen.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isEnabled ? null : t.border,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: t.accentGreen.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: t.textSecondary.withValues(alpha: 0.5),
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: EdgeInsets.zero,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 7. GoogleButton: "Continue with Google" button.
class GoogleButton extends StatelessWidget {
  final bool isLoading;
  final Future<void> Function(String idToken) onGoogleIdToken;
  final void Function(Object error, StackTrace stackTrace) onGoogleError;

  const GoogleButton({
    super.key,
    required this.isLoading,
    required this.onGoogleIdToken,
    required this.onGoogleError,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    final btnBg = isDark ? t.hoverSurface : Colors.white;
    final btnBorder = t.border;
    final textColor = t.textPrimary;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: kIsWeb
          ? Center(
              child: GoogleContinueButton(
                isLoading: isLoading,
                onIdToken: onGoogleIdToken,
                onError: onGoogleError,
              ),
            )
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isLoading
                    ? null
                    : () async {
                        try {
                          final idToken = await GoogleSignInService.instance
                              .signInOnNativePlatform();
                          await onGoogleIdToken(idToken);
                        } catch (e, s) {
                          onGoogleError(e, s);
                        }
                      },
                child: _googleContainer(btnBg, btnBorder, textColor, isDark),
              ),
            ),
    );
  }

  Widget _googleContainer(
    Color bg,
    Color border,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(size: const Size(20, 20), painter: _GoogleLogoPainter()),
          const SizedBox(width: 12),
          Text(
            'Continue with Google',
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 8. PasswordStrengthIndicator: 4-segment bar with labels.
class PasswordStrengthIndicator extends StatelessWidget {
  final int strength; // 0 to 4
  final String label;

  const PasswordStrengthIndicator({
    super.key,
    required this.strength,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    Color color;
    switch (strength) {
      case 1:
        color = t.danger;
        break;
      case 2:
        color = t.warning;
        break;
      case 3:
        color = t.accentGreen;
        break;
      case 4:
        color = t.accentGreen;
        break;
      default:
        color = t.danger;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password strength:',
              style: TextStyle(color: t.textSecondary, fontSize: 12),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            final filled = index < strength;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 3 ? 6.0 : 0.0),
                decoration: BoxDecoration(
                  color: filled ? color : t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// 9. AuthFooter: Cross links for auth flows.
class AuthFooter extends StatelessWidget {
  final String text;
  final String actionText;
  final VoidCallback onTap;

  const AuthFooter({
    super.key,
    required this.text,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: TextStyle(color: t.textSecondary, fontSize: 14)),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionText,
            style: TextStyle(
              color: t.accentGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// 10. ValidationMessage: Error card for auth errors.
class ValidationMessage extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  final bool isRetrying;
  final String actionLabel;

  const ValidationMessage({
    super.key,
    required this.text,
    this.onRetry,
    this.isRetrying = false,
    this.actionLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _AuthTokens(isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: t.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: t.danger,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            isRetrying
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.danger,
                    ),
                  )
                : TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        color: t.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────
/// Background and Icon Painters
/// ────────────────────────────────────────────────────────

class _CyberBackgroundPainter extends CustomPainter {
  final bool isDark;

  _CyberBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final accentGreen = isDark
        ? const Color(0xFF22C55E)
        : const Color(0xFF16A34A);

    // Top-Right Radial Glow
    final rectTR = Rect.fromCircle(
      center: Offset(size.width * 0.9, size.height * 0.15),
      radius: 260,
    );
    paint.shader = RadialGradient(
      colors: [
        accentGreen.withValues(alpha: isDark ? 0.09 : 0.05),
        Colors.transparent,
      ],
    ).createShader(rectTR);
    canvas.drawCircle(rectTR.center, 260, paint);

    // Bottom-Left Radial Glow
    final rectBL = Rect.fromCircle(
      center: Offset(size.width * 0.1, size.height * 0.85),
      radius: 280,
    );
    paint.shader = RadialGradient(
      colors: [
        accentGreen.withValues(alpha: isDark ? 0.06 : 0.03),
        Colors.transparent,
      ],
    ).createShader(rectBL);
    canvas.drawCircle(rectBL.center, 280, paint);

    // Grid
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.012)
        : Colors.black.withValues(alpha: 0.02);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;
    const double step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Network Node connection points
    final nodePaint = Paint()
      ..color = accentGreen.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = accentGreen.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    final List<Offset> points = [
      Offset(size.width * 0.15, size.height * 0.22),
      Offset(size.width * 0.28, size.height * 0.15),
      Offset(size.width * 0.82, size.height * 0.65),
      Offset(size.width * 0.74, size.height * 0.78),
      Offset(size.width * 0.88, size.height * 0.82),
    ];

    canvas.drawLine(points[0], points[1], linePaint);
    canvas.drawLine(points[2], points[3], linePaint);
    canvas.drawLine(points[3], points[4], linePaint);

    for (final pt in points) {
      canvas.drawCircle(pt, 3.5, nodePaint);
      canvas.drawCircle(
        pt,
        7,
        nodePaint..color = accentGreen.withValues(alpha: 0.03),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    
    final double strokeWidth = size.width * 0.28;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeWidth / 2);
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    const double d = 3.141592653589793 / 180;

    // 1. Red (Top Segment)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -145 * d, 103 * d, false, paint);

    // 2. Yellow (Left Segment)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -250 * d, 107 * d, false, paint);

    // 3. Green (Bottom Segment)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 35 * d, 110 * d, false, paint);

    // 4. Blue (Right Segment & Horizontal Bar)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -42 * d, 78 * d, false, paint);

    // Draw the horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    
    final double barHeight = strokeWidth * 0.95;
    final double barLeft = cx - r * 0.05;
    final double barWidth = r + strokeWidth / 2 - (barLeft - cx);
    
    canvas.drawRect(
      Rect.fromLTWH(barLeft, cy - barHeight / 2, barWidth, barHeight),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
