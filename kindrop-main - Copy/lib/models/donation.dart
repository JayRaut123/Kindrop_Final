class Donation {
  final String id;
  final String donorId;
  final String donorName;
  final String type;
  final String category;
  final int quantity;
  final String condition;
  final String address;
  final String pickupDate;
  final String status;
  final String? orgId;
  final String? orgName;
  final String createdAt;

  Donation({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.type,
    required this.category,
    required this.quantity,
    required this.condition,
    required this.address,
    required this.pickupDate,
    required this.status,
    required this.createdAt,
    this.orgId,
    this.orgName,
  });

  factory Donation.fromMap(Map<String, dynamic> map, String id) => Donation(
        id: id,
        donorId: map['donorId'] ?? '',
        donorName: map['donorName'] ?? '',
        type: map['type'] ?? '',
        category: map['category'] ?? '',
        quantity: map['quantity'] ?? 0,
        condition: map['condition'] ?? '',
        address: map['address'] ?? '',
        pickupDate: map['pickupDate'] ?? '',
        status: map['status'] ?? 'Pending',
        orgId: map['orgId'],
        orgName: map['orgName'],
        createdAt: map['createdAt'] ?? '',
      );
}