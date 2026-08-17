import 'package:flutter/material.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'task_repository.dart';

class PatientDataScreen extends StatefulWidget {
  const PatientDataScreen({
    super.key,
    required this.taskId,
    this.initialPreHospital,
    this.initialChallenges,
    this.initialHandoverVitals,
  });

  final String taskId;
  final String? initialPreHospital;
  final String? initialChallenges;
  final Map<String, dynamic>? initialHandoverVitals;

  @override
  State<PatientDataScreen> createState() => _PatientDataScreenState();
}

class _PatientDataScreenState extends State<PatientDataScreen> {
  final TaskRepository _repository = const TaskRepository();

  late final TextEditingController _preHospitalController;
  late final TextEditingController _challengesController;

  // Handover Vitals Controllers
  late final TextEditingController _tempController;
  late final TextEditingController _bpController;
  late final TextEditingController _spo2Controller;
  late final TextEditingController _pulseController;
  late final TextEditingController _gcsController;
  late final TextEditingController _rrController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _preHospitalController =
        TextEditingController(text: widget.initialPreHospital ?? '');
    _challengesController =
        TextEditingController(text: widget.initialChallenges ?? '');

    final initialVitals = widget.initialHandoverVitals ?? {};
    _tempController = TextEditingController(
        text: initialVitals['temperature']?.toString() ?? '');
    _bpController =
        TextEditingController(text: initialVitals['bp']?.toString() ?? '');
    _spo2Controller =
        TextEditingController(text: initialVitals['spo2']?.toString() ?? '');
    _pulseController = TextEditingController(
        text: initialVitals['pulseRate']?.toString() ?? '');
    _gcsController =
        TextEditingController(text: initialVitals['gcs']?.toString() ?? '');
    _rrController = TextEditingController(
        text: initialVitals['respirationRate']?.toString() ?? '');
  }

  @override
  void dispose() {
    _preHospitalController.dispose();
    _challengesController.dispose();
    _tempController.dispose();
    _bpController.dispose();
    _spo2Controller.dispose();
    _pulseController.dispose();
    _gcsController.dispose();
    _rrController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final preHospital = _preHospitalController.text.trim();
    final challenges = _challengesController.text.trim();

    // ── Validation ──────────────────────────────────────────────────────────
    if (preHospital.isEmpty) {
      _showSnackBar('Pre-hospital management notes are required', isError: true);
      return;
    }

    // ── Build Handover Vitals Payload (only non-empty fields) ───────────────
    final vitals = <String, String>{};
    if (_tempController.text.trim().isNotEmpty) {
      vitals['temperature'] = _tempController.text.trim();
    }
    if (_bpController.text.trim().isNotEmpty) {
      vitals['bp'] = _bpController.text.trim();
    }
    if (_spo2Controller.text.trim().isNotEmpty) {
      vitals['spo2'] = _spo2Controller.text.trim();
    }
    if (_pulseController.text.trim().isNotEmpty) {
      vitals['pulseRate'] = _pulseController.text.trim();
    }
    if (_gcsController.text.trim().isNotEmpty) {
      vitals['gcs'] = _gcsController.text.trim();
    }
    if (_rrController.text.trim().isNotEmpty) {
      vitals['respirationRate'] = _rrController.text.trim();
    }

    setState(() => _isSubmitting = true);

    try {
      await _repository.submitPatientData(
        taskId: widget.taskId,
        preHospitalManagement: preHospital,
        dispatcherChallenges: challenges.isNotEmpty ? challenges : null,
        handoverVitals: vitals.isNotEmpty ? vitals : null,
      );

      if (!mounted) return;
      _showSnackBar('Clinical notes & vitals saved successfully');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackBar('Failed to save data. Please try again.', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.onPrimary),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Patient / Clinical Notes & Vitals',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Pre-hospital management ─────────────────────────────────────
              const Text(
                'Pre-hospital Management *',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _preHospitalController,
                minLines: 6,
                maxLines: 10,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'e.g. Patient conscious, BP 120/80, O2 administered via nasal cannula at 4L/min, IV access secured...',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.inputBg,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Dispatcher challenges ───────────────────────────────────────
              const Text(
                'Dispatcher Challenges (Optional)',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _challengesController,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'e.g. Heavy traffic along Mombasa Road, narrow access road at scene...',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.inputBg,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: AppColors.border),
              const SizedBox(height: 16),

              // ── Handover Vitals Section ─────────────────────────────────────
              Row(
                children: const [
                  Icon(Icons.monitor_heart_outlined,
                      size: 20, color: AppColors.brandNavy),
                  SizedBox(width: 8),
                  Text(
                    'HANDOVER VITALS (OPTIONAL)',
                    style: TextStyle(
                      color: AppColors.brandNavy,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Record vital signs observed at hospital / facility handover.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Vitals Grid (2 items per row)
              Row(
                children: [
                  Expanded(
                    child: _buildVitalField(
                      controller: _tempController,
                      label: 'Temperature',
                      hint: '37.2 °C',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalField(
                      controller: _bpController,
                      label: 'Blood Pressure',
                      hint: '120/80',
                      keyboardType: TextInputType.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildVitalField(
                      controller: _spo2Controller,
                      label: 'SpO₂ (%)',
                      hint: '98',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalField(
                      controller: _pulseController,
                      label: 'Pulse Rate (bpm)',
                      hint: '80',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildVitalField(
                      controller: _gcsController,
                      label: 'GCS (3–15)',
                      hint: '15',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalField(
                      controller: _rrController,
                      label: 'Respiration Rate',
                      hint: '18',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Submit button ───────────────────────────────────────────────
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandNavy,
                    disabledBackgroundColor:
                        AppColors.brandNavy.withValues(alpha: 0.6),
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.onPrimary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Notes & Handover Vitals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppColors.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
