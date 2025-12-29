class Room {
  final String id;
  final int roomNumber;
  final String type;
  final String bedType;
  final double price;
  final String status;
  final String image;

  Room({
    required this.id,
    required this.roomNumber,
    required this.type,
    required this.bedType,
    required this.price,
    required this.status,
    required this.image,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? "",
      roomNumber: int.tryParse(json['room_number'].toString()) ?? 0,
      type: json['type'] ?? "Standard",
      bedType: json['bed_type'] ?? "Single Bed",
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      status: json['status'] ?? "Available",
      image: json['image'] ?? "https://via.placeholder.com/300",
    );
  }
}