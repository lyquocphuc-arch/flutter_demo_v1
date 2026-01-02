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
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
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
    if (mounted) {
      setState(() {
        _allRooms = rooms;
        _isLoading = false;
      });
      _filterRooms();
    }
  }

  void _filterRooms() {
    setState(() {
      _filteredRooms = _showActiveOnly
          ? _allRooms.where((r) => r.isActive).toList()
          : List.from(_allRooms);
      _filteredRooms.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
    });
  }

  void _editRoom(Room room) {
    final numCtrl = TextEditingController(text: room.roomNumber.toString());
    final priceCtrl = TextEditingController(text: room.price.toStringAsFixed(0));
    String selectedType = room.type;
    String selectedBed = room.bedType;

    final List<String> typeItems = ['Standard', 'VIP', 'Luxury'];
    if (!typeItems.contains(selectedType)) {
      typeItems.add(selectedType);
    }

    final List<String> bedItems = ['Single Bed', 'Double Bed'];
    if (!bedItems.contains(selectedBed)) {
      bedItems.add(selectedBed);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Chỉnh sửa P.${room.roomNumber}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numCtrl,
                  decoration: const InputDecoration(labelText: "Số phòng"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: "Giá phòng (24h)"),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: typeItems.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                  decoration: const InputDecoration(labelText: "Loại phòng"),
                ),
                DropdownButtonFormField<String>(
                  value: selectedBed,
                  items: bedItems.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (v) => setDialogState(() => selectedBed = v!),
                  decoration: const InputDecoration(labelText: "Loại giường"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
            ElevatedButton(
              onPressed: () async {
                Room updated = Room(
                  id: room.id,
                  roomNumber: int.tryParse(numCtrl.text) ?? room.roomNumber,
                  type: selectedType,
                  bedType: selectedBed,
                  price: double.tryParse(priceCtrl.text) ?? room.price,
                  image: room.image,
                  isActive: room.isActive,
                );
                if (await _apiService.updateRoom(updated)) {
                  Navigator.pop(ctx);
                  _loadRooms();
                }
              },
              child: const Text("Cập nhật"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRoomStatus(Room room) async {
    if (room.isActive) {
      final bookings = await _apiService.fetchBookings();
      bool hasActive = bookings.any((b) => b.roomId == room.id && (b.status == BookingStatus.Confirmed || b.status == BookingStatus.CheckedIn));
      if (hasActive && mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                title: const Text("Lỗi"),
                content: const Text("Phòng đang có đơn đặt."),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng"))]
            )
        );
        return;
      }
    }
    Room updated = Room(
        id: room.id,
        roomNumber: room.roomNumber,
        type: room.type,
        bedType: room.bedType,
        price: room.price,
        image: room.image,
        isActive: !room.isActive
    );
    if (await _apiService.updateRoom(updated)) _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Quản lý phòng"),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white
      ),
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
                    onTap: () => _editRoom(room),
                    leading: CircleAvatar(backgroundImage: NetworkImage(room.image)),
                    title: Text("P.${room.roomNumber} - ${room.type}"),
                    subtitle: Text("${currencyFormatter.format(room.price)} - ${room.bedType}"),
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