import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/storage/secure_storage_service.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'history_repository.dart';
import 'models.dart';

/// Screen for viewing details and PCR reports for a past history task.
class PcrViewerScreen extends StatefulWidget {
  const PcrViewerScreen({
    super.key,
    required this.task,
  });

  final HistoryTask task;

  @override
  State<PcrViewerScreen> createState() => _PcrViewerScreenState();
}

class _PcrViewerScreenState extends State<PcrViewerScreen> {
  final HistoryRepository _repository = const HistoryRepository();

  bool _isLoading = true;
  String? _authToken;
  List<PcrReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadPcrData();
  }

  Future<void> _loadPcrData() async {
    setState(() => _isLoading = true);
    try {
      final token = await SecureStorageService.instance.getToken();
      final reports = await _repository.getPcrReports(widget.task.id);

      if (mounted) {
        setState(() {
          _authToken = token;
          _reports = reports;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load PCR reports', isError: true);
      }
    }
  }

  Future<void> _launchFileUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnackBar('Could not open report file link', isError: true);
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

  static (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'COMPLETED':
        return (AppColors.accent, const Color(0xFFD1FAE5));
      case 'CANCELLED':
        return (AppColors.danger, AppColors.dangerBg);
      default:
        return (AppColors.textSecondary, AppColors.inputBg);
    }
  }

  static String _formatDate(String isoString) {
    if (isoString.isEmpty) return 'Date unknown';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[dt.month - 1];
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $month ${dt.year}, $hour:$minute $period';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final (textColor, bgColor) = _statusColors(task.status);
    final displayDate = _formatDate(task.completedAt ?? task.receivedAt);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Task Details — ${task.caseNumber}',
          style: const TextStyle(
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          task.caseNumber,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            task.status,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          displayDate,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 12),

                    const Text(
                      'CHIEF COMPLAINT',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.chiefComplaint,
                      style: const TextStyle(color: AppColors.text, fontSize: 14),
                    ),

                    if (task.locationName.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${task.locationName}${task.subCounty.isNotEmpty ? ', ${task.subCounty}' : ''}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: const [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 20, color: AppColors.brandNavy),
                  SizedBox(width: 8),
                  Text(
                    'PATIENT CARE REPORTS (PCR)',
                    style: TextStyle(
                      color: AppColors.brandNavy,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_reports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No PCR reports uploaded yet.',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'No digital Patient Care Report was submitted for this assignment.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reports.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                  itemBuilder: (ctx, i) {
                    final report = _reports[i];
                    final fileUrl = _repository.getPcrFileUrl(task.id, report.id);

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (report.isImage) ...[
                            Container(
                              constraints: const BoxConstraints(maxHeight: 260),
                              width: double.infinity,
                              color: AppColors.inputBg,
                              child: Image.network(
                                fileUrl,
                                headers: _authToken != null
                                    ? {'Authorization': 'Bearer $_authToken'}
                                    : null,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, error, stack) => Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image_outlined,
                                          size: 36, color: AppColors.textMuted),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Unable to load image inline',
                                        style: TextStyle(
                                            color: AppColors.textMuted, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      report.isImage
                                          ? Icons.image_outlined
                                          : Icons.picture_as_pdf_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        report.originalName,
                                        style: const TextStyle(
                                          color: AppColors.text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                                if (report.note != null && report.note!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Note: ${report.note}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _launchFileUrl(fileUrl),
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('Open / View Report File'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
