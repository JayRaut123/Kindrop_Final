class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String role;
  final String? phone;
  final String? orgName;
  final String createdAt;

  UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    this.phone,
    this.orgName,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        uid: map['uid'] ?? '',
        fullName: map['fullName'] ?? '',
        email: map['email'] ?? '',
        role: map['role'] ?? 'donor',
        phone: map['phone'],
        orgName: map['orgName'],
        createdAt: map['createdAt'] ?? '',
      );
}