import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Room.dart';
import '../Screen/RoomManager.dart';


class RoomManagerScreen extends StatefulWidget {
  const RoomManagerScreen({super.key});

  @override
  State<RoomManagerScreen> createState() => _RoomManagerScreenState();
}

class _RoomManagerScreenState extends State<RoomManagerScreen> {
  final RoomManager _manager = RoomManager();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  List<Room> _rooms = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    List<Room> rooms = await _manager.getRooms(isAdmin: true);
    rooms.sort((a, b) {
      if (!a.isActive && b.isActive) return 1;
      if (a.isActive && !b.isActive) return -1;
      return a.roomNumber.compareTo(b.roomNumber);
    });
    if (mounted) setState(() { _rooms = rooms; _isLoading = false; });
  }

  void _showRoomDialog({Room? room}) {
    final isEditing = room != null;
    final numberController = TextEditingController(text: isEditing ? room.roomNumber.toString() : "");
    final typeController = TextEditingController(text: isEditing ? room.type : "Standard");
    final bedTypeController = TextEditingController(text: isEditing ? room.bedType : "Single Bed");
    final priceController = TextEditingController(text: isEditing ? room.price.toString() : "");
    final imageController = TextEditingController(text: isEditing ? room.image : "https://via.placeholder.com/300");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? "Sửa phòng" : "Thêm phòng"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: numberController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Số phòng")),
              TextField(controller: typeController, decoration: const InputDecoration(labelText: "Loại phòng")),
              TextField(controller: bedTypeController, decoration: const InputDecoration(labelText: "Loại giường")),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Giá")),
              TextField(controller: imageController, decoration: const InputDecoration(labelText: "URL Ảnh")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              if (numberController.text.isEmpty || priceController.text.isEmpty) return;

              final newRoom = Room(
                id: isEditing ? room.id : "",
                roomNumber: int.tryParse(numberController.text) ?? 0,
                type: typeController.text,
                bedType: bedTypeController.text,
                price: double.tryParse(priceController.text) ?? 0,
                status: isEditing ? room.status : "Available",
                isActive: isEditing ? room.isActive : true,
                image: imageController.text,
              );

              bool success = isEditing ? await _manager.editRoom(newRoom) : await _manager.addRoom(newRoom);
              if (mounted && success) { Navigator.pop(ctx); _fetchRooms(); }
            },
            child: const Text("Lưu"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý phòng"), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRoomDialog(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          final isHidden = !room.isActive;
          return Card(
            color: isHidden ? Colors.grey[300] : Colors.white,
            child: ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(room.image)),
              title: Text("P.${room.roomNumber} - ${room.type}", style: TextStyle(decoration: isHidden ? TextDecoration.lineThrough : null, color: isHidden ? Colors.grey : Colors.black)),
              subtitle: Text(isHidden ? "Đang ẩn" : "${currencyFormatter.format(room.price)} - ${room.bedType}", style: TextStyle(color: isHidden ? Colors.red : Colors.green)),
              trailing: PopupMenuButton<String>(
                onSelected: (val) async {
                  if (val == 'edit') _showRoomDialog(room: room);
                  if (val == 'toggle') { await _manager.toggleRoomVisibility(room); _fetchRooms(); }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text("Sửa")),
                  PopupMenuItem(value: 'toggle', child: Text(isHidden ? "Hiện lại" : "Ẩn phòng")),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}