enum BookingStatus { Confirmed, CheckedIn, CheckedOut, Cancelled }

class Booking {
  final String id;
  final String roomId;
  final String customerName;
  final String customerPhone;
  final DateTime checkIn;
  final DateTime checkOut;
  final BookingStatus status;
  final double totalPrice;

  Booking({
    required this.id,
    required this.roomId,
    required this.customerName,
    required this.customerPhone,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    this.totalPrice = 0.0,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    BookingStatus parseStatus(String? val) {
      return BookingStatus.values.firstWhere(
            (e) => e.name == val,
        orElse: () => BookingStatus.Confirmed,
      );
    }

    return Booking(
      id: json['id']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      customerName: json['customerName'] ?? 'Guest',
      customerPhone: json['customerPhone']?.toString() ?? '',
      checkIn: json['checkIn'] != null ? DateTime.parse(json['checkIn']) : DateTime.now(),
      checkOut: json['checkOut'] != null ? DateTime.parse(json['checkOut']) : DateTime.now(),
      status: parseStatus(json['status']),
      totalPrice: double.tryParse(json['totalPrice']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "roomId": roomId,
      "customerName": customerName,
      "customerPhone": customerPhone,
      "checkIn": checkIn.toIso8601String(),
      "checkOut": checkOut.toIso8601String(),
      "status": status.toString().split('.').last,
      "totalPrice": totalPrice,
    };
  }
}