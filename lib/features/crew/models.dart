class CrewMemberSimple {
  const CrewMemberSimple({
    required this.id,
    required this.name,
    this.phone,
  });

  final String id;
  final String name;
  final String? phone;

  factory CrewMemberSimple.fromJson(Map<String, dynamic> json) {
    return CrewMemberSimple(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
    );
  }
}

class CrewMember {
  const CrewMember({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
  });

  final String id;
  final String name;
  final String role;
  final String? phone;

  factory CrewMember.fromJson(Map<String, dynamic> json) {
    return CrewMember(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
    );
  }
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.registrationNumber,
    required this.status,
    required this.isActive,
    this.lastLocationName,
    this.currentDriver,
    this.currentEmt,
    this.currentNurse,
    this.checkedInAt,
  });

  final String id;
  final String registrationNumber;
  final String status;
  final bool isActive;
  final String? lastLocationName;
  final CrewMemberSimple? currentDriver;
  final CrewMemberSimple? currentEmt;
  final CrewMemberSimple? currentNurse;
  final String? checkedInAt;

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      registrationNumber: json['registrationNumber'] as String,
      status: (json['status'] as String?) ?? 'READY',
      isActive: (json['isActive'] as bool?) ?? true,
      lastLocationName: (json['lastLocationName'] ?? json['checkInLocationName']) as String?,
      currentDriver: json['currentDriver'] != null
          ? CrewMemberSimple.fromJson(json['currentDriver'] as Map<String, dynamic>)
          : null,
      currentEmt: json['currentEmt'] != null
          ? CrewMemberSimple.fromJson(json['currentEmt'] as Map<String, dynamic>)
          : null,
      currentNurse: json['currentNurse'] != null
          ? CrewMemberSimple.fromJson(json['currentNurse'] as Map<String, dynamic>)
          : null,
      checkedInAt: json['checkedInAt'] as String?,
    );
  }
}

class CheckInStatus {
  const CheckInStatus({
    required this.vehicleId,
    required this.registrationNumber,
    required this.status,
    this.checkInLocationName,
    this.checkInLat,
    this.checkInLng,
    this.checkedInAt,
    this.currentDriver,
    this.currentEmt,
    this.currentNurse,
  });

  final String vehicleId;
  final String registrationNumber;
  final String status;
  final String? checkInLocationName;
  final double? checkInLat;
  final double? checkInLng;
  final String? checkedInAt;
  final CrewMemberSimple? currentDriver;
  final CrewMemberSimple? currentEmt;
  final CrewMemberSimple? currentNurse;

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    return CheckInStatus(
      vehicleId: (json['vehicleId'] ?? json['id']) as String,
      registrationNumber: json['registrationNumber'] as String,
      status: (json['status'] as String?) ?? 'READY',
      checkInLocationName: (json['checkInLocationName'] ?? json['lastLocationName']) as String?,
      checkInLat: (json['checkInLat'] as num?)?.toDouble() ?? (json['lastLat'] as num?)?.toDouble(),
      checkInLng: (json['checkInLng'] as num?)?.toDouble() ?? (json['lastLng'] as num?)?.toDouble(),
      checkedInAt: json['checkedInAt'] as String?,
      currentDriver: json['currentDriver'] != null
          ? CrewMemberSimple.fromJson(json['currentDriver'] as Map<String, dynamic>)
          : null,
      currentEmt: json['currentEmt'] != null
          ? CrewMemberSimple.fromJson(json['currentEmt'] as Map<String, dynamic>)
          : null,
      currentNurse: json['currentNurse'] != null
          ? CrewMemberSimple.fromJson(json['currentNurse'] as Map<String, dynamic>)
          : null,
    );
  }
}

