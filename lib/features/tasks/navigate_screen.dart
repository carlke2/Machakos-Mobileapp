import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobileapp/core/services/directions_service.dart';
import 'package:mobileapp/core/theme/app_colors.dart';

class NavigateScreen extends StatefulWidget {
  const NavigateScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationName,
  });

  final double destinationLat;
  final double destinationLng;
  final String destinationName;

  @override
  State<NavigateScreen> createState() => _NavigateScreenState();
}

class _NavigateScreenState extends State<NavigateScreen> {
  final DirectionsService _directionsService = DirectionsService();
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStreamSubscription;

  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _distanceText;
  String? _durationText;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initNavigation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initNavigation() async {
    try {
      final permStatus = await Permission.location.request();
      if (!permStatus.isGranted) {
        debugPrint('[NavigateScreen] Location permission denied: $permStatus');
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint('[NavigateScreen] Could not get current position: $e');
      }

      if (pos != null) {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      }

      final destLatLng = LatLng(widget.destinationLat, widget.destinationLng);
      _updateMarkers(_currentPosition, destLatLng);

      if (_currentPosition != null) {
        await _fetchRoute(_currentPosition!, destLatLng);
      } else {
        setState(() => _isLoading = false);
      }

      _startLocationStream(destLatLng);
    } catch (e, st) {
      debugPrint('[NavigateScreen] Init navigation error: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize navigation map';
        });
      }
    }
  }

  void _startLocationStream(LatLng destLatLng) {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      final newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = newPos;
          _updateMarkers(newPos, destLatLng);
        });
      }
    }, onError: (Object e) {
      debugPrint('[NavigateScreen] Location stream error: $e');
    });
  }

  void _updateMarkers(LatLng? current, LatLng dest) {
    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: dest,
        infoWindow: InfoWindow(
          title: widget.destinationName,
          snippet: 'Incident Location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    if (current != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: current,
          infoWindow: const InfoWindow(
            title: 'My Position',
            snippet: 'Current Ambulance Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    _markers = markers;
  }

  Future<void> _fetchRoute(LatLng origin, LatLng dest) async {
    final result = await _directionsService.getDirections(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destLat: dest.latitude,
      destLng: dest.longitude,
    );

    if (!mounted) return;

    if (result.errorMessage != null) {
      debugPrint('[NavigateScreen] Directions error: ${result.errorMessage}');
    }

    setState(() {
      _isLoading = false;
      _distanceText = result.distanceText;
      _durationText = result.durationText;
      _errorMessage = result.errorMessage;

      if (result.points.isNotEmpty) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: result.points,
            color: AppColors.primary,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      }
    });

    _fitBounds(origin, dest, routePoints: result.points);
  }

  void _fitBounds(LatLng origin, LatLng dest, {List<LatLng>? routePoints}) {
    if (_mapController == null) return;

    final pointsToFit = (routePoints != null && routePoints.isNotEmpty)
        ? routePoints
        : [origin, dest];

    double minLat = pointsToFit.first.latitude;
    double maxLat = pointsToFit.first.latitude;
    double minLng = pointsToFit.first.longitude;
    double maxLng = pointsToFit.first.longitude;

    for (final p in pointsToFit) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destLatLng = LatLng(widget.destinationLat, widget.destinationLng);
    final initialTarget = _currentPosition ?? destLatLng;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Navigation — ${widget.destinationName}',
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            onPressed: () {
              if (_currentPosition != null && _mapController != null) {
                _fitBounds(_currentPosition!, destLatLng,
                    routePoints: _polylines.isNotEmpty
                        ? _polylines.first.points
                        : null);
              }
            },
            tooltip: 'Center Route',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Embedded Google Map ─────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                _fitBounds(_currentPosition!, destLatLng,
                    routePoints: _polylines.isNotEmpty
                        ? _polylines.first.points
                        : null);
              }
            },
          ),

          // ── Loading Indicator Overlay ───────────────────────────────────────
          if (_isLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Calculating optimal driving route...',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Error Banner Overlay ────────────────────────────────────────────
          if (_errorMessage != null && !_isLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom Destination & ETA Panel ──────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_hospital_outlined,
                          color: AppColors.danger,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'INCIDENT DESTINATION',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.destinationName,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (_distanceText != null || _durationText != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (_durationText != null)
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                _durationText!,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        if (_distanceText != null)
                          Row(
                            children: [
                              const Icon(Icons.route_outlined,
                                  color: AppColors.textSecondary, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                _distanceText!,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
