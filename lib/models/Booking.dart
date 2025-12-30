// lib/models/Booking.dart
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
      roomId: json['roomId']?.toString() ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',

      checkIn: json['checkIn'] != null
          ? DateTime.tryParse(json['checkIn'].toString()) ?? DateTime.now()
          : DateTime.now(),

      checkOut: json['checkOut'] != null
          ? DateTime.tryParse(json['checkOut'].toString()) ?? DateTime.now()
          : DateTime.now(),
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