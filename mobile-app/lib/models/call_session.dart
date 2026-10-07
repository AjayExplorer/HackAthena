class CallSession {
  final String callId;
  final String callerId;
  final String recipientId;
  final String status;
  final double threatScore;
  final String? counterAgent;
  final DateTime createdAt;

  CallSession({
    required this.callId,
    required this.callerId,
    required this.recipientId,
    required this.status,
    required this.threatScore,
    this.counterAgent,
    required this.createdAt,
  });

  factory CallSession.fromJson(Map<String, dynamic> json, String id) {
    return CallSession(
      callId: id,
      callerId: json['callerId'] ?? '',
      recipientId: json['recipientId'] ?? '',
      status: json['status'] ?? 'IDLE',
      threatScore: (json['threatScore'] ?? 0.0).toDouble(),
      counterAgent: json['counterAgent'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callerId': callerId,
      'recipientId': recipientId,
      'status': status,
      'threatScore': threatScore,
      'counterAgent': counterAgent,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
