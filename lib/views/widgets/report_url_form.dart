import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/community_threat_service.dart';
import '../../providers/app_providers.dart';

class ReportUrlForm extends ConsumerStatefulWidget {
  final String url;

  const ReportUrlForm({super.key, required this.url});

  @override
  ConsumerState<ReportUrlForm> createState() => _ReportUrlFormState();
}

class _ReportUrlFormState extends ConsumerState<ReportUrlForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.url);
  }
  
  String _selectedCategory = 'phishing';
  XFile? _screenshotFile;
  String? _screenshotBase64;
  bool _isSubmitting = false;

  final List<Map<String, String>> _categories = [
    {'value': 'phishing', 'label': 'Phishing'},
    {'value': 'malware', 'label': 'Malware'},
    {'value': 'scam', 'label': 'Scam'},
    {'value': 'fake_login', 'label': 'Fake Login'},
    {'value': 'crypto_scam', 'label': 'Crypto Scam'},
    {'value': 'spam', 'label': 'Spam'},
    {'value': 'unsafe_download', 'label': 'Unsafe Download'},
  ];

  @override
  void dispose() {
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        final name = image.name.toLowerCase();
        if (!name.endsWith('.png') && !name.endsWith('.jpg') && !name.endsWith('.jpeg') && !name.endsWith('.webp')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid file format. Please pick a PNG, JPG, or WEBP image.'),
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
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final service = ref.read(communityThreatServiceProvider);
      await service.submitReport(
        url: _urlController.text.trim(),
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        screenshotBase64: _screenshotBase64,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Basic report created — we're running a full scan and will update this shortly."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cardBg;
    final surfaceColor = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: surfaceColor, width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.report_problem_outlined,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Report Suspicious URL',
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Target URL:',
                style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _urlController,
                style: TextStyle(color: textPrimary, fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surfaceColor.withValues(alpha: 0.1),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: surfaceColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.activeAccent),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Threat Category:',
                style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: cardBg,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: surfaceColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.activeAccent),
                    borderRadius: BorderRadius.circular(10),
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
              const SizedBox(height: 16),
              Text(
                'Description:',
                style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                style: TextStyle(color: textPrimary),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe the threat (e.g. spoofed login page, fake support number, etc.)',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: surfaceColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.activeAccent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (val.trim().length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Attach Screenshot (Optional):',
                style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image, size: 18),
                    label: const Text('Pick Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: surfaceColor,
                      foregroundColor: textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_screenshotFile != null)
                    Expanded(
                      child: Text(
                        _screenshotFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: context.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.activeAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: textPrimary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit',
                    style: TextStyle(
                      color: _isSubmitting ? Colors.white.withOpacity(0.5) : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
