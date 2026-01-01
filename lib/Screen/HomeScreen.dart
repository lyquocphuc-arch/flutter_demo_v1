import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Room.dart';
import '../models/Booking.dart';
import 'Service.dart';
import 'RoomDetailScreen.dart';
import 'BookingHistoryScreen.dart';
import 'RoomManagerScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Room> _rooms = [];
  List<Booking> _bookings = [];
  bool _isLoading = true;
  late DateTime _viewTime;
  int _durationHours = 2;

  @override
  void initState() {
    super.initState();
    _viewTime = _roundToNext30Minutes(DateTime.now());
    _loadData();
  }

  DateTime _roundToNext30Minutes(DateTime dt) {
    int minute = dt.minute;
    if (minute == 0 || minute == 30) return dt;
    int add = (minute < 30) ? (30 - minute) : (60 - minute);
    return dt.add(Duration(minutes: add));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await _apiService.fetchRooms();
      final bookings = await _apiService.fetchBookings();
      setState(() {
        _rooms = rooms.where((r) => r.isActive).toList();
        _rooms.sort((a,b) => a.roomNumber.compareTo(b.roomNumber));
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _calculateStatus(Room room) {
    DateTime start = _viewTime;
    DateTime end = _viewTime.add(Duration(hours: _durationHours));
    var roomBookings = _bookings.where((b) => b.roomId == room.id).toList();
    for (var b in roomBookings) {
      if (b.status == BookingStatus.Cancelled || b.status == BookingStatus.CheckedOut) continue;
      if (start.isBefore(b.checkOut) && end.isAfter(b.checkIn)) {
        if (b.status == BookingStatus.CheckedIn) return "OCCUPIED";
        return "RESERVED";
      }
    }
    return "AVAILABLE";
  }

  int _countActiveBookings(Room room) {
    return _bookings.where((b) =>
    b.roomId == room.id &&
        (b.status == BookingStatus.Confirmed || b.status == BookingStatus.CheckedIn)
    ).length;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(context: context, initialDate: _viewTime, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (date == null) return;
    if(!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_viewTime));
    if (time == null) return;
    setState(() {
      _viewTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sơ đồ phòng"),
        backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      drawer: Drawer(
        child: ListView(children: [
          const DrawerHeader(decoration: BoxDecoration(color: Colors.blueAccent), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hotel, size: 50, color: Colors.white), SizedBox(height: 10), Text("Mini Hotel Admin", style: TextStyle(color: Colors.white, fontSize: 20))])),
          ListTile(leading: const Icon(Icons.dashboard), title: const Text("Trang chủ"), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.list_alt), title: const Text("Quản lý Đặt phòng"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen()));}),
          ListTile(leading: const Icon(Icons.settings), title: const Text("Quản lý Phòng"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomManagerScreen()));}),
        ]),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12), color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDateTime,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Xem trạng thái lúc:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(DateFormat('HH:mm - dd/MM').format(_viewTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                  ),
                ),
                const VerticalDivider(),
                DropdownButton<int>(
                  value: _durationHours,
                  underline: Container(),
                  items: [1, 2, 4, 12, 24].map((h) => DropdownMenuItem(value: h, child: Text("+ $h giờ"))).toList(),
                  onChanged: (v) => setState(() => _durationHours = v!),
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _loadData,
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 10, mainAxisSpacing: 10
                ),
                itemCount: _rooms.length,
                itemBuilder: (ctx, i) {
                  final room = _rooms[i];
                  final status = _calculateStatus(room);
                  final bookingCount = _countActiveBookings(room);
                  Color color = status == 'AVAILABLE' ? Colors.green : status == 'OCCUPIED' ? Colors.red : Colors.orange;
                  return InkWell(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)));
                      _loadData();
                    },
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(side: BorderSide(color: color, width: 2), borderRadius: BorderRadius.circular(8)),
                      child: Stack(
                        children: [
                          if (bookingCount > 0)
                            Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: const BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), topRight: Radius.circular(8))), child: Text("$bookingCount đơn", style: const TextStyle(color: Colors.white, fontSize: 10)))),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text("P.${room.roomNumber}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))
                                ]),
                                const Spacer(),
                                Text(room.type, style: const TextStyle(fontSize: 12)),
                                Text("${NumberFormat('#,###').format(room.price)} đ", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}