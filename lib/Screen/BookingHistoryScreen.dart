import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Booking.dart';
import '../models/Room.dart';
import 'Service.dart';
import 'RoomDetailScreen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  late TabController _tabController;
  List<Booking> _allBookings = [];
  List<Booking> _filteredBookings = [];
  List<Room> _allRooms = [];
  String _searchKeyword = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _filterData();
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.fetchRooms(),
        _apiService.fetchBookings(),
      ]);

      List<Room> rooms = results[0] as List<Room>;
      List<Booking> list = results[1] as List<Booking>;

      DateTime now = DateTime.now();
      bool hasAutoCancelled = false;

      for (var b in list) {
        if (b.status == BookingStatus.Confirmed) {
          if (now.isAfter(b.checkIn.add(const Duration(minutes: 5)))) {
            await _apiService.updateBookingStatus(b, BookingStatus.Cancelled);
            hasAutoCancelled = true;
          }
        }
      }

      if (hasAutoCancelled) {
        list = await _apiService.fetchBookings();
      }

      if (mounted) {
        setState(() {
          _allRooms = rooms;
          _allBookings = list;
          _isLoading = false;
        });
        _filterData();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getRoomNumber(String roomId) {
    try {
      if (_allRooms.isEmpty) return "P.?";
      final room = _allRooms.firstWhere((r) => r.id == roomId);
      return "P.${room.roomNumber}";
    } catch (e) {
      return "P.?";
    }
  }

  void _filterData() {
    List<Booking> temp = [];
    if (_tabController.index == 0) {
      temp = _allBookings.where((b) => b.status == BookingStatus.Confirmed).toList();
      temp.sort((a, b) => a.checkIn.compareTo(b.checkIn));
    } else if (_tabController.index == 1) {
      temp = _allBookings.where((b) => b.status == BookingStatus.CheckedIn).toList();
    } else {
      temp = _allBookings.where((b) => b.status == BookingStatus.CheckedOut || b.status == BookingStatus.Cancelled).toList();
      temp.sort((a, b) => b.checkOut.compareTo(a.checkOut));
    }

    if (_searchKeyword.isNotEmpty) {
      String k = _searchKeyword.toLowerCase();
      temp = temp.where((b) {
        String roomName = _getRoomNumber(b.roomId).toLowerCase();
        return b.customerName.toLowerCase().contains(k) ||
            b.customerPhone.contains(k) ||
            roomName.contains(k);
      }).toList();
    }
    setState(() => _filteredBookings = temp);
  }

  void _checkIn(Booking b) async {
    bool isAvailable = await _apiService.checkAvailability(b.roomId, DateTime.now(), b.checkOut, excludeBookingId: b.id);
    if (!isAvailable) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phòng đang kẹt!")));
      return;
    }
    if (await _apiService.updateBookingStatus(b, BookingStatus.CheckedIn)) {
      _loadData();
    }
  }

  void _checkOut(Booking b) async {
    Room? room;
    try {
      room = _allRooms.firstWhere((r) => r.id == b.roomId);
    } catch (_) {
      room = await _apiService.fetchRoomById(b.roomId);
    }
    if (room == null) return;

    double penalty = _apiService.calculateLatePenalty(room.price, b.checkOut);
    double finalPrice = b.totalPrice + penalty;

    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Xác nhận Trả phòng"),
      content: Text("Tổng thu: ${currencyFormatter.format(finalPrice)}"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xác nhận"))
      ],
    )) ?? false;

    if (confirm && await _apiService.updateBookingStatus(b, BookingStatus.CheckedOut, totalPrice: finalPrice)) {
      _loadData();
    }
  }

  void _cancelBooking(Booking b) async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Hủy đơn"),
      content: const Text("Xác nhận hủy đơn đặt phòng này?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Không")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xác nhận"))
      ],
    )) ?? false;
    if (confirm && await _apiService.updateBookingStatus(b, BookingStatus.Cancelled)) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quản lý Đặt phòng"),
        backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Sắp tới"), Tab(text: "Đang ở"), Tab(text: "Lịch sử")],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(hintText: "Tìm kiếm...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              onChanged: (val) {
                _searchKeyword = val;
                _filterData();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _filteredBookings.length,
              itemBuilder: (ctx, i) {
                final item = _filteredBookings[i];
                return InkWell(
                  onTap: () async {
                    Room? room;
                    try {
                      room = _allRooms.firstWhere((r) => r.id == item.roomId);
                    } catch (_) {
                      room = await _apiService.fetchRoomById(item.roomId);
                    }
                    if (room != null && mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room!)),
                      );
                      _loadData();
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.status == BookingStatus.CheckedIn ? Colors.red : item.status == BookingStatus.Cancelled ? Colors.grey : Colors.blue,
                        child: Text(_getRoomNumber(item.roomId).replaceAll("P.", ""), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      title: Text(item.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${DateFormat('dd/MM HH:mm').format(item.checkIn)} - ${DateFormat('dd/MM HH:mm').format(item.checkOut)}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.status == BookingStatus.Confirmed) ...[
                            IconButton(icon: const Icon(Icons.login, color: Colors.green), onPressed: () => _checkIn(item)),
                            IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _cancelBooking(item)),
                          ] else if (item.status == BookingStatus.CheckedIn)
                            IconButton(icon: const Icon(Icons.logout, color: Colors.orange), onPressed: () => _checkOut(item)),
                        ],
                      ),
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