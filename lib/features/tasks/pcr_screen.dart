import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'task_repository.dart';

class PcrScreen extends StatefulWidget {
  const PcrScreen({
    super.key,
    required this.taskId,
  });

  final String taskId;

  @override
  State<PcrScreen> createState() => _PcrScreenState();
}

class _PcrScreenState extends State<PcrScreen> {
  final TaskRepository _repository = const TaskRepository();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _noteController = TextEditingController();

  File? _selectedFile;
  String? _selectedFileName;
  bool _isImage = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ── File Selection ─────────────────────────────────────────────────────────

  Future<void> _pickCameraPhoto() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        debugPrint('[PcrScreen] Camera permission denied: $status');
        _showSnackBar('Camera permission is required to take a photo', isError: true);
        return;
      }

      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 60,
      );
      if (picked != null) {
        final file = File(picked.path);
        debugPrint('[PcrScreen] Camera photo captured: ${file.path}, size: ${file.lengthSync()} bytes');
        setState(() {
          _selectedFile = file;
          _selectedFileName = picked.name;
          _isImage = true;
        });
      }
    } catch (e, st) {
      debugPrint('[PcrScreen] Camera error: $e\n$st');
      _showSnackBar('Failed to capture photo from camera', isError: true);
    }
  }

  Future<void> _pickGalleryImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
      if (picked != null) {
        final file = File(picked.path);
        debugPrint('[PcrScreen] Gallery image selected: ${file.path}, size: ${file.lengthSync()} bytes');
        setState(() {
          _selectedFile = file;
          _selectedFileName = picked.name;
          _isImage = true;
        });
      }
    } catch (e, st) {
      debugPrint('[PcrScreen] Gallery error: $e\n$st');
      _showSnackBar('Failed to select image from gallery', isError: true);
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          final file = File(path);
          debugPrint('[PcrScreen] Document selected: ${file.path}, exists: ${file.existsSync()}, size: ${file.existsSync() ? file.lengthSync() : 0}');
          setState(() {
            _selectedFile = file;
            _selectedFileName = result.files.first.name;
            _isImage = false;
          });
        }
      }
    } catch (e, st) {
      debugPrint('[PcrScreen] FilePicker error: $e\n$st');
      _showSnackBar('Failed to select PDF/DOCX file', isError: true);
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _isImage = false;
    });
  }

  // ── Submit & Skip Handlers ──────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    final file = _selectedFile;
    if (file == null) {
      _showSnackBar(
        'Add a report. Take a photo, choose an image, or pick a PDF/DOCX file.',
        isError: true,
      );
      return;
    }

    if (!file.existsSync()) {
      debugPrint('[PcrScreen] File does not exist on disk: ${file.path}');
      _showSnackBar('Selected file no longer exists on device disk', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    debugPrint('[PcrScreen] Submitting PCR for taskId: ${widget.taskId}, file: ${file.path}, size: ${file.lengthSync()} bytes');

    try {
      await _repository.submitPcr(
        taskId: widget.taskId,
        file: file,
        note: _noteController.text.trim(),
      );

      debugPrint('[PcrScreen] PCR upload SUCCESS for taskId: ${widget.taskId}');
      if (!mounted) return;
      _showSnackBar('Patient Care Report uploaded successfully');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      debugPrint('[PcrScreen] ApiException during submitPcr: ${e.message}');
      if (!mounted) return;
      setState(() => _isUploading = false);
      if (e.message.toLowerCase().contains('413') ||
          e.message.toLowerCase().contains('too large')) {
        _showSnackBar(
          'File is too large. Use a smaller photo/PDF (under ~20MB) or take a new compressed photo.',
          isError: true,
        );
      } else {
        _showSnackBar(e.message, isError: true);
      }
    } catch (e, st) {
      debugPrint('[PcrScreen] General error during submitPcr: $e\n$st');
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar('Failed to upload report. Please try again.', isError: true);
      }
    }
  }

  Future<void> _handleSkip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip PCR Upload?'),
        content: const Text(
          'Dispatch may require this report for patient record handover.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Skip & Finish'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.of(context).pop(false);
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
    final file = _selectedFile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Patient Care Report (PCR)',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
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
              // ── Header Notice ───────────────────────────────────────────────
              const Text(
                'Attach PCR Document or Photo',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Take a photo of the paper PCR form or upload an image, PDF, or DOCX document.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 20),

              // ── File Selection Buttons ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickCameraPhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Take Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickGalleryImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Choose Image'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickDocument,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Choose PDF / DOCX File'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Preview Area ────────────────────────────────────────────────
              if (file != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (_isImage)
                        Container(
                          height: 220,
                          width: double.infinity,
                          color: AppColors.inputBg,
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.inputBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.description_outlined,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedFileName ?? 'Document',
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
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
                      Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedFileName ?? 'Selected File',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isUploading ? null : _clearSelectedFile,
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Remove'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Optional Note Field ─────────────────────────────────────────
              const Text(
                'PCR Note (Optional)',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                minLines: 4,
                maxLines: 6,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add any optional summary or notes regarding this PCR...',
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

              const SizedBox(height: 32),

              // ── Submit Button ───────────────────────────────────────────────
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _handleSubmit,
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
                  child: _isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: AppColors.onPrimary,
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Uploading Report...'),
                          ],
                        )
                      : const Text(
                          'Submit Patient Care Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Skip Option ─────────────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: _isUploading ? null : _handleSkip,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
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
}
