import 'package:cloud_firestore/cloud_firestore.dart';

class AgentIdentity {
  final String agentCode;
  final String displayName;
  final String? deviceId;
  final bool deviceBindingRequired;
  final bool needsAdminApprovalForNewDevice;
  final DateTime? lastLoginAt;
  final String? lastLoginDeviceId;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final String? destructionCode;

  AgentIdentity({
    required this.agentCode,
    required this.displayName,
    this.deviceId,
    this.deviceBindingRequired = true,
    this.needsAdminApprovalForNewDevice = false,
    this.lastLoginAt,
    this.lastLoginDeviceId,
    this.isActive = true,
    this.metadata,
    this.destructionCode,
  });

  factory AgentIdentity.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AgentIdentity(
      agentCode: doc.id,
      displayName: data['displayName'] as String? ?? doc.id,
      deviceId: data['deviceId'] as String?,
      deviceBindingRequired: data['deviceBindingRequired'] as bool? ?? true,
      needsAdminApprovalForNewDevice: data['needsAdminApprovalForNewDevice'] as bool? ?? false,
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      lastLoginDeviceId: data['lastLoginDeviceId'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
      destructionCode: data['destructionCode'] as String?,
    );
  }

  factory AgentIdentity.fromJson(Map<String, dynamic> json) {
    return AgentIdentity(
      agentCode: json['agentCode'] as String,
      displayName: json['displayName'] as String,
      deviceId: json['deviceId'] as String?,
      deviceBindingRequired: json['deviceBindingRequired'] as bool,
      needsAdminApprovalForNewDevice: json['needsAdminApprovalForNewDevice'] as bool,
      lastLoginAt: json['lastLoginAt'] != null ? DateTime.parse(json['lastLoginAt']) : null,
      lastLoginDeviceId: json['lastLoginDeviceId'] as String?,
      isActive: json['isActive'] as bool,
      metadata: json['metadata'] as Map<String, dynamic>?,
      destructionCode: json['destructionCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agentCode': agentCode,
      'displayName': displayName,
      'deviceId': deviceId,
      'deviceBindingRequired': deviceBindingRequired,
      'needsAdminApprovalForNewDevice': needsAdminApprovalForNewDevice,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'lastLoginDeviceId': lastLoginDeviceId,
      'isActive': isActive,
      'metadata': metadata,
      'destructionCode': destructionCode,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'deviceId': deviceId,
      'deviceBindingRequired': deviceBindingRequired,
      'needsAdminApprovalForNewDevice': needsAdminApprovalForNewDevice,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'lastLoginDeviceId': lastLoginDeviceId,
      'isActive': isActive,
      'metadata': metadata,
      'destructionCode': destructionCode,
    };
  }

  AgentIdentity copyWith({
    String? agentCode,
    String? displayName,
    String? deviceId,
    bool? deviceBindingRequired,
    bool? needsAdminApprovalForNewDevice,
    DateTime? lastLoginAt,
    String? lastLoginDeviceId,
    bool? isActive,
    Map<String, dynamic>? metadata,
    String? destructionCode,
  }) {
    return AgentIdentity(
      agentCode: agentCode ?? this.agentCode,
      displayName: displayName ?? this.displayName,
      deviceId: deviceId ?? this.deviceId,
      deviceBindingRequired: deviceBindingRequired ?? this.deviceBindingRequired,
      needsAdminApprovalForNewDevice: needsAdminApprovalForNewDevice ?? this.needsAdminApprovalForNewDevice,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLoginDeviceId: lastLoginDeviceId ?? this.lastLoginDeviceId,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      destructionCode: destructionCode ?? this.destructionCode,
    );
  }
}
