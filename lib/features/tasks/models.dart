/// Data models for active tasks, incidents, stops, and handover vehicles.
library;

class TaskMember {
  const TaskMember({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;

  factory TaskMember.fromJson(Map<String, dynamic> json) => TaskMember(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
      );
}

class TaskVehicle {
  const TaskVehicle({required this.id, required this.registrationNumber});

  final String id;
  final String registrationNumber;

  factory TaskVehicle.fromJson(Map<String, dynamic> json) => TaskVehicle(
        id: json['id'] as String,
        registrationNumber: json['registrationNumber'] as String,
      );
}

class TaskIncident {
  const TaskIncident({
    required this.id,
    required this.caseNumber,
    required this.chiefComplaint,
    required this.locationName,
    required this.subCounty,
    this.lat,
    this.lng,
    this.patientName,
    this.patientAge,
    this.patientGender,
    this.patientContact,
    this.nextOfKin,
    this.nextOfKinPhone,
    this.alertNature,
    this.alertNatureDetail,
    this.preHospitalManagement,
    this.dispatcherChallenges,
    this.vitals,
  });

  final String id;
  final String caseNumber;
  final String chiefComplaint;
  final String locationName;
  final String subCounty;
  final double? lat;
  final double? lng;
  final String? patientName;
  final String? patientAge;
  final String? patientGender;
  final String? patientContact;
  final String? nextOfKin;
  final String? nextOfKinPhone;
  final String? alertNature;
  final String? alertNatureDetail;
  final String? preHospitalManagement;
  final String? dispatcherChallenges;
  final Map<String, dynamic>? vitals;

  factory TaskIncident.fromJson(Map<String, dynamic> json) => TaskIncident(
        id: json['id'] as String,
        caseNumber: json['caseNumber'] as String,
        chiefComplaint: json['chiefComplaint'] as String,
        locationName: json['locationName'] as String,
        subCounty: json['subCounty'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        patientName: json['patientName'] as String?,
        patientAge: json['patientAge'] as String?,
        patientGender: json['patientGender'] as String?,
        patientContact: json['patientContact'] as String?,
        nextOfKin: json['nextOfKin'] as String?,
        nextOfKinPhone: json['nextOfKinPhone'] as String?,
        alertNature: json['alertNature'] as String?,
        alertNatureDetail: json['alertNatureDetail'] as String?,
        preHospitalManagement: json['preHospitalManagement'] as String?,
        dispatcherChallenges: json['dispatcherChallenges'] as String?,
        vitals: json['vitals'] != null
            ? Map<String, dynamic>.from(json['vitals'] as Map)
            : null,
      );
}

class ActiveTask {
  const ActiveTask({
    required this.id,
    required this.status,
    required this.incident,
    required this.vehicle,
    required this.driver,
    this.emt,
    this.nurse,
    this.handoverVitals,
    this.receivedAt,
    this.acceptedAt,
    this.sceneArrivalAt,
    this.patientPickAt,
    this.facilityArrivalAt,
    this.completedAt,
  });

  final String id;
  final String status;
  final TaskIncident incident;
  final TaskVehicle vehicle;
  final TaskMember driver;
  final TaskMember? emt;
  final TaskMember? nurse;
  final Map<String, dynamic>? handoverVitals;
  final String? receivedAt;
  final String? acceptedAt;
  final String? sceneArrivalAt;
  final String? patientPickAt;
  final String? facilityArrivalAt;
  final String? completedAt;

  factory ActiveTask.fromJson(Map<String, dynamic> json) => ActiveTask(
        id: json['id'] as String,
        status: json['status'] as String,
        incident:
            TaskIncident.fromJson(json['incident'] as Map<String, dynamic>),
        vehicle:
            TaskVehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
        driver:
            TaskMember.fromJson(json['driver'] as Map<String, dynamic>),
        emt: json['emt'] != null
            ? TaskMember.fromJson(json['emt'] as Map<String, dynamic>)
            : null,
        nurse: json['nurse'] != null
            ? TaskMember.fromJson(json['nurse'] as Map<String, dynamic>)
            : null,
        handoverVitals: json['handoverVitals'] != null
            ? Map<String, dynamic>.from(json['handoverVitals'] as Map)
            : null,
        receivedAt: json['receivedAt'] as String?,
        acceptedAt: json['acceptedAt'] as String?,
        sceneArrivalAt: json['sceneArrivalAt'] as String?,
        patientPickAt: json['patientPickAt'] as String?,
        facilityArrivalAt: json['facilityArrivalAt'] as String?,
        completedAt: json['completedAt'] as String?,
      );
}

class TaskStop {
  const TaskStop({
    required this.id,
    required this.taskId,
    required this.name,
    this.facilityId,
    this.lat,
    this.lng,
    this.note,
    required this.sequence,
    this.arrivedAt,
    this.createdAt,
  });

  final String id;
  final String taskId;
  final String name;
  final String? facilityId;
  final double? lat;
  final double? lng;
  final String? note;
  final int sequence;
  final String? arrivedAt;
  final String? createdAt;

  bool get isArrived => arrivedAt != null && arrivedAt!.isNotEmpty;

  factory TaskStop.fromJson(Map<String, dynamic> json) => TaskStop(
        id: json['id'] as String,
        taskId: json['taskId'] as String,
        name: json['name'] as String,
        facilityId: json['facilityId'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        note: json['note'] as String?,
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        arrivedAt: json['arrivedAt'] as String?,
        createdAt: json['createdAt'] as String?,
      );
}

class HandoverVehicle {
  const HandoverVehicle({
    required this.id,
    required this.registrationNumber,
    this.driverName,
  });

  final String id;
  final String registrationNumber;
  final String? driverName;

  factory HandoverVehicle.fromJson(Map<String, dynamic> json) {
    final driver = json['currentDriver'] as Map<String, dynamic>?;
    return HandoverVehicle(
      id: json['id'] as String,
      registrationNumber: json['registrationNumber'] as String,
      driverName: driver?['name'] as String?,
    );
  }
}
