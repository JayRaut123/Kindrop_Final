class Need {
  final String id;
  final String orgId;
  final String orgName;
  final String item;
  final int quantity;
  final String createdAt;

  Need({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.item,
    required this.quantity,
    required this.createdAt,
  });

  factory Need.fromMap(Map<String, dynamic> map, String id) => Need(
        id: id,
        orgId: map['orgId'] ?? '',
        orgName: map['orgName'] ?? '',
        item: map['item'] ?? '',
        quantity: map['quantity'] ?? 0,
        createdAt: map['createdAt'] ?? '',
      );
}