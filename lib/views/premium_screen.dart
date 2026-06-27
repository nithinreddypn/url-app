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

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.isDark ? Color(0xFFF59E0B) : Color(0xFFD97706);
  Color get _red => context.isDark ? Color(0xFFEF4444) : Color(0xFFDC2626);

  Color get _textPrimary => context.textPrimary;

  final PaymentService _paymentService = PaymentService();
  PlanModel? _selectedPlan;
  String _selectedBilling = 'Yearly'; // Default choice

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
    super.dispose();
  }

  // ──────────────────────────── Razorpay Event Handlers ────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_selectedPlan == null) return;

    final notifier = ref.read(paymentProvider.notifier);
    notifier.setLoading();

    // Call the Edge Function backend to verify signature and activate premium
    final success = await notifier.verifyAndUpgrade(
      planId: _selectedPlan!.planId,
      paymentId: response.paymentId ?? '',
      orderId: response.orderId ?? '',
      signature: response.signature ?? '',
      amount: _selectedPlan!.price,
    );

    if (success) {
      if (!mounted) return;
      AlertService.showSuccess(
        context,
        'Subscription Activated',
        'Subscription activated successfully.',
      );
      _showSuccessDialog();
    } else {
      if (!mounted) return;
      AlertService.showError(
        context,
        'Verification failed. Please contact support if amount was debited.',
        customTitle: 'Subscription Verification Failed',
      );
      _showErrorDialog('Verification failed. Please contact support if amount was debited.');
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    ref.read(paymentProvider.notifier).setFailure(response.message ?? 'Payment failed or cancelled.');
    _showErrorDialog(response.message ?? 'Payment was cancelled or failed.');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ref.read(paymentProvider.notifier).setFailure('External wallets are not supported directly in test mode.');
  }

  // ──────────────────────────── Trigger Checkout ────────────────────────────

  Future<void> _startCheckout(PlanModel plan) async {
    final user = ref.read(userProvider);
    if (user == null) {
      _showSnackBar('Please log in to upgrade your subscription', isError: true);
      return;
    }

    setState(() {
      _selectedPlan = plan;
    });

    ref.read(paymentProvider.notifier).setLoading();

    try {
      if (kIsWeb) {
        RazorpayWebPayment.open(
          key: 'rzp_test_LqpN92VpLqm1zP', // Razorpay test API key
          amount: plan.price,
          name: 'URL Defender Plus',
          description: '${plan.name} Protection Subscription',
          email: user.email,
          contact: '9999999999', // Default contact fallback
          onSuccess: (paymentId, orderId, signature) async {
            final success = await ref.read(paymentProvider.notifier).verifyAndUpgrade(
              planId: plan.planId,
              paymentId: paymentId,
              orderId: orderId,
              signature: signature,
              amount: plan.price,
            );
            if (success) {
              _showSuccessDialog();
            } else {
              _showErrorDialog('Verification failed. Please contact support if amount was debited.');
            }
          },
          onFailure: (errorMessage) {
            ref.read(paymentProvider.notifier).setFailure(errorMessage);
            _showErrorDialog(errorMessage);
          },
        );
        return;
      }

      // Launch official Razorpay SDK on mobile
      _paymentService.openCheckout(
        key: 'rzp_test_LqpN92VpLqm1zP', // Razorpay test API key
        amount: plan.price,
        name: 'URL Defender Plus',
        description: '${plan.name} Protection Subscription',
        email: user.email,
        contact: '9999999999', // Default contact fallback
      );
    } catch (e) {
      ref.read(paymentProvider.notifier).setFailure(e.toString());
      _showErrorDialog('Failed to launch payment checkout: ${e.toString()}');
    }
  }

  // ──────────────────────────── Dialogs & SnackBar ────────────────────────────

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _primaryGreen, width: 1.5),
        ),
        title: Column(
          children: [
            Icon(Icons.verified_rounded, color: _primaryGreen, size: 50),
            SizedBox(height: 16),
            Text(
              'Upgrade Successful!',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Congratulations! You have successfully upgraded to URL Defender Plus. Unlimited URL Scanning is now active.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                context.go('/main'); // Go back to Home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Let\'s Go',
                style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _red, width: 1.5),
        ),
        title: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: _red, size: 50),
            SizedBox(height: 16),
            Text(
              'Payment Failed',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Color(0xFF475569)),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w700),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AlertService.showAlert(
        context,
        type: AlertType.error,
        title: 'Action Failed',
        description: message,
      );
    } else {
      AlertService.showAlert(
        context,
        type: AlertType.success,
        title: 'Success',
        description: message,
      );
    }
  }

  // ──────────────────────────── Render UI ────────────────────────────

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(planProvider);
    final paymentState = ref.watch(paymentProvider);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: paymentState.status == PaymentStatus.loading
          ? _buildLoadingOverlay()
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeroSection(),
                  SizedBox(height: 32),
                  _buildToggleBilling(),
                  SizedBox(height: 28),
                  plansAsync.when(
                    data: (plans) {
                      // Filter out the Free plan
                      final activePlans = plans
                          .where((p) => p.name.toLowerCase() != 'free')
                          .toList();

                      // Locate currently active selectedBilling plan
                      final displayedPlan = activePlans.firstWhere(
                        (p) => p.name.toLowerCase() == _selectedBilling.toLowerCase(),
                        orElse: () => activePlans.first,
                      );

                      return Column(
                        children: [
                          _buildPlanCard(displayedPlan),
                          SizedBox(height: 32),
                          _buildBenefitsList(displayedPlan.features),
                          SizedBox(height: 36),
                          _buildSubscribeButton(displayedPlan),
                        ],
                      );
                    },
                    loading: () => Center(
                      child: CircularProgressIndicator(color: _primaryGreen),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Failed to load pricing plans: $e',
                        style: TextStyle(color: _red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: _bgColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryGreen),
            SizedBox(height: 20),
            Text(
              'Verifying payment signature securely...',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Please do not close the application.',
              style: TextStyle(color: Color(0xFF48484A), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final isYearly = _selectedBilling == 'Yearly';
    final tierColor = isYearly ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0);
    final tierBgColor = isYearly ? const Color(0xFFFFD700).withValues(alpha: 0.12) : const Color(0xFFC0C0C0).withValues(alpha: 0.12);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tierBgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tierColor.withValues(alpha: 0.2),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              Icons.workspace_premium_rounded,
              key: ValueKey(isYearly),
              color: tierColor,
              size: 48,
            ),
          ),
        ),
        SizedBox(height: 18),
        Text(
          'URL Defender Plus',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Unlimited protection for every link you open.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleBilling() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Monthly'),
          _buildToggleButton('Yearly'),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String type) {
    final isSelected = _selectedBilling == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBilling = type;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          type == 'Yearly' ? 'Yearly (Best Value)' : 'Monthly',
          style: TextStyle(
            color: isSelected ? Colors.white : Color(0xFF8E8E93),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(PlanModel plan) {
    final isYearly = plan.name.toLowerCase() == 'yearly';
    final priceLabel = isYearly ? '₹999 / year' : '₹99 / month';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isYearly ? _amber : _surfaceColor,
          width: isYearly ? 2.0 : 1.0,
        ),
        boxShadow: isYearly
            ? [
                BoxShadow(
                  color: _amber.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          if (isYearly) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'BEST VALUE — SAVE 15%',
                style: TextStyle(
                  color: _amber,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
            SizedBox(height: 12),
          ],
          Text(
            plan.name,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            priceLabel,
            style: TextStyle(
              color: _primaryGreen,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            plan.description ?? 'Unlimited security metrics',
            style: TextStyle(
              color: Color(0xFF48484A),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsList(List<String> features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT\'S INCLUDED',
          style: TextStyle(
            color: Color(0xFF48484A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 16),
        ...features.map((feature) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.check, color: _primaryGreen, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSubscribeButton(PlanModel plan) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryGreen, Color(0xFF3ED65C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _startCheckout(plan),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Subscribe Now',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
