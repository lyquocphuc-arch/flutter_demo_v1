import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/Room.dart';
import '../models/Booking.dart';

class ApiService {
  final String baseUrl = "https://6951463270e1605a1089ad60.mockapi.io";

  // --- 1. ROOMS ---
  Future<List<Room>> fetchRooms(int page, int limit) async {
    final response = await http.get(Uri.parse('$baseUrl/HotelRoom?page=$page&limit=$limit'));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Room.fromJson(item)).toList();
    } else {
      throw Exception('Không thể tải dữ liệu phòng');
    }
  }

  // Cập nhật trạng thái phòng (Available <-> Reserved)
  Future<void> updateRoomStatus(String roomId, String newStatus) async {
    final url = Uri.parse('$baseUrl/HotelRoom/$roomId');
    await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': newStatus}),
    );
  }

  // --- 2. BOOKINGS (CRUD ĐẦY ĐỦ) ---

  // A. Lấy danh sách (GET)
  Future<List<Booking>> fetchBookings() async {
    // Lưu ý: Bookings viết hoa theo MockAPI của bạn
    final response = await http.get(Uri.parse('$baseUrl/Bookings'));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Booking.fromJson(item)).toList();
    }
    return [];
  }

  // B. Tạo mới (POST)
  Future<bool> createBooking(Booking booking) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(booking.toJson()),
    );
    return response.statusCode == 201;
  }

  // C. Cập nhật / Sửa (PUT) - Mới thêm
  Future<bool> updateBooking(Booking booking) async {
    final response = await http.put(
      Uri.parse('$baseUrl/Bookings/${booking.id}'), // Gọi vào ID cụ thể
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(booking.toJson()),
    );
    return response.statusCode == 200;
  }

  // D. Xóa / Hủy (DELETE) - Mới thêm
  Future<bool> deleteBooking(String bookingId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/Bookings/$bookingId'),
    );
    return response.statusCode == 200;
  }

  // 3. Logic check trùng lịch
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
      return false;
    }
  }

  // 4. Login giả
  Future<bool> login(String username, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    return username.isNotEmpty && password.length >= 6;
  }
}