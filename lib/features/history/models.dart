class HistoryTask {
  const HistoryTask({
    required this.id,
    required this.status,
    this.completedAt,
    required this.receivedAt,
    required this.caseNumber,
    required this.chiefComplaint,
    required this.locationName,
    required this.subCounty,
    this.vehicleReg,
    this.pcrCount = 0,
    this.lastPcrAt,
  });

  final String id;
  final String status;
  final String? completedAt;
  final String receivedAt;
  final String caseNumber;
  final String chiefComplaint;
  final String locationName;
  final String subCounty;
  final String? vehicleReg;
  final int pcrCount;
  final String? lastPcrAt;

  factory HistoryTask.fromJson(Map<String, dynamic> json) {
    final incident = json['incident'] as Map<String, dynamic>? ?? {};
    final vehicle = json['vehicle'] as Map<String, dynamic>? ?? {};
    return HistoryTask(
      id: json['id'] as String,
      status: json['status'] as String,
      completedAt: json['completedAt'] as String?,
      receivedAt: json['receivedAt'] as String? ?? '',
      caseNumber: incident['caseNumber'] as String? ?? 'N/A',
      chiefComplaint: incident['chiefComplaint'] as String? ?? 'No complaint recorded',
      locationName: incident['locationName'] as String? ?? '',
      subCounty: incident['subCounty'] as String? ?? '',
      vehicleReg: vehicle['registrationNumber'] as String?,
      pcrCount: (json['pcrCount'] as num?)?.toInt() ?? 0,
      lastPcrAt: json['lastPcrAt'] as String?,
    );
  }
}

class PcrReport {
  const PcrReport({
    required this.id,
    required this.taskId,
    required this.mimeType,
    required this.originalName,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String mimeType;
  final String originalName;
  final String? note;
  final String createdAt;

  bool get isImage {
    final lowerMime = mimeType.toLowerCase();
    final lowerName = originalName.toLowerCase();
    return lowerMime.startsWith('image/') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp');
  }

  factory PcrReport.fromJson(Map<String, dynamic> json) => PcrReport(
        id: json['id'] as String,
        taskId: json['taskId'] as String,
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        originalName: json['originalName'] as String? ?? 'PCR_Report',
        note: json['note'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );
}
