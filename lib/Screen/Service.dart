import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/Room.dart';
import '../models/Booking.dart';

class ApiService {
  final String baseUrl = "https://6951463270e1605a1089ad60.mockapi.io";

  Future<List<Room>> fetchRooms(int page, int limit) async {
    // Gọi vào endpoint /HotelRoom
    final response = await http.get(
      Uri.parse('$baseUrl/HotelRoom?page=$page&limit=$limit'),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Room> rooms = body.map((dynamic item) => Room.fromJson(item)).toList();
      return rooms;
    } else {
      throw Exception('Không thể tải dữ liệu phòng');
    }
  }

  Future<List<Booking>> fetchBookings() async {
    final response = await http.get(Uri.parse('$baseUrl/bookings'));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Booking.fromJson(item)).toList();
    } else {
      return [];
    }
  }

  // Tạo Booking mới (Chỉ gọi khi đã check availability OK)
  Future<bool> createBooking(Booking booking) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(booking.toJson()),
    );
    return response.statusCode == 201;
  }
  Future<bool> checkAvailability(String roomId, DateTime start, DateTime end) async {
    try {
      List<Booking> allBookings = await fetchBookings();

      var roomBookings = allBookings.where((b) => b.roomId == roomId).toList();

      for (var b in roomBookings) {
        if (start.isBefore(b.checkOut) && end.isAfter(b.checkIn)) {
          return false;
        }
      }
      return true;
    } catch (e) {
      print("Lỗi check availability: $e");
      return false;
    }
  }

  // --- 4. AUTH (Giữ nguyên) ---
  Future<bool> login(String username, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    if (username.isNotEmpty && password.length >= 6) {
      return true;
    }
    return false;
  }
}