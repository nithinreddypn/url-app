// LINT-STYLE REMINDER:
// Never expose third-party provider names (VirusTotal, Google Safe Browsing, OpenPhish, URLHaus, PhishTank, WHOIS, etc.) anywhere in this UI.
// Always use the single branded phrase "URL Defender Threat Intelligence" for anything sourced from the verification pipeline.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../../services/community_threat_service.dart';
import '../../services/url_scan_service.dart';
import '../../providers/app_providers.dart';
import '../../models/url_scan_model.dart';
import 'my_report_status_screen.dart';
import 'verified_intelligence_view.dart';

class ReportFlowWizard extends ConsumerStatefulWidget {
  final String? initialUrl;
  const ReportFlowWizard({super.key, this.initialUrl});

  @override
  ConsumerState<ReportFlowWizard> createState() => _ReportFlowWizardState();
}

class _ReportFlowWizardState extends ConsumerState<ReportFlowWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0 to 6 representing Step 1 to 7

  // Form State variables
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'phishing';
  XFile? _screenshotFile;
  String? _screenshotBase64;
  bool _isSubmitting = false;

  // Analysis / lookup states
  bool _checkingDb = false;
  Map<String, dynamic>? _lookupResult;
  bool _analyzingUrl = false;
  UrlScanModel? _initialScanResult;

  // Checklist animation states for Step 3
  bool _checkDbDone = false;
  bool _analysisDone = false;
  bool _threatIntelDone = false;
  bool _riskCalcDone = false;

  // Canonical threat categories mapping
  final List<Map<String, String>> _categories = [
    {'value': 'phishing', 'label': 'Phishing'},
    {'value': 'malware', 'label': 'Malware'},
    {'value': 'fake_banking', 'label': 'Fake Banking'},
    {'value': 'investment_scam', 'label': 'Investment Scam'},
    {'value': 'crypto_scam', 'label': 'Crypto Scam'},
    {'value': 'fake_shopping', 'label': 'Fake Shopping'},
    {'value': 'identity_theft', 'label': 'Identity Theft'},
    {'value': 'spam', 'label': 'Spam'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _navigateToStep(int stepIndex) {
    setState(() {
      _currentStep = stepIndex;
    });
    _pageController.animateToPage(
      stepIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // --- Step 2 Lookup Action ---
  Future<void> _checkCommunityIntelligence() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _checkingDb = true;
    });

    // Move to Step 2 page
    _navigateToStep(1);

    try {
      final threatService = ref.read(communityThreatServiceProvider);
      final result = await threatService.checkStatus(url);
      
      setState(() {
        _lookupResult = result;
        _checkingDb = false;
      });

      if (result['status'] == 'clean') {
        // Case C: Auto-proceeds to Step 3 after 1.5 seconds
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted && _currentStep == 1) {
          _startInitialSecurityAnalysis();
        }
      }
    } catch (_) {
      setState(() {
        _checkingDb = false;
        _lookupResult = {'status': 'clean', 'data': null};
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted && _currentStep == 1) {
        _startInitialSecurityAnalysis();
      }
    }
  }

  // --- Step 3 Scan Action ---
  Future<void> _startInitialSecurityAnalysis() async {
    _navigateToStep(2);
    setState(() {
      _analyzingUrl = true;
      _checkDbDone = false;
      _analysisDone = false;
      _threatIntelDone = false;
      _riskCalcDone = false;
    });

    // Stagger checklist animations
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _checkDbDone = true);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _analysisDone = true);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _threatIntelDone = true);
    });

    try {
      final scanService = UrlScanService();
      final user = ref.read(userProvider);
      final scanResult = await scanService.scanUrlWithVirusTotal(
        scannedUrl: _urlController.text.trim(),
        userId: user?.userId ?? 'anonymous',
      );

      // Finish last checkmark
      setState(() {
        _riskCalcDone = true;
        _initialScanResult = scanResult;
        _analyzingUrl = false;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _navigateToStep(3); // Go to Step 4
      }
    } catch (e) {
      setState(() {
        _analyzingUrl = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initial analysis failed: $e'), backgroundColor: Colors.red),
        );
        _navigateToStep(0); // Return to entry
      }
    }
  }

  // --- Image Picker for Step 5 ---
  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        final name = image.name.toLowerCase();
        if (!name.endsWith('.png') && !name.endsWith('.jpg') && !name.endsWith('.jpeg') && !name.endsWith('.webp')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid format. Please pick a PNG, JPG, or WEBP image.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        final bytes = await image.readAsBytes();
        setState(() {
          _screenshotFile = image;
          _screenshotBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick screenshot: $e')),
        );
      }
    }
  }

  // --- Final Submit Action for Step 6 ---
  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final threatService = ref.read(communityThreatServiceProvider);
      await threatService.submitReport(
        url: _urlController.text.trim(),
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        screenshotBase64: _screenshotBase64,
      );

      // Successfully submitted
      setState(() {
        _isSubmitting = false;
      });
      _navigateToStep(6); // Step 7
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = context.bg;
    final cardBg = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final activeGreen = const Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          'Security Contributor Portal',
          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () {
            if (_currentStep > 0 && _currentStep < 6) {
              _navigateToStep(_currentStep - 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar Step Indicator
            if (_currentStep < 6)
              Container(
                height: 4,
                width: double.infinity,
                color: context.border,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_currentStep + 1) / 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Entry(context),
                  _buildStep2IntelligentCheck(context),
                  _buildStep3AnalysisProgress(context),
                  _buildStep4InitialResult(context),
                  _buildStep5DetailsForm(context),
                  _buildStep6Review(context),
                  _buildStep7Success(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 1 ====================
  Widget _buildStep1Entry(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final activeGreen = const Color(0xFF16A34A);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Suspicious Website',
            style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Flag malicious links to protect the broader community. Reports are investigated automatically and reviewed by system moderators.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Website Link (URL)',
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/login',
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.link, size: 20),
                    filled: true,
                    fillColor: context.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: activeGreen, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste the complete website URL you want to report.',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _urlController.text.trim().isNotEmpty
                  ? _checkCommunityIntelligence
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: activeGreen.withOpacity(0.3),
                disabledForegroundColor: Colors.white.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 2 ====================
  Widget _buildStep2IntelligentCheck(BuildContext context) {
    if (_checkingDb || _lookupResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF16A34A)),
            const SizedBox(height: 18),
            Text(
              'Checking Community Intelligence…',
              style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final status = _lookupResult!['status'];
    final data = _lookupResult!['data'];

    if (status == 'verified') {
      // Case B: URL already verified
      final verdict = data['verdict'] ?? 'dangerous';
      final isDangerous = verdict == 'dangerous' || verdict == 'malicious';
      final badgeColor = isDangerous ? Colors.red : Colors.green;
      final badgeText = isDangerous ? 'Verified Dangerous' : 'Verified Safe';
      final recText = isDangerous ? 'Avoid opening this website.' : 'This website has been verified as safe to visit.';

      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.border),
              ),
              child: Column(
                children: [
                  Icon(
                    isDangerous ? Icons.gpp_bad_outlined : Icons.verified_user_outlined,
                    color: badgeColor,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Threat Intelligence Available',
                    style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    recText,
                    style: TextStyle(color: context.textPrimary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to VerifiedIntelligenceView
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VerifiedIntelligenceView(urlData: data),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToStep(4), // Go to details form
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Report Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      );
    } else if (status == 'pending') {
      // Case A: URL already exists, under investigation
      final reportsCount = data['reporter_count'] ?? 1;

      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.border),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.security_update_warning_outlined,
                    color: Colors.amber,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Website Already Known',
                    style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Verification in Progress',
                      style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'This website has already been reported. Active Reports: $reportsCount. If you have additional evidence, please continue.',
                    style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to timeline page
                      // We will route it to MyReportStatusScreen using a stub/lookup id if we don't have direct id
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyReportStatusScreen(url: _urlController.text.trim()),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToStep(4), // Go to details form
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue Report', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      );
    } else {
      // Case C: URL not found
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.border),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.explore_outlined,
                    color: Colors.blue,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'New Website Detected',
                    style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This website has not previously been reported. We will perform an initial security check before submitting your report.',
                    style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ==================== STEP 3 ====================
  Widget _buildStep3AnalysisProgress(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF16A34A)),
                  const SizedBox(height: 24),
                  Text(
                    'Analyzing Website…',
                    style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _buildChecklistItem('Checking Community Database', _checkDbDone),
            _buildChecklistItem('Performing Security Analysis', _analysisDone),
            _buildChecklistItem('Collecting Threat Intelligence', _threatIntelDone),
            _buildChecklistItem('Calculating Initial Risk', _riskCalcDone, isPending: !_riskCalcDone),
            const SizedBox(height: 48),
            Center(
              child: Text(
                'Powered by URL Defender Threat Intelligence',
                style: TextStyle(color: context.textSecondary.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isDone, {bool isPending = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          isDone
              ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20)
              : (isPending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                    )
                  : const Icon(Icons.circle_outlined, color: Colors.grey, size: 20)),
          const SizedBox(width: 14),
          Text(
            title,
            style: TextStyle(
              color: isDone ? context.textPrimary : context.textSecondary,
              fontSize: 13,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 4 ====================
  Widget _buildStep4InitialResult(BuildContext context) {
    if (_initialScanResult == null) return const SizedBox();

    final verdict = _initialScanResult!.scanResult ?? 'safe';
    final riskScore = _initialScanResult!.riskScore ?? 0;
    final isDangerous = verdict.toLowerCase() == 'dangerous' || verdict.toLowerCase() == 'malicious';
    final isSuspicious = verdict.toLowerCase() == 'suspicious';
    
    Color badgeColor = Colors.green;
    String badgeText = 'Safe';
    String descText = 'Our automated systems checked this URL and did not flag immediate indicators. You can still continue to file a report if you know this is a scam.';
    
    if (isDangerous) {
      badgeColor = Colors.red;
      badgeText = 'Dangerous';
      descText = 'URL Defender Threat Intelligence has identified high-risk indicators on this domain. We recommend you do not browse to this website.';
    } else if (isSuspicious) {
      badgeColor = Colors.amber;
      badgeText = 'Suspicious';
      descText = 'This website matches patterns commonly associated with malicious networks. Please submit details to help us investigate.';
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.border),
            ),
            child: Column(
              children: [
                Icon(
                  isDangerous ? Icons.report_problem : (isSuspicious ? Icons.warning_amber : Icons.check_circle_outline),
                  color: badgeColor,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Initial Analysis Complete',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Risk score: $riskScore%',
                        style: TextStyle(color: context.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  descText,
                  style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.45),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel / Discard', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _navigateToStep(4), // Go to form Details
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continue Report', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ==================== STEP 5 ====================
  Widget _buildStep5DetailsForm(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final activeGreen = const Color(0xFF16A34A);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Details',
            style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Provide category and descriptive context to help moderators analyze this website.',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Category Dropdown
          Text(
            'Threat Category',
            style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            dropdownColor: context.cardBg,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: context.cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: activeGreen),
              ),
            ),
            items: _categories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat['value'],
                child: Text(cat['label']!),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedCategory = val;
                });
              }
            },
          ),

          const SizedBox(height: 20),

          // Description input
          Text(
            'Why is this website suspicious?',
            style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            style: TextStyle(color: textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Describe why you believe this website is suspicious.',
              hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
              filled: true,
              fillColor: context.cardBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: activeGreen),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 20),

          // Screenshot picker
          Text(
            'Evidence Screenshot (Optional)',
            style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickScreenshot,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border, style: BorderStyle.solid),
              ),
              child: _screenshotFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: textSecondary, size: 28),
                        const SizedBox(height: 8),
                        Text('Add Screenshot', style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Screenshots help moderators verify faster.', style: TextStyle(color: textSecondary, fontSize: 10)),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              base64Decode(_screenshotBase64!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.6),
                            radius: 16,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _screenshotFile = null;
                                  _screenshotBase64 = null;
                                });
                              },
                            ),
                          ),
                        )
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _descriptionController.text.trim().isNotEmpty
                  ? () => _navigateToStep(5) // Review step
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Review Submission', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 6 ====================
  Widget _buildStep6Review(BuildContext context) {
    final activeGreen = const Color(0xFF16A34A);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Report',
            style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Confirm the details before sending to URL Defender Threat Intelligence verification queue.',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewItem('URL', _urlController.text.trim()),
                const Divider(height: 20),
                _buildReviewItem('Category', _categories.firstWhere((cat) => cat['value'] == _selectedCategory)['label']!),
                const Divider(height: 20),
                _buildReviewItem('Description', _descriptionController.text.trim()),
                if (_screenshotBase64 != null) ...[
                  const Divider(height: 20),
                  Text('Evidence Screenshot', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(_screenshotBase64!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Notice: Your report will be reviewed by automated systems and community moderators. You will receive updates as the investigation progresses.',
            style: TextStyle(color: context.textSecondary, fontSize: 11, height: 1.45),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => _navigateToStep(4), // Go back to edit
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ==================== STEP 7 ====================
  Widget _buildStep7Success(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.gpp_good_outlined,
            color: Color(0xFF16A34A),
            size: 64,
          ),
          const SizedBox(height: 18),
          Text(
            'Community Investigation Started',
            style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Thank you for helping protect the community. Your report has entered the investigation queue. We will notify you whenever the status changes.',
            style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Visual Timeline Stepper
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: const ProgressTimeline(
              status: 'pending',
              step3Completed: true,
            ),
          ),

          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Exit wizard
                // Navigate to MyReportStatusScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyReportStatusScreen(url: _urlController.text.trim()),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View My Report', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// ==================== REUSABLE TIMELINE STEPPER ====================
class ProgressTimeline extends StatelessWidget {
  final String status;
  final bool step3Completed;

  const ProgressTimeline({
    super.key,
    required this.status,
    this.step3Completed = false,
  });

  @override
  Widget build(BuildContext context) {
    // Stepper stages
    // 1. Report Submitted (complete)
    // 2. Initial Analysis Complete (complete if scan ran)
    // 3. Community Verification (pending/complete)
    // 4. Moderator Review (pending/complete)
    // 5. Final Verdict (pending)
    
    final isHighRisk = status == 'high_risk';
    final isNeedsReview = status == 'needs_review';
    final isCompleted = status == 'completed' || status == 'verified' || status == 'high_risk' || status == 'needs_review';

    return Column(
      children: [
        _buildTimelineStep(context, 'Report Submitted', true, true),
        _buildTimelineStep(context, 'Initial Analysis Complete', step3Completed, true),
        _buildTimelineStep(context, 'Community Verification', isCompleted, false),
        _buildTimelineStep(context, 'Moderator Review', isHighRisk || isNeedsReview, false),
        _buildTimelineStep(context, 'Final Verdict', status == 'verified', false, isLast: true),
      ],
    );
  }

  Widget _buildTimelineStep(
    BuildContext context,
    String title,
    bool isCompleted,
    bool isStepCompletedBefore, {
    bool isLast = false,
  }) {
    final activeGreen = const Color(0xFF16A34A);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? activeGreen : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? activeGreen : Colors.grey,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isCompleted ? activeGreen : Colors.grey.withOpacity(0.5),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              title,
              style: TextStyle(
                color: isCompleted ? context.textPrimary : context.textSecondary,
                fontSize: 13,
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
