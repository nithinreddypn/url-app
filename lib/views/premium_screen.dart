import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/plan_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../services/payment_service.dart';
import '../services/razorpay_web_payment.dart';
import '../services/alert_service.dart';
import '../services/error_handler.dart';

enum PremiumFlowStep {
  plans,
  checkout,
  processing,
  success,
  failed,
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing Glow Card for Premium Highlights
// ─────────────────────────────────────────────────────────────────────────────
class PulsingGlowCard extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double borderWidth;
  final Color borderColor;
  final double borderRadius;

  const PulsingGlowCard({
    super.key,
    required this.child,
    required this.glowColor,
    required this.borderWidth,
    required this.borderColor,
    required this.borderRadius,
  });

  @override
  State<PulsingGlowCard> createState() => _PulsingGlowCardState();
}

class _PulsingGlowCardState extends State<PulsingGlowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: widget.borderColor, width: widget.borderWidth),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.18),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius - widget.borderWidth),
            child: widget.child,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti Animation Controller & Painter
// ─────────────────────────────────────────────────────────────────────────────
class ConfettiParticle {
  double x, y;
  double vx, vy;
  Color color;
  double size;
  double rotation;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ConfettiWidget extends StatefulWidget {
  const ConfettiWidget({super.key});

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(_updateParticles);
    
    // Spawn particles on entry
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.orange, Colors.purple, Colors.pink];
    for (int i = 0; i < 80; i++) {
      _particles.add(ConfettiParticle(
        x: 100 + _random.nextDouble() * 200,
        y: -10,
        vx: -3 + _random.nextDouble() * 6,
        vy: 2 + _random.nextDouble() * 6,
        color: colors[_random.nextInt(colors.length)],
        size: 6 + _random.nextDouble() * 8,
        rotation: _random.nextDouble() * pi * 2,
      ));
    }
    _controller.forward();
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.1; // gravity
        p.rotation += 0.05;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 300),
      painter: ConfettiPainter(particles: _particles),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PremiumScreen Main View
// ─────────────────────────────────────────────────────────────────────────────
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => const Color(0xFF16A34A);
  Color get _red => context.danger;
  Color get _textPrimary => context.textPrimary;
  Color get _textSecondary => context.textSecondary;

  final PaymentService _paymentService = PaymentService();
  final TextEditingController _couponController = TextEditingController();

  PremiumFlowStep _currentStep = PremiumFlowStep.plans;
  PlanModel? _selectedPlan;
  String _selectedPaymentMethod = 'Razorpay';
  
  // Coupon state
  String? _activeCoupon;
  double _discountPercent = 0.0;
  String? _couponError;
  String? _couponSuccessMessage;
  bool _isValidatingCoupon = false;

  // Checkout states
  String? _paymentErrorMessage;
  bool _isProcessing = false;
  String _processingMessage = 'Processing Payment...';
  DateTime? _activationDate;

  @override
  void initState() {
    super.initState();
    _paymentService.initialize(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
      onExternalWallet: _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    _couponController.dispose();
    super.dispose();
  }

  // ──────────────────────────── Payment Gateway Event Handlers ────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_selectedPlan == null) return;
    
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Verifying payment securely on server...';
    });

    final notifier = ref.read(paymentProvider.notifier);
    
    // Server-to-server independent payment signature check & verification
    final success = await notifier.verifyAndUpgrade(
      planId: _selectedPlan!.planId,
      paymentId: response.paymentId ?? '',
      orderId: response.orderId ?? '',
      signature: response.signature ?? '',
      amount: _selectedPlan!.price * (1 - (_discountPercent / 100)),
    );

    if (success) {
      // Hard Rule 5: Refresh user and subscription state from the backend
      await ref.read(userProvider.notifier).refreshUser();
      await ref.refresh(subscriptionProvider.future);
      
      setState(() {
        _activationDate = DateTime.now();
        _isProcessing = false;
        _currentStep = PremiumFlowStep.success;
      });
    } else {
      setState(() {
        _isProcessing = false;
        _paymentErrorMessage = 'Payment verification signature check failed.';
        _currentStep = PremiumFlowStep.failed;
      });
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    setState(() {
      _isProcessing = false;
      _paymentErrorMessage = response.message ?? 'Payment was cancelled or card declined.';
      _currentStep = PremiumFlowStep.failed;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() {
      _isProcessing = false;
      _paymentErrorMessage = 'External wallet option is not supported.';
      _currentStep = PremiumFlowStep.failed;
    });
  }

  // ──────────────────────────── Action Logic Methods ────────────────────────────

  Future<void> _applyCouponCode() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
      _couponSuccessMessage = null;
    });

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final result = await repo.validateCoupon(code);
      
      setState(() {
        _discountPercent = (result['discount_percent'] as num).toDouble();
        _activeCoupon = code;
        _couponSuccessMessage = result['message'] ?? 'Coupon applied!';
        _isValidatingCoupon = false;
      });
    } catch (e) {
      setState(() {
        _couponError = 'Invalid or expired coupon code.';
        _discountPercent = 0.0;
        _activeCoupon = null;
        _isValidatingCoupon = false;
      });
    }
  }

  Future<void> _proceedToCheckoutOrder() async {
    if (_selectedPlan == null) return;
    
    final user = ref.read(userProvider);
    if (user == null) {
      AlertService.showError(context, 'Please login to upgrade subscription');
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Generating secure order key...';
    });

    try {
      final notifier = ref.read(paymentProvider.notifier);
      final order = await notifier.createOrder(
        _selectedPlan!.planId,
        couponCode: _activeCoupon,
      );

      final discountAmount = _selectedPlan!.price * (1 - (_discountPercent / 100));

      if (kIsWeb) {
        setState(() {
          _processingMessage = 'Please complete checkout in Razorpay web popup...';
        });
        RazorpayWebPayment.open(
          key: order.keyId,
          amount: discountAmount,
          name: 'URL Defender Premium',
          description: 'Premium Protection Subscription',
          email: user.email,
          contact: '9999999999',
          orderId: order.orderId,
          onSuccess: (paymentId, orderId, signature) async {
            setState(() {
              _processingMessage = 'Verifying signature on backend server...';
            });
            final success = await notifier.verifyAndUpgrade(
              planId: _selectedPlan!.planId,
              paymentId: paymentId,
              orderId: orderId,
              signature: signature,
              amount: discountAmount,
            );
            if (success) {
              await ref.read(userProvider.notifier).refreshUser();
              await ref.refresh(subscriptionProvider.future);
              setState(() {
                _activationDate = DateTime.now();
                _isProcessing = false;
                _currentStep = PremiumFlowStep.success;
              });
            } else {
              setState(() {
                _isProcessing = false;
                _paymentErrorMessage = 'Payment verification signature check failed.';
                _currentStep = PremiumFlowStep.failed;
              });
            }
          },
          onFailure: (errorMessage) {
            setState(() {
              _isProcessing = false;
              _paymentErrorMessage = errorMessage;
              _currentStep = PremiumFlowStep.failed;
            });
          },
        );
        return;
      }

      // Launch native SDK on mobile devices
      _paymentService.openCheckout(
        key: order.keyId,
        amount: discountAmount,
        name: 'URL Defender Premium',
        description: 'Premium Protection Subscription',
        email: user.email,
        contact: '9999999999',
        orderId: order.orderId,
      );
    } catch (e, stack) {
      final mapped = ErrorHandler.handle(e, stack);
      setState(() {
        _isProcessing = false;
        _paymentErrorMessage = mapped.message;
        _currentStep = PremiumFlowStep.failed;
      });
    }
  }

  Future<void> _cancelSubscriptionFlow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Subscription?', style: TextStyle(color: _textPrimary)),
        content: const Text('Are you sure you want to cancel your Premium benefits? You will lose unlimited scans instantly.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Plan')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: const Text('Confirm Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Processing cancellation request...';
      });

      try {
        final repo = ref.read(subscriptionRepositoryProvider);
        final success = await repo.cancelActiveSubscription();
        if (success) {
          await ref.read(userProvider.notifier).refreshUser();
          ref.invalidate(subscriptionProvider);
          ref.invalidate(scanLimitProvider);
          if (mounted) {
            AlertService.showSuccess(context, 'Subscription Cancelled', 'Your plan has been downgraded to Free.');
          }
        }
      } catch (e) {
        if (mounted) {
          AlertService.showError(context, e);
        }
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ──────────────────────────── Render Helper Layouts ────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final subscription = subscriptionAsync.valueOrNull;
    final isPremium = user?.isPremium ?? false;

    // Direct render block for already premium subscription management view
    if (isPremium && subscription != null && _currentStep == PremiumFlowStep.plans) {
      return _buildSubscriptionManagementView(subscription);
    }

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
            onPressed: _isProcessing ? null : () {
              if (_currentStep == PremiumFlowStep.plans) {
                context.pop();
              } else if (_currentStep == PremiumFlowStep.checkout) {
                setState(() => _currentStep = PremiumFlowStep.plans);
              } else {
                setState(() => _currentStep = PremiumFlowStep.plans);
              }
            },
          ),
          title: Text(
            _currentStep == PremiumFlowStep.checkout ? 'Secure Checkout' : 'Upgrade Plan',
            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentFlowStepView(),
            ),
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentFlowStepView() {
    switch (_currentStep) {
      case PremiumFlowStep.plans:
        return _buildPlansView();
      case PremiumFlowStep.checkout:
        return _buildCheckoutView();
      case PremiumFlowStep.success:
        return _buildSuccessView();
      case PremiumFlowStep.failed:
        return _buildFailedView();
      default:
        return _buildPlansView();
    }
  }

  // 1. Premium Plans Screen
  Widget _buildPlansView() {
    final plansAsync = ref.watch(planProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.workspace_premium_rounded, color: _primaryGreen, size: 40),
          ),
          const SizedBox(height: 14),
          Text(
            'URL Defender Premium',
            style: TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Deploy enterprise-grade safety tools to every device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 32),

          plansAsync.when(
            data: (plans) {
              final premiumPlan = plans.firstWhere(
                (p) => p.planId == 'team',
                orElse: () => PlanModel(planId: 'team', name: 'Premium', description: 'Enhanced protection', price: 99, currency: 'INR', durationMonths: 1, features: const []),
              );
              final enterprisePlan = plans.firstWhere(
                (p) => p.planId == 'enterprise',
                orElse: () => PlanModel(planId: 'enterprise', name: 'Enterprise', description: 'Enterprise protection', price: 499, currency: 'INR', durationMonths: 1, features: const []),
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildFreePlanCard()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildPremiumPlanCard(premiumPlan)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildEnterprisePlanCard(enterprisePlan)),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildFreePlanCard(),
                        const SizedBox(height: 20),
                        _buildPremiumPlanCard(premiumPlan),
                        const SizedBox(height: 20),
                        _buildEnterprisePlanCard(enterprisePlan),
                      ],
                    );
                  }
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: _primaryGreen)),
            error: (e, _) => Center(
              child: Text('Failed to load pricing plans: $e', style: TextStyle(color: _red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreePlanCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surfaceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Free Plan', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('₹0', style: TextStyle(color: _textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text('/month', style: TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          _buildCheckItem('Basic URL Scanning'),
          _buildCheckItem('Limited Daily Scans'),
          _buildCheckItem('Community Reports'),
          _buildCheckItem('Basic Security Metrics'),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: _surfaceColor.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Current Plan', style: TextStyle(color: _textSecondary.withOpacity(0.6), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPlanCard(PlanModel plan) {
    final innerCard = Container(
      color: _cardColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Premium Plan', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'RECOMMENDED',
                  style: TextStyle(color: _primaryGreen, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('₹99', style: TextStyle(color: _primaryGreen, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text('/month', style: TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          _buildCheckItem('Unlimited URL Scans'),
          _buildCheckItem('AI Threat Detection'),
          _buildCheckItem('Real-Time Protection'),
          _buildCheckItem('Advanced Threat Reports'),
          _buildCheckItem('Priority Email Support'),
          _buildCheckItem('Zero Advertisements'),
          _buildCheckItem('Early Access Features'),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => _showPlanDetailsDialog(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Upgrade Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return PulsingGlowCard(
      glowColor: _primaryGreen,
      borderWidth: 2.0,
      borderColor: _primaryGreen,
      borderRadius: 20,
      child: innerCard,
    );
  }

  Widget _buildEnterprisePlanCard(PlanModel plan) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surfaceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enterprise', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Custom', style: TextStyle(color: _textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text('/contract', style: TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          _buildCheckItem('Team Member Management'),
          _buildCheckItem('Developer API Access'),
          _buildCheckItem('Threat Intel Feed (STIX/TAXII)'),
          _buildCheckItem('Dedicated Account Rep'),
          _buildCheckItem('SAML Single Sign-On (SSO)'),
          _buildCheckItem('99.9% API SLA Uptime'),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Contact Sales', style: TextStyle(color: _textPrimary)),
                  content: Text('Please contact our sales team at sales@urldefender.com for custom volume licensing.', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _surfaceColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Contact Sales', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.check, color: _primaryGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Plan Details dialog sheet helper
  void _showPlanDetailsDialog(PlanModel plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: _surfaceColor),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Plan',
                        style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Monthly billing cycle', style: TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                  Text(
                    '₹99',
                    style: TextStyle(color: _primaryGreen, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'FEATURES INCLUDED',
                style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              ...[
                'Unlimited URL scans',
                'AI detection analysis',
                'Real-time link monitoring',
                'Priority email support',
                'Membership badges',
                'No advertisements',
              ].map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: _primaryGreen, size: 18),
                    const SizedBox(width: 10),
                    Text(f, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, color: _textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Text('Cancel anytime. Secure checkout.', style: TextStyle(color: _textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _surfaceColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedPlan = plan;
                          _currentStep = PremiumFlowStep.checkout;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Checkout Screen
  Widget _buildCheckoutView() {
    final subtotal = _selectedPlan?.price ?? 99.0;
    final discount = subtotal * (_discountPercent / 100.0);
    final total = (subtotal - discount).clamp(0.0, subtotal);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trust Indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: _primaryGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Secure Checkout — Secured with SSL/TLS encryption.',
                    style: TextStyle(color: _primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Order summary
          Text('SELECTED PLAN', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _surfaceColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium Plan Monthly', style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('₹99 billed monthly', style: TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
                Text('₹99.00', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Coupon Code field
          Text('COUPON CODE', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: InputDecoration(
                    hintText: 'Enter coupon (e.g. SECURE50)',
                    hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: _cardColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _surfaceColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _primaryGreen, width: 1.5),
                    ),
                  ),
                  style: TextStyle(color: _textPrimary, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isValidatingCoupon ? null : _applyCouponCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _surfaceColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isValidatingCoupon
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Apply', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_couponError != null) ...[
            const SizedBox(height: 6),
            Text(_couponError!, style: TextStyle(color: _red, fontSize: 11)),
          ],
          if (_couponSuccessMessage != null) ...[
            const SizedBox(height: 6),
            Text(_couponSuccessMessage!, style: TextStyle(color: _primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 24),

          // Payment Methods
          Text('PAYMENT METHOD', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          _buildPaymentMethodTile('Razorpay', 'Card, Netbanking, UPI, Wallets', Icons.credit_card_rounded),
          const SizedBox(height: 10),
          _buildPaymentMethodTile('Stripe', 'International Credit/Debit Cards', Icons.payment_rounded, disabled: true),
          const SizedBox(height: 10),
          _buildPaymentMethodTile('Google Play Billing', 'In-App billing subscription', Icons.play_arrow_rounded, disabled: true),
          const SizedBox(height: 24),

          // Invoice Details
          Divider(color: _surfaceColor),
          const SizedBox(height: 12),
          _buildInvoiceRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
          if (discount > 0)
            _buildInvoiceRow('Discount (${_discountPercent.toStringAsFixed(0)}%)', '-₹${discount.toStringAsFixed(2)}', isGreen: true),
          _buildInvoiceRow('Total Amount', '₹${total.toStringAsFixed(2)}', isBold: true),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _proceedToCheckoutOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Pay ₹${total.toStringAsFixed(2)} securely', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile(String name, String desc, IconData icon, {bool disabled = false}) {
    final isSelected = _selectedPaymentMethod == name;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _primaryGreen : _surfaceColor,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: disabled ? null : () => setState(() => _selectedPaymentMethod = name),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: disabled ? _textSecondary.withOpacity(0.3) : (isSelected ? _primaryGreen : _textSecondary), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: disabled ? _textSecondary.withOpacity(0.4) : _textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(desc, style: TextStyle(color: disabled ? _textSecondary.withOpacity(0.3) : _textSecondary, fontSize: 10)),
                  ],
                ),
              ),
              if (disabled)
                Text('UNAVAILABLE', style: TextStyle(color: _textSecondary.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold))
              else
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? _primaryGreen : _surfaceColor,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String value, {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? _textPrimary : _textSecondary, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              color: isGreen ? _primaryGreen : _textPrimary,
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Processing overlay
  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _surfaceColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primaryGreen),
              const SizedBox(height: 24),
              Text(
                _processingMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please do not press back or close the app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 5. Payment Success view
  Widget _buildSuccessView() {
    final today = DateTime.now();
    final renewal = today.add(const Duration(days: 30));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${months[today.month - 1]} ${today.day}, ${today.year}';
    final renewalStr = '${months[renewal.month - 1]} ${renewal.day}, ${renewal.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ConfettiWidget(),
          const SizedBox(height: 10),

          // Check icon
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _primaryGreen.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: _primaryGreen.withOpacity(0.3), width: 2),
                    ),
                    child: Icon(Icons.verified_rounded, color: _primaryGreen, size: 54),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Welcome to URL Defender Premium',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Premium has been activated successfully. Unlimited protection is now enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 32),

          // Summary details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _surfaceColor),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Membership', 'Premium Monthly'),
                _buildSummaryRow('Billing Cycle', 'Monthly'),
                _buildSummaryRow('Activated', dateStr),
                _buildSummaryRow('Next Renewal', renewalStr),
              ],
            ),
          ),
          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: () {
              setState(() => _currentStep = PremiumFlowStep.plans);
              context.go('/main');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start Using Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() => _currentStep = PremiumFlowStep.plans);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _surfaceColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('View Subscription', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 6. Payment Failed Screen
  Widget _buildFailedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: _red.withOpacity(0.3), width: 2),
              ),
              child: Icon(Icons.error_outline_rounded, color: _red, size: 54),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Payment Failed',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your payment could not be completed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_paymentErrorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _paymentErrorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: () {
              setState(() => _currentStep = PremiumFlowStep.checkout);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() => _currentStep = PremiumFlowStep.plans);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _surfaceColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Cancel Upgrade', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // 7. Subscription Management View
  Widget _buildSubscriptionManagementView(dynamic subscription) {
    final expiry = subscription.expiryDate;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = expiry != null ? '${months[expiry.month - 1]} ${expiry.day}, ${expiry.year}' : 'N/A';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Subscription Management',
          style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Plan Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primaryGreen.withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Premium protection active', style: TextStyle(color: _primaryGreen, fontSize: 12, fontWeight: FontWeight.w800)),
                          Icon(Icons.workspace_premium_rounded, color: _primaryGreen, size: 24),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Premium Plan', style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Unlimited scans & AI heuristics active.', style: TextStyle(color: _textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Subscription Details
                Text('DETAILS', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _surfaceColor),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Billing Status', subscription.status.toUpperCase()),
                      _buildSummaryRow('Billing Cycle', 'Monthly'),
                      _buildSummaryRow('Payment Provider', subscription.paymentProvider.toUpperCase()),
                      _buildSummaryRow('Next Renewal Date', dateStr),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                OutlinedButton(
                  onPressed: () async {
                    setState(() {
                      _isProcessing = true;
                      _processingMessage = 'Refreshed subscription details...';
                    });
                    await ref.refresh(subscriptionProvider.future);
                    await ref.read(userProvider.notifier).refreshUser();
                    setState(() {
                      _isProcessing = false;
                    });
                    if (mounted) {
                      AlertService.showSuccess(context, 'Refreshed', 'Subscription status synchronized.');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _surfaceColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Restore / Refresh Purchase', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: _cancelSubscriptionFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel Subscription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }
}
