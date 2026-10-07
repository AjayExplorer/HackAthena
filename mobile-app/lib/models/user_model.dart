class UserModel {
  final String uid;
  final String name;
  final String email;
  final String aegisId;
  final bool isOnline;
  final DateTime createdAt;
  final DateTime lastSeen;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.aegisId,
    required this.isOnline,
    required this.createdAt,
    required this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      aegisId: json['aegisId'] ?? '',
      isOnline: json['isOnline'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'aegisId': aegisId,
      'isOnline': isOnline,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
    };
  }
}
