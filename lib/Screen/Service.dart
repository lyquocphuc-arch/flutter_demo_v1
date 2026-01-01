import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/Room.dart';
import '../models/Booking.dart';

class ApiService {
  final String baseUrl = "https://6951463270e1605a1089ad60.mockapi.io";

  Future<bool> login(String username, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    return username.isNotEmpty && password.length >= 6;
  }

  Future<List<Room>> fetchRooms() async {
    final response = await http.get(Uri.parse('$baseUrl/HotelRoom'));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Room.fromJson(item)).toList();
    }
    return [];
  }

  Future<Room?> fetchRoomById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/HotelRoom/$id'));
      if (response.statusCode == 200) {
        return Room.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<bool> createRoom(Room room) async {
    final response = await http.post(
      Uri.parse('$baseUrl/HotelRoom'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(room.toJson()),
    );
    return response.statusCode == 201;
  }

  Future<bool> updateRoom(Room room) async {
    final response = await http.put(
      Uri.parse('$baseUrl/HotelRoom/${room.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(room.toJson()),
    );
    return response.statusCode == 200;
  }

  Future<List<Booking>> fetchBookings() async {
    final response = await http.get(Uri.parse('$baseUrl/Bookings'));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Booking.fromJson(item)).toList();
    }
    return [];
  }

  Future<bool> createBooking(Booking booking) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(booking.toJson()),
    );
    return response.statusCode == 201;
  }

  Future<bool> updateBookingStatus(Booking booking, BookingStatus newStatus, {double? totalPrice}) async {
    Map<String, dynamic> data = {
      'status': newStatus.toString().split('.').last,
    };
    if (totalPrice != null) {
      data['totalPrice'] = totalPrice;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/Bookings/${booking.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }

  Future<bool> updateBookingInfo(Booking booking) async {
    final response = await http.put(
      Uri.parse('$baseUrl/Bookings/${booking.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(booking.toJson()),
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteBooking(String bookingId) async {
    final response = await http.delete(Uri.parse('$baseUrl/Bookings/$bookingId'));
    return response.statusCode == 200;
  }

  Future<bool> checkAvailability(String roomId, DateTime start, DateTime end, {String? excludeBookingId}) async {
    try {
      List<Booking> allBookings = await fetchBookings();
      var roomBookings = allBookings.where((b) =>
      b.roomId == roomId &&
          b.status != BookingStatus.Cancelled &&
          b.status != BookingStatus.CheckedOut
      ).toList();

      for (var b in roomBookings) {
        if (excludeBookingId != null && b.id == excludeBookingId) continue;

        if (start.isBefore(b.checkOut) && end.isAfter(b.checkIn)) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  double calculateTotalPrice(double roomPrice, DateTime checkIn, DateTime checkOut) {
    int minutes = checkOut.difference(checkIn).inMinutes;
    if (minutes <= 0) return 0;
    int hours = (minutes / 60).ceil();
    if (hours < 1) hours = 1;
    double price = (roomPrice / 24 * hours) + 30000 - ((hours ~/ 24) * roomPrice * 0.1);
    return price > 0 ? price.roundToDouble() : 0;
  }

  double calculateLatePenalty(double roomPrice, DateTime scheduledCheckOut) {
    DateTime now = DateTime.now();
    if (now.isAfter(scheduledCheckOut)) {
      int lateMinutes = now.difference(scheduledCheckOut).inMinutes;
      if (lateMinutes > 15) {
        int lateHours = (lateMinutes / 60).ceil();
        double hourlyPrice = roomPrice / 24;
        double penalty = lateHours * hourlyPrice * 1.5;
        return penalty.roundToDouble();
      }
    }
    return 0;
  }
}