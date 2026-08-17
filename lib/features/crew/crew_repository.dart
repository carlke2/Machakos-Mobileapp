import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'models.dart';

/// Repository for vehicle check-in and crew management API calls.
class CrewRepository {
  const CrewRepository();

  Future<List<Vehicle>> getVehicles() async {
    final response = await ApiClient.instance.get('/fleet/vehicles');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;

    return data
        .map((item) => Vehicle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CheckInStatus?> getMyCheckIn() async {
    final response = await ApiClient.instance.get('/fleet/my-checkin');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'];

    if (data == null) return null;
    return CheckInStatus.fromJson(data as Map<String, dynamic>);
  }

  Future<CheckInStatus> checkIn({
    required String vehicleId,
    required File selfieFile,
    required double lat,
    required double lng,
    String? locationName,
  }) async {
    final formData = FormData();

    formData.fields.add(MapEntry('lat', lat.toString()));
    formData.fields.add(MapEntry('lng', lng.toString()));
    if (locationName != null && locationName.trim().isNotEmpty) {
      formData.fields.add(MapEntry('locationName', locationName.trim()));
    }

    final fileName = selfieFile.path.split(Platform.pathSeparator).last;
    formData.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(
          selfieFile.path,
          filename: fileName,
        ),
      ),
    );

    final response = await ApiClient.instance.post(
      '/fleet/$vehicleId/checkin',
      data: formData,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return CheckInStatus.fromJson(data);
  }

  Future<void> checkOut(String vehicleId) async {
    await ApiClient.instance.delete('/fleet/$vehicleId/checkin');
  }

  Future<List<CrewMember>> getCrewMembers() async {
    final response = await ApiClient.instance.get('/fleet/crew-members');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;

    return data
        .map((item) => CrewMember.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CheckInStatus> assignCrew(
    String vehicleId, {
    Object? emtId = _sentinel,
    Object? nurseId = _sentinel,
  }) async {
    final payload = <String, dynamic>{};
    if (!identical(emtId, _sentinel)) {
      payload['emtId'] = emtId;
    }
    if (!identical(nurseId, _sentinel)) {
      payload['nurseId'] = nurseId;
    }

    final response = await ApiClient.instance.post(
      '/fleet/$vehicleId/crew',
      data: payload,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return CheckInStatus.fromJson(data);
  }
}

const _sentinel = Object();
