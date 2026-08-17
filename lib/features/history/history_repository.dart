import 'package:mobileapp/core/network/api_client.dart';
import 'models.dart';

class HistoryRepository {
  const HistoryRepository();

  Future<({List<HistoryTask> tasks, int totalPages, int total})> getTaskHistory({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await ApiClient.instance.get(
      '/tasks/history',
      queryParameters: {'page': page, 'limit': limit},
    );

    final body = response.data as Map<String, dynamic>;
    final dataList = body['data'] as List<dynamic>;
    final meta = body['meta'] as Map<String, dynamic>? ?? {};

    final tasks = dataList
        .map((item) => HistoryTask.fromJson(item as Map<String, dynamic>))
        .toList();

    return (
      tasks: tasks,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? tasks.length,
    );
  }

  Future<List<PcrReport>> getPcrReports(String taskId) async {
    final response = await ApiClient.instance.get(
      '/tasks/$taskId/patient-care-reports',
    );

    final body = response.data as Map<String, dynamic>;
    final dataList = body['data'] as List<dynamic>;

    return dataList
        .map((item) => PcrReport.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  String getPcrFileUrl(String taskId, String reportId) {
    return '${ApiClient.instance.baseUrl}/tasks/$taskId/patient-care-reports/$reportId/file';
  }
}
