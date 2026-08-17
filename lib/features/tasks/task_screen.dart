import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/network/socket_service.dart';
import 'package:mobileapp/core/storage/secure_storage_service.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'end_case_modal.dart';
import 'handover_modal.dart';
import 'models.dart';
import 'navigate_screen.dart';
import 'patient_data_screen.dart';
import 'pcr_screen.dart';
import 'task_repository.dart';
import 'task_stops_widget.dart';

/// Active task screen for field responders.
class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TaskRepository _repository = const TaskRepository();

  bool _isLoading = true;
  bool _isAdvancing = false;
  ActiveTask? _activeTask;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadActiveTask();
    _registerSocketListeners();
  }

  @override
  void dispose() {
    _unregisterSocketListeners();
    super.dispose();
  }

  void _onTaskEvent(dynamic _) {
    _loadActiveTask(silent: true);
  }

  void _registerSocketListeners() {
    SocketService.instance.onTaskAssigned(_onTaskEvent);
    SocketService.instance.onTaskUpdated(_onTaskEvent);
  }

  void _unregisterSocketListeners() {
    SocketService.instance.offTaskAssigned(_onTaskEvent);
    SocketService.instance.offTaskUpdated(_onTaskEvent);
  }

  bool get _isDriver => _userRole == 'DRIVER';

  Future<void> _loadUserRole() async {
    final user = await SecureStorageService.instance.getUser();
    if (mounted && user != null) {
      setState(() => _userRole = user['role'] as String?);
    }
  }

  Future<void> _loadActiveTask({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);

    try {
      final task = await _repository.getActiveTask();
      if (mounted) {
        setState(() {
          _activeTask = task;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) _showSnackBar('Failed to load task', isError: true);
      }
    }
  }

  Future<void> _advanceStatus() async {
    final task = _activeTask;
    if (task == null) return;

    final nextStatus = _nextStatus(task.status);
    if (nextStatus == null) return;

    setState(() => _isAdvancing = true);

    try {
      await _repository.updateTaskStatus(task.id, nextStatus);

      if (mounted) {
        setState(() => _isAdvancing = false);
        if (nextStatus == 'COMPLETED') {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PcrScreen(taskId: task.id),
            ),
          );
          _loadActiveTask();
        } else if (nextStatus == 'ACCEPTED') {
          await _loadActiveTask(silent: true);
          if (mounted) _onLocationTap(task);
        } else {
          await _loadActiveTask(silent: true);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isAdvancing = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAdvancing = false);
        _showSnackBar('Failed to update status', isError: true);
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

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) _showSnackBar('Could not open dialler', isError: true);
    }
  }

  Future<void> _openHandoverModal(ActiveTask task) async {
    final result = await HandoverModal.show(
      context,
      taskId: task.id,
      currentVehicleId: task.vehicle.id,
    );
    if (result == true && mounted) {
      _showSnackBar('Task handed over successfully');
      _loadActiveTask();
    }
  }

  Future<void> _openEndCaseModal(ActiveTask task) async {
    final result = await EndCaseModal.show(
      context,
      incidentId: task.incident.id,
      caseNumber: task.incident.caseNumber,
    );
    if (result == true && mounted) {
      _showSnackBar('Case closed successfully');
      _loadActiveTask();
    }
  }

  void _onLocationTap(ActiveTask task) {
    final lat = task.incident.lat ?? -1.5167;
    final lng = task.incident.lng ?? 37.2667;
    final name = '${task.incident.locationName}, ${task.incident.subCounty}'.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigateScreen(
          destinationLat: lat,
          destinationLng: lng,
          destinationName: name,
        ),
      ),
    );
  }

  static String? _nextStatus(String current) {
    const transitions = {
      'PENDING': 'ACCEPTED',
      'ACCEPTED': 'EN_ROUTE',
      'EN_ROUTE': 'AT_SCENE',
      'AT_SCENE': 'PATIENT_PICKED',
      'PATIENT_PICKED': 'AT_HOSPITAL',
      'AT_HOSPITAL': 'COMPLETED',
    };
    return transitions[current];
  }

  static String _buttonLabel(String current) {
    const labels = {
      'PENDING': 'Accept Assignment',
      'ACCEPTED': 'Start En Route',
      'EN_ROUTE': 'Arrived at Scene',
      'AT_SCENE': 'Patient Picked Up',
      'PATIENT_PICKED': 'Arrived at the hospital',
      'AT_HOSPITAL': 'Complete Task',
    };
    return labels[current] ?? '';
  }

  static String _statusDisplay(String status) {
    const display = {
      'PENDING': 'PENDING',
      'ACCEPTED': 'ACCEPTED',
      'EN_ROUTE': 'EN ROUTE',
      'AT_SCENE': 'AT SCENE',
      'PATIENT_PICKED': 'PATIENT PICKED',
      'AT_HOSPITAL': 'AT HOSPITAL',
      'COMPLETED': 'COMPLETED',
      'CANCELLED': 'CANCELLED',
    };
    return display[status] ?? status;
  }

  static (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'PENDING':
        return (const Color(0xFFB7791F), const Color(0xFFFBF1DD));
      case 'ACCEPTED':
        return (const Color(0xFF2563EB), const Color(0xFFE8EFFD));
      case 'EN_ROUTE':
        return (AppColors.primary, const Color(0xFFE8F3ED));
      case 'AT_SCENE':
        return (AppColors.text, const Color(0xFFEDF2EF));
      case 'PATIENT_PICKED':
        return (const Color(0xFFB7791F), const Color(0xFFFBF3DD));
      case 'AT_HOSPITAL':
        return (const Color(0xFF2563EB), const Color(0xFFE8EFFD));
      case 'COMPLETED':
        return (AppColors.primary, const Color(0xFFE8F3ED));
      case 'CANCELLED':
        return (AppColors.danger, AppColors.dangerBg);
      default:
        return (AppColors.textSecondary, AppColors.inputBg);
    }
  }

  static const _vitalsLabels = {
    'temperature': 'Temp',
    'pulseRate': 'Pulse',
    'respirationRate': 'RR',
    'bp': 'BP',
    'spo2': 'SpO₂',
    'gcs': 'GCS',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        title: const Text(
          'Machakos EOC',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: () => _loadActiveTask(silent: true),
              color: AppColors.primary,
              child: _activeTask == null
                  ? _buildEmptyState()
                  : _buildActiveTask(_activeTask!),
            ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_hospital_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No active assignment',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You will be notified when dispatch\nassigns a case.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTask(ActiveTask task) {
    final incident = task.incident;
    final hasVitals = incident.vitals != null && incident.vitals!.isNotEmpty;
    final hasPatient = incident.patientName != null ||
        incident.patientAge != null ||
        incident.patientGender != null ||
        incident.patientContact != null;
    final hasNextOfKin =
        incident.nextOfKin != null || incident.nextOfKinPhone != null;
    final canAdvance = _nextStatus(task.status) != null;

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCaseHeader(incident.caseNumber, task.status),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => PatientDataScreen(
                        taskId: task.id,
                        initialPreHospital: incident.preHospitalManagement,
                        initialChallenges: incident.dispatcherChallenges,
                        initialHandoverVitals: task.handoverVitals,
                      ),
                    ),
                  ).then((updated) {
                    if (updated == true) _loadActiveTask(silent: true);
                  });
                },
                icon: const Icon(Icons.note_alt_outlined, size: 18),
                label: const Text('Patient / Clinical Notes & Vitals'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      icon: Icons.report_outlined,
                      title: 'Chief Complaint',
                      child: Text(
                        incident.chiefComplaint,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                    _divider(),
                    if (incident.alertNature != null) ...[
                      _buildSection(
                        icon: Icons.category_outlined,
                        title: 'Nature of Alert',
                        child: Text(
                          [
                            incident.alertNature,
                            if (incident.alertNatureDetail != null)
                              incident.alertNatureDetail,
                          ].join(' — '),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _divider(),
                    ],
                    _buildSection(
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      child: GestureDetector(
                        onTap: () => _onLocationTap(task),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${incident.locationName}, ${incident.subCounty}',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.navigation_outlined,
                              size: 18,
                              color: AppColors.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _divider(),
                    _buildSection(
                      icon: Icons.local_shipping_outlined,
                      title: 'Vehicle',
                      child: Text(
                        task.vehicle.registrationNumber,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _divider(),
                    TaskStopsWidget(
                      taskId: task.id,
                      isTaskActive: task.status != 'COMPLETED' && task.status != 'CANCELLED',
                    ),
                    if (hasPatient) ...[
                      _divider(),
                      _buildPatientSection(incident),
                    ],
                    if (hasNextOfKin) ...[
                      _divider(),
                      _buildNextOfKinSection(incident),
                    ],
                    if (hasVitals) ...[
                      _divider(),
                      _buildVitalsSection(incident.vitals!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (canAdvance)
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isAdvancing ? null : _advanceStatus,
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
                    child: _isAdvancing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.onPrimary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _buttonLabel(task.status),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              if (_isDriver && canAdvance) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openHandoverModal(task),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Handover'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openEndCaseModal(task),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('End Case'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (_isAdvancing)
          Container(
            color: Colors.black.withValues(alpha: 0.15),
          ),
      ],
    );
  }

  Widget _buildCaseHeader(String caseNumber, String status) {
    final (textColor, bgColor) = _statusColors(status);
    return Row(
      children: [
        Expanded(
          child: Text(
            caseNumber,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusDisplay(status),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildPatientSection(TaskIncident incident) {
    return _buildSection(
      icon: Icons.person_outlined,
      title: 'Patient',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incident.patientName != null)
            Text(
              incident.patientName!,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          if (incident.patientAge != null || incident.patientGender != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                [
                  if (incident.patientAge != null) 'Age: ${incident.patientAge}',
                  if (incident.patientGender != null) incident.patientGender,
                ].join('  ·  '),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          if (incident.patientContact != null)
            _buildPhoneRow(incident.patientContact!, label: 'Patient'),
        ],
      ),
    );
  }

  Widget _buildNextOfKinSection(TaskIncident incident) {
    return _buildSection(
      icon: Icons.family_restroom_outlined,
      title: 'Next of Kin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incident.nextOfKin != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                incident.nextOfKin!,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (incident.nextOfKinPhone != null)
            _buildPhoneRow(incident.nextOfKinPhone!, label: 'Next of Kin'),
        ],
      ),
    );
  }

  Widget _buildPhoneRow(String phone, {required String label}) {
    return GestureDetector(
      onTap: () => _launchPhone(phone),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_outlined, size: 15, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            phone,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsSection(Map<String, dynamic> vitals) {
    final entries = vitals.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      icon: Icons.monitor_heart_outlined,
      title: 'Vitals',
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: entries.map((e) {
          final label = _vitalsLabels[e.key] ?? _titleCase(e.key);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: e.value.toString(),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, color: AppColors.border);
  }

  static String _titleCase(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
