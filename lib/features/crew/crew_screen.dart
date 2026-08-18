import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/network/socket_service.dart';
import 'package:mobileapp/core/services/notification_service.dart';
import 'package:mobileapp/core/storage/secure_storage_service.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'package:mobileapp/features/auth/login_screen.dart';
import 'crew_repository.dart';
import 'models.dart';
import 'widgets/crew_slot_card.dart';

class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key});

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  final CrewRepository _repository = const CrewRepository();

  bool _isLoading = true;
  bool _isActionSubmitting = false;
  bool _isVehicleListExpanded = false;

  CheckInStatus? _activeCheckIn;
  List<Vehicle> _vehicles = [];
  List<CrewMember> _crewMembers = [];
  Vehicle? _selectedVehicle;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = await SecureStorageService.instance.getUser();
      final checkIn = await _repository.getMyCheckIn();
      final vehicles = await _repository.getVehicles();

      List<CrewMember> crewMembers = [];
      try {
        crewMembers = await _repository.getCrewMembers();
      } catch (e) {
        debugPrint('Failed to load assignable crew members: $e');
      }

      if (mounted) {
        setState(() {
          _user = user;
          _activeCheckIn = checkIn;
          _vehicles = vehicles;
          _crewMembers = crewMembers;
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
        _showSnackBar('Failed to load fleet data', isError: true);
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

  Future<void> _handleLogout() async {
    SocketService.instance.disconnect();
    await NotificationService.instance.clearToken();
    await SecureStorageService.instance.clearAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }


  Future<void> _openCrewPickerSheet(String roleTitle, String targetRole) async {
    final active = _activeCheckIn;
    if (active == null) return;

    final roleMembers = _crewMembers
        .where((c) => c.role.toUpperCase() == targetRole.toUpperCase())
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = roleMembers.where((m) {
              final query = searchQuery.trim().toLowerCase();
              if (query.isEmpty) return true;
              return m.name.toLowerCase().contains(query) ||
                  (m.phone != null && m.phone!.contains(query));
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select $roleTitle',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search bar
                  TextField(
                    onChanged: (val) {
                      setSheetState(() => searchQuery = val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // List of members
                  Expanded(
                    child: roleMembers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No available ${roleTitle}s found in your agency.',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No matching crew members.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.border),
                                itemBuilder: (ctx, i) {
                                  final member = filtered[i];

                                  // Check if assigned to OTHER slot
                                  final isOtherSlot = targetRole.toUpperCase() == 'EMT'
                                      ? active.currentNurse?.id == member.id
                                      : active.currentEmt?.id == member.id;

                                  // Check if assigned to THIS slot
                                  final isCurrentSlot = targetRole.toUpperCase() == 'EMT'
                                      ? active.currentEmt?.id == member.id
                                      : active.currentNurse?.id == member.id;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: isCurrentSlot
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : AppColors.inputBg,
                                      child: Text(
                                        member.name.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: isCurrentSlot ? AppColors.primary : AppColors.text,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      member.name,
                                      style: TextStyle(
                                        color: isOtherSlot ? AppColors.textMuted : AppColors.text,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Text(
                                      isOtherSlot
                                          ? 'Assigned as ${targetRole.toUpperCase() == 'EMT' ? 'Nurse' : 'EMT'}'
                                          : (member.phone ?? 'No phone listed'),
                                      style: TextStyle(
                                        color: isOtherSlot ? AppColors.danger : AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: isCurrentSlot
                                        ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                                        : isOtherSlot
                                            ? null
                                            : const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                                    enabled: !isOtherSlot,
                                    onTap: isOtherSlot
                                        ? null
                                        : () {
                                            Navigator.of(ctx).pop();
                                            _assignCrewMember(targetRole, member.id);
                                          },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _assignCrewMember(String targetRole, String memberId) async {
    final active = _activeCheckIn;
    if (active == null) return;

    setState(() => _isActionSubmitting = true);

    try {
      final isEmt = targetRole.toUpperCase() == 'EMT';
      final updatedCheckIn = isEmt
          ? await _repository.assignCrew(active.vehicleId, emtId: memberId)
          : await _repository.assignCrew(active.vehicleId, nurseId: memberId);

      if (mounted) {
        setState(() {
          _activeCheckIn = updatedCheckIn;
          _isActionSubmitting = false;
        });
        _showSnackBar('Assigned $targetRole successfully');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isActionSubmitting = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isActionSubmitting = false);
        _showSnackBar('Failed to assign $targetRole. Please try again.', isError: true);
      }
    }
  }

  Future<void> _clearCrewSlot(String targetRole) async {
    final active = _activeCheckIn;
    if (active == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear $targetRole'),
        content: Text('Are you sure you want to remove the assigned $targetRole from this vehicle?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionSubmitting = true);

    try {
      final isEmt = targetRole.toUpperCase() == 'EMT';
      final updatedCheckIn = isEmt
          ? await _repository.assignCrew(active.vehicleId, emtId: null)
          : await _repository.assignCrew(active.vehicleId, nurseId: null);

      if (mounted) {
        setState(() {
          _activeCheckIn = updatedCheckIn;
          _isActionSubmitting = false;
        });
        _showSnackBar('Cleared $targetRole assignment');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isActionSubmitting = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isActionSubmitting = false);
        _showSnackBar('Failed to clear $targetRole', isError: true);
      }
    }
  }


  Future<void> _onVehicleTap(Vehicle vehicle) async {
    setState(() => _selectedVehicle = vehicle);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Check In to ${vehicle.registrationNumber}'),
        content: const Text(
          'A check-in selfie photo and your location will be captured for shift accountability.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandNavy,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _startCheckInProcess(vehicle);
  }

  Future<void> _startCheckInProcess(Vehicle vehicle) async {
    // 1. Camera permission check
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showSnackBar('Camera permission is required to check in.', isError: true);
      return;
    }

    // 2. Selfie capture
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 60,
    );

    if (photo == null) {
      _showSnackBar('Check-in selfie is required', isError: true);
      return;
    }

    // 3. Location permission check
    LocationPermission locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied) {
      locPerm = await Geolocator.requestPermission();
    }

    if (locPerm == LocationPermission.denied ||
        locPerm == LocationPermission.deniedForever) {
      _showSnackBar('Location permission is required to check in.', isError: true);
      return;
    }

    // 4. Get GPS Position & submit
    setState(() => _isActionSubmitting = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final selfieFile = File(photo.path);

      final newCheckIn = await _repository.checkIn(
        vehicleId: vehicle.id,
        selfieFile: selfieFile,
        lat: position.latitude,
        lng: position.longitude,
      );

      if (mounted) {
        setState(() {
          _activeCheckIn = newCheckIn;
          _selectedVehicle = null;
          _isActionSubmitting = false;
        });
        _showSnackBar('Checked in successfully to ${vehicle.registrationNumber}');
        _loadInitialData(); // Refresh list & status
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isActionSubmitting = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionSubmitting = false);
        _showSnackBar('Check-in failed. Please try again.', isError: true);
      }
    }
  }


  Future<void> _handleCheckOut() async {
    final active = _activeCheckIn;
    if (active == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Shift'),
        content: Text('Are you sure you want to check out of ${active.registrationNumber}?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End Shift'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionSubmitting = true);

    try {
      await _repository.checkOut(active.vehicleId);
      if (mounted) {
        setState(() {
          _activeCheckIn = null;
          _isActionSubmitting = false;
        });
        _showSnackBar('Checked out successfully');
        _loadInitialData();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isActionSubmitting = false);
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isActionSubmitting = false);
        _showSnackBar('Failed to check out. Please try again.', isError: true);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        title: const Text(
          'Machakos EOC — Crew',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 20),
            tooltip: 'Log out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadInitialData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // User info header
                        _buildUserHeader(),
                        const SizedBox(height: 20),

                        // State 1: CHECKED IN view
                        if (_activeCheckIn != null) ...[
                          _buildCheckedInCard(_activeCheckIn!),
                          _buildCrewAssignmentSection(_activeCheckIn!),
                        ]
                        // State 2: NOT CHECKED IN view
                        else
                          _buildNotCheckedInSection(),
                      ],
                    ),
                  ),
                ),

                if (_isActionSubmitting)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.onPrimary),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildUserHeader() {
    final name = _user?['name'] as String? ?? 'Field Responder';
    final role = _user?['role'] as String? ?? 'CREW';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Role: $role',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckedInCard(CheckInStatus checkIn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, size: 8, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text(
                      'DRIVER SHIFT: ACTIVE',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'VEHICLE: ${checkIn.status}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            checkIn.registrationNumber,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (checkIn.checkInLocationName != null) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    checkIn.checkInLocationName!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (checkIn.checkedInAt != null) ...[
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Checked in at ${checkIn.checkedInAt!.contains('T') ? checkIn.checkedInAt!.split('T').last.substring(0, 5) : checkIn.checkedInAt}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isActionSubmitting ? null : _handleCheckOut,
              icon: const Icon(Icons.logout, size: 18, color: AppColors.danger),
              label: const Text(
                'End Shift / Check Out',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewAssignmentSection(CheckInStatus checkIn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: const [
            Icon(Icons.group_outlined, size: 20, color: AppColors.brandNavy),
            SizedBox(width: 8),
            Text(
              'CREW ASSIGNMENT',
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
          'Assign available EMT and Nurse responders to this vehicle for duty.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        CrewSlotCard(
          roleTitle: 'EMT',
          assignedMember: checkIn.currentEmt,
          onAssignTap: () => _openCrewPickerSheet('EMT', 'EMT'),
          onClearTap: () => _clearCrewSlot('EMT'),
          isSubmitting: _isActionSubmitting,
        ),
        const SizedBox(height: 12),
        CrewSlotCard(
          roleTitle: 'Nurse',
          assignedMember: checkIn.currentNurse,
          onAssignTap: () => _openCrewPickerSheet('Nurse', 'NURSE'),
          onClearTap: () => _clearCrewSlot('Nurse'),
          isSubmitting: _isActionSubmitting,
        ),
      ],
    );
  }

  Widget _buildNotCheckedInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Shift Check-In',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select your assigned vehicle to check in for duty.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Toggle button to expand/collapse vehicle list
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandNavy,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              setState(() => _isVehicleListExpanded = !_isVehicleListExpanded);
            },
            icon: Icon(
              _isVehicleListExpanded ? Icons.keyboard_arrow_up : Icons.directions_car_outlined,
              size: 20,
            ),
            label: Text(
              _isVehicleListExpanded
                  ? 'Hide vehicle list'
                  : 'Select vehicle to check in (${_vehicles.length} available)',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),

        if (_isVehicleListExpanded || _vehicles.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'AVAILABLE VEHICLES',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable vehicle list with max height 260px per spec
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: _vehicles.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No active vehicles found in agency.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _vehicles.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      final isSelected = _selectedVehicle?.id == vehicle.id;

                      return ListTile(
                        onTap: () => _onVehicleTap(vehicle),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(alpha: 0.05),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_hospital_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          vehicle.registrationNumber,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          vehicle.lastLocationName ?? 'Status: ${vehicle.status}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            vehicle.status,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
