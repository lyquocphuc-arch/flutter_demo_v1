class Booking {
  final String id;
  final String roomId;
  final String customerName;
  final String customerPhone;
  final DateTime checkIn;
  final DateTime checkOut;

  Booking({
    required this.id,
    required this.roomId,
    required this.customerName,
    required this.customerPhone,
    required this.checkIn,
    required this.checkOut,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id']?.toString() ?? '',
      roomId: json['roomId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      checkIn: DateTime.parse(json['checkIn']),
      checkOut: DateTime.parse(json['checkOut']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "roomId": roomId,
      "customerName": customerName,
      "customerPhone": customerPhone,
      "checkIn": checkIn.toIso8601String(),
      "checkOut": checkOut.toIso8601String(),
    };
  }
}