import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_demo_v1/models/Room.dart';
import 'package:flutter_demo_v1/Screen/Service.dart';
import 'package:flutter_demo_v1/Screen/RoomDetailScreen.dart';
import 'package:flutter_demo_v1/Screen/BookingHistoryScreen.dart';
import 'package:flutter_demo_v1/Screen/LoginScreen.dart';
import 'package:flutter_demo_v1/Screen/RoomManagerScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final String _userName = "Admin";
  List<Room> _rooms = [];
  List<Room> _allRoomsLoaded = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadMoreRooms();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        _loadMoreRooms();
      }
    });
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadMoreRooms() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      List<Room> newRooms = await _apiService.fetchRooms(_page, _limit);

      newRooms = newRooms.where((r) => r.isActive).toList();

      setState(() {
        _page++;
        if (newRooms.length < _limit) _hasMore = false;
        _allRoomsLoaded.addAll(newRooms);
        _rooms = _allRoomsLoaded;
      });
    } catch (e) {
      print("Lỗi tải trang: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _refreshRooms() {
    setState(() {
      _page = 1;
      _rooms.clear();
      _allRoomsLoaded.clear();
      _hasMore = true;
      _isLoading = false;
    });
    _loadMoreRooms();
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _rooms = _allRoomsLoaded.where((room) {
        return (room.roomNumber.toString().contains(query) ||
            room.type.toLowerCase().contains(query)) && room.isActive;
      }).toList();
    });
  }

  void _navigateToHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingHistoryScreen()));
  }

  void _handleLogout() {
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent, elevation: 0, titleSpacing: 0,
        title: Container(
          height: 40, margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
          child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: "Tìm phòng...", hintStyle: TextStyle(fontSize: 14, color: Colors.grey), prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.only(top: 5))),
        ),
        actions: [
          IconButton(tooltip: "Lịch sử", icon: const Icon(Icons.history, color: Colors.white), onPressed: _navigateToHistory),
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Row(children: [Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [const Text("Xin chào,", style: TextStyle(fontSize: 10, color: Colors.white70)), Text(_userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]), const SizedBox(width: 8), const CircleAvatar(backgroundColor: Colors.white, radius: 16, child: Icon(Icons.person, color: Colors.blueAccent, size: 20))]),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          UserAccountsDrawerHeader(decoration: const BoxDecoration(color: Colors.blueAccent), accountName: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), accountEmail: const Text("admin@minihotel.com"), currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Colors.blueAccent))),
          ListTile(leading: const Icon(Icons.home, color: Colors.blueAccent), title: const Text('Trang chủ'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.history, color: Colors.blueAccent), title: const Text('Lịch sử đặt phòng'), onTap: () {Navigator.pop(context); _navigateToHistory();}),
          ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Quản lý phòng'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomManagerScreen()));
              }
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Đăng xuất'), onTap: _handleLogout)
        ]),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _rooms.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _rooms.length) return const Center(child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator()));
                final room = _rooms[index];
                return GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RoomDetailScreen(room: room)),
                    );
                    if (result == true) {
                      _refreshRooms();
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)), child: Image.network(room.image, width: 120, height: 100, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 120, height: 100, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey)))),
                        Expanded(child: Padding(padding: const EdgeInsets.all(10.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Phòng ${room.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), _buildStatusBadge(room.status)]), const SizedBox(height: 5), Row(children: [const Icon(Icons.king_bed, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(room.type, style: TextStyle(color: Colors.grey[700], fontSize: 13))]), const SizedBox(height: 8), Text(currencyFormatter.format(room.price), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16))]))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color; String label;
    switch (status) {
      case 'Available': color = Colors.green; label = "Trống"; break;
      case 'Occupied': color = Colors.red; label = "Đang ở"; break;
      case 'Reserved': color = Colors.orange; label = "Đã đặt"; break;
      default: color = Colors.grey; label = status;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}