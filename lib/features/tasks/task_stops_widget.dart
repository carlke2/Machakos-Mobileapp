import 'package:flutter/material.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/network/socket_service.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'models.dart';
import 'task_repository.dart';

/// Widget displaying intermediate task stops (re-routes) and an "Add Stop" action.
class TaskStopsWidget extends StatefulWidget {
  const TaskStopsWidget({
    super.key,
    required this.taskId,
    required this.isTaskActive,
  });

  final String taskId;
  final bool isTaskActive;

  @override
  State<TaskStopsWidget> createState() => _TaskStopsWidgetState();
}

class _TaskStopsWidgetState extends State<TaskStopsWidget> {
  final TaskRepository _repository = const TaskRepository();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<TaskStop> _stops = [];

  @override
  void initState() {
    super.initState();
    _loadStops();
    _registerSocketListeners();
  }

  @override
  void dispose() {
    _unregisterSocketListeners();
    super.dispose();
  }

  void _onStopSocketEvent(dynamic _) {
    _loadStops(silent: true);
  }

  void _registerSocketListeners() {
    SocketService.instance.onTaskUpdated(_onStopSocketEvent);
  }

  void _unregisterSocketListeners() {
    SocketService.instance.offTaskUpdated(_onStopSocketEvent);
  }

  Future<void> _loadStops({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);

    try {
      final stops = await _repository.getStops(widget.taskId);
      if (mounted) {
        setState(() {
          _stops = stops;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openAddStopSheet() async {
    final nameController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Intermediate Stop',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Specify a re-route facility or intermediate destination during transit.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Location Name Input
              const Text(
                'Destination / Stop Name *',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Mama Lucy Kibaki Hospital',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Optional Note Input
              const Text(
                'Reason / Note (Optional)',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Patient needs CT scan not available at primary facility',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit CTA
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandNavy,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Stop name is required'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text(
                    'Add Stop',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      final name = nameController.text.trim();
      final note = noteController.text.trim();
      if (name.isNotEmpty) {
        await _addStop(name: name, note: note.isNotEmpty ? note : null);
      }
    }
  }

  Future<void> _addStop({required String name, String? note}) async {
    setState(() => _isSubmitting = true);
    try {
      await _repository.addStop(
        taskId: widget.taskId,
        name: name,
        note: note,
      );
      if (mounted) {
        _showSnackBar('Added stop: $name');
        await _loadStops(silent: true);
      }
    } on ApiException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnackBar('Failed to add stop', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _markArrived(TaskStop stop) async {
    setState(() => _isSubmitting = true);
    try {
      await _repository.markStopArrived(
        taskId: widget.taskId,
        stopId: stop.id,
      );
      if (mounted) {
        _showSnackBar('Arrived at ${stop.name}');
        await _loadStops(silent: true);
      }
    } on ApiException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnackBar('Failed to update stop status', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.alt_route_outlined, size: 16, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Text(
                    'TASK STOPS / RE-ROUTES',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (widget.isTaskActive)
                InkWell(
                  onTap: _isSubmitting ? null : _openAddStopSheet,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_circle_outline, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Add Stop',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else if (_stops.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No extra stops recorded for this task.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stops.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final stop = _stops[i];
                final isArrived = stop.isArrived;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isArrived
                        ? AppColors.accent.withValues(alpha: 0.05)
                        : AppColors.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isArrived
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isArrived
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isArrived ? Icons.check : Icons.pin_drop_outlined,
                          size: 16,
                          color: isArrived ? AppColors.accent : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.name,
                              style: TextStyle(
                                color: isArrived ? AppColors.textSecondary : AppColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: isArrived ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (stop.note != null && stop.note!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  stop.note!,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isArrived)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ARRIVED',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (widget.isTaskActive)
                        OutlinedButton(
                          onPressed: _isSubmitting ? null : () => _markArrived(stop),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Mark Arrived',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
