import 'package:flutter/material.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'models.dart';
import 'task_repository.dart';

/// Modal bottom sheet for handing over an active task.
class HandoverModal extends StatefulWidget {
  const HandoverModal({
    super.key,
    required this.taskId,
    required this.currentVehicleId,
  });

  final String taskId;
  final String currentVehicleId;

  static Future<bool?> show(
    BuildContext context, {
    required String taskId,
    required String currentVehicleId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HandoverModal(
        taskId: taskId,
        currentVehicleId: currentVehicleId,
      ),
    );
  }

  @override
  State<HandoverModal> createState() => _HandoverModalState();
}

class _HandoverModalState extends State<HandoverModal> {
  static const _presetReasons = [
    'Driver unable to continue — medical / personal',
    'Vehicle mechanical issue',
    'Crew fatigue / end of shift mid-case',
    'Escalation — higher-capability unit needed',
    'Conflict of interest / safety concern',
    'Other — see notes',
  ];

  final TaskRepository _repository = const TaskRepository();
  final TextEditingController _notesController = TextEditingController();

  int? _selectedPresetIndex;
  bool _autoAssign = true;
  bool _isSubmitting = false;
  bool _isLoadingVehicles = false;
  List<HandoverVehicle> _availableVehicles = [];
  String? _selectedVehicleId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _combinedReason {
    final preset =
        _selectedPresetIndex != null ? _presetReasons[_selectedPresetIndex!] : '';
    final note = _notesController.text.trim();
    if (note.isEmpty) return preset;
    return '$preset — $note';
  }

  bool get _isValid {
    if (_selectedPresetIndex == null) return false;
    if (_combinedReason.length < 5) return false;
    if (!_autoAssign && _selectedVehicleId == null) return false;
    return true;
  }

  Future<void> _fetchAvailableVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final vehicles =
          await _repository.getAvailableForHandover(widget.currentVehicleId);
      if (mounted) {
        setState(() {
          _availableVehicles = vehicles;
          _isLoadingVehicles = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
        _showSnackBar('Failed to load available vehicles', isError: true);
      }
    }
  }

  Future<void> _submit() async {
    if (!_isValid) return;

    setState(() => _isSubmitting = true);

    try {
      await _repository.reassignTask(
        widget.taskId,
        reason: _combinedReason,
        newVehicleId: _autoAssign ? null : _selectedVehicleId,
        autoAssign: _autoAssign ? true : null,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackBar('Handover failed — please try again', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.onPrimary)),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'HANDOVER TASK',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SELECT REASON',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(_presetReasons.length, (i) {
                    final selected = _selectedPresetIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPresetIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.07)
                                : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _presetReasons[i],
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.text,
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text(
                    'ADDITIONAL NOTES (OPTIONAL)',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Provide any additional context…',
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-assign available driver',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'System picks the next available vehicle',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _autoAssign,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _autoAssign = val;
                              if (!val) {
                                _fetchAvailableVehicles();
                              } else {
                                _selectedVehicleId = null;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (!_autoAssign) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'SELECT VEHICLE',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingVehicles)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      )
                    else if (_availableVehicles.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'No vehicles currently available for handover.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      ...List.generate(_availableVehicles.length, (i) {
                        final v = _availableVehicles[i];
                        final selected = _selectedVehicleId == v.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedVehicleId =
                                    selected ? null : v.id;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.07)
                                    : AppColors.inputBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.local_shipping_outlined,
                                    size: 20,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.registrationNumber,
                                          style: TextStyle(
                                            color: selected
                                                ? AppColors.primary
                                                : AppColors.text,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (v.driverName != null)
                                          Text(
                                            'Driver: ${v.driverName}',
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          _isValid && !_isSubmitting ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                              'Confirm handover',
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
        ],
      ),
    );
  }
}
