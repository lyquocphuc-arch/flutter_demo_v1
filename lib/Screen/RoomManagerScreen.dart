import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Room.dart';
import '../models/Booking.dart';
import 'Service.dart';

class RoomManagerScreen extends StatefulWidget {
  const RoomManagerScreen({super.key});
  @override
  State<RoomManagerScreen> createState() => _RoomManagerScreenState();
}

class _RoomManagerScreenState extends State<RoomManagerScreen> {
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  List<Room> _allRooms = [];
  List<Room> _filteredRooms = [];
  bool _isLoading = true;
  bool _showActiveOnly = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    final rooms = await _apiService.fetchRooms();
    if(mounted) {
      setState(() {
        _allRooms = rooms;
        _isLoading = false;
      });
      _filterRooms();
    }
  }

  void _filterRooms() {
    setState(() {
      if (_showActiveOnly) {
        _filteredRooms = _allRooms.where((r) => r.isActive).toList();
      } else {
        _filteredRooms = List.from(_allRooms);
      }
      _filteredRooms.sort((a,b) => a.roomNumber.compareTo(b.roomNumber));
    });
  }

  Future<void> _toggleRoomStatus(Room room) async {
    if (room.isActive) {
      final bookings = await _apiService.fetchBookings();
      bool hasFutureBooking = bookings.any((b) =>
      b.roomId == room.id &&
          (b.status == BookingStatus.Confirmed || b.status == BookingStatus.CheckedIn) &&
          b.checkOut.isAfter(DateTime.now())
      );
      if(!mounted) return;
      if (hasFutureBooking) {
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Không thể ẩn phòng!"),
          content: const Text("Phòng này đang có khách hoặc có lịch đặt sắp tới."),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng"))],
        ));
        return;
      }
      bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận ẩn phòng"),
        content: const Text("Phòng sẽ bị ẩn khỏi sơ đồ."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Đồng ý"))
        ],
      )) ?? false;
      if (!confirm) return;
    }

    Room updated = Room(
        id: room.id, roomNumber: room.roomNumber, type: room.type, bedType: room.bedType, price: room.price, image: room.image,
        isActive: !room.isActive
    );
    await _apiService.updateRoom(updated);
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý phòng"), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text("Chỉ hiện phòng đang hoạt động"),
            value: _showActiveOnly,
            onChanged: (val) {
              setState(() => _showActiveOnly = val);
              _filterRooms();
            },
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _filteredRooms.length,
              itemBuilder: (ctx, i) {
                final room = _filteredRooms[i];
                return Card(
                  color: room.isActive ? Colors.white : Colors.grey.shade200,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(backgroundImage: NetworkImage(room.image)),
                    title: Text("P.${room.roomNumber} - ${room.type}", style: TextStyle(color: room.isActive ? Colors.black : Colors.grey)),
                    subtitle: Text(currencyFormatter.format(room.price)),
                    trailing: Switch(
                      value: room.isActive,
                      activeThumbColor: Colors.green,
                      onChanged: (val) => _toggleRoomStatus(room),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}