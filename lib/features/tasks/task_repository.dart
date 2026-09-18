import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'models.dart';

/// Task management API repository.
class TaskRepository {
  const TaskRepository();

  Future<ActiveTask?> getActiveTask() async {
    final response = await ApiClient.instance.get('/tasks/active');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data == null) return null;
    return ActiveTask.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    await ApiClient.instance.patch(
      '/tasks/$taskId/status',
      data: {'status': newStatus},
    );
  }

  Future<void> submitPatientData({
    required String taskId,
    required String preHospitalManagement,
    String? dispatcherChallenges,
    Map<String, dynamic>? handoverVitals,
  }) async {
    await ApiClient.instance.post(
      '/tasks/$taskId/patient-data',
      data: {
        'preHospitalManagement': preHospitalManagement,
        if (dispatcherChallenges != null && dispatcherChallenges.trim().isNotEmpty)
          'dispatcherChallenges': dispatcherChallenges.trim(),
        if (handoverVitals != null && handoverVitals.isNotEmpty)
          'handoverVitals': handoverVitals,
      },
    );
  }

  Future<void> submitPcr({
    required String taskId,
    required File file,
    String? note,
  }) async {
    final exists = file.existsSync();
    final fileSize = exists ? file.lengthSync() : 0;
    debugPrint(
        '[TaskRepository] submitPcr -> taskId: $taskId, filePath: ${file.path}, exists: $exists, bytes: $fileSize');

    if (!exists) {
      throw const ApiException('Selected file does not exist on disk');
    }

    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });

    await ApiClient.instance.post(
      '/tasks/$taskId/patient-care-report',
      data: formData,
    );
  }

  Future<List<TaskStop>> getStops(String taskId) async {
    final response = await ApiClient.instance.get('/tasks/$taskId/stops');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((item) => TaskStop.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TaskStop> addStop({
    required String taskId,
    required String name,
    String? note,
    double? lat,
    double? lng,
    String? facilityId,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'lat': ?lat,
      'lng': ?lng,
      if (facilityId != null && facilityId.trim().isNotEmpty)
        'facilityId': facilityId.trim(),
    };

    final response = await ApiClient.instance.post(
      '/tasks/$taskId/stops',
      data: payload,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return TaskStop.fromJson(data);
  }

  Future<TaskStop> markStopArrived({
    required String taskId,
    required String stopId,
  }) async {
    final response = await ApiClient.instance.patch(
      '/tasks/$taskId/stops/$stopId/arrived',
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return TaskStop.fromJson(data);
  }

  Future<void> reassignTask(
    String taskId, {
    required String reason,
    String? newVehicleId,
    bool? autoAssign,
  }) async {
    final payload = <String, dynamic>{
      'reason': reason,
      'newVehicleId': ?newVehicleId,
      if (autoAssign == true) 'autoAssign': true,
    };
    await ApiClient.instance.post('/tasks/$taskId/reassign', data: payload);
  }

  Future<List<HandoverVehicle>> getAvailableForHandover(
    String excludeVehicleId,
  ) async {
    final response = await ApiClient.instance.get(
      '/fleet/available-for-handover',
      queryParameters: {'excludeVehicleId': excludeVehicleId},
    );
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((item) =>
            HandoverVehicle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> closeCase(String incidentId, String reason) async {
    await ApiClient.instance.post(
      '/incidents/$incidentId/close',
      data: {'reason': reason},
    );
  }
}
