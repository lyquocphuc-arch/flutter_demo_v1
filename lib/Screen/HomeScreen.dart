import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Room.dart';
import '../models/Booking.dart';
import 'Service.dart';
import 'RoomDetailScreen.dart';
import 'BookingHistoryScreen.dart';
import 'RoomManagerScreen.dart';
import 'LoginScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- PHẦN LOGIC MỚI (GIỮ NGUYÊN) ---
  final ApiService _apiService = ApiService();
  List<Room> _allRooms = [];
  List<Booking> _bookings = [];
  bool _isLoading = true;

  late DateTime _viewTime;
  int _durationHours = 2;

  bool _isFilterExpanded = false;
  bool _showAvailableOnly = false;
  Map<String, bool> _selectedRoomTypes = {};
  Map<String, bool> _selectedBedTypes = {};

  @override
  void initState() {
    super.initState();
    _viewTime = DateTime.now().add(const Duration(minutes: 5));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    DateTime Time_now = DateTime.now();
    if(Time_now.isAfter(_viewTime))
      _viewTime= Time_now.add(const Duration(minutes: 5));
    DateTime timeNow = DateTime.now();
    if(timeNow.isAfter(_viewTime)) {
      _viewTime = timeNow.add(const Duration(minutes: 5));
    }
    try {
      final rooms = await _apiService.fetchRooms();
      final bookings = await _apiService.fetchBookings();

      final activeRooms = rooms.where((r) => r.isActive).toList();
      activeRooms.sort((a,b) => a.roomNumber.compareTo(b.roomNumber));

      final rTypes = activeRooms.map((e) => e.type).toSet().toList();
      final bTypes = activeRooms.map((e) => e.bedType).toSet().toList();

      Map<String, bool> rTypeMap = {};
      Map<String, bool> bTypeMap = {};

      for (var t in rTypes) rTypeMap[t] = true;
      for (var t in bTypes) bTypeMap[t] = true;

      if (mounted) {
        setState(() {
          _allRooms = activeRooms;
          _bookings = bookings;
          _selectedRoomTypes = rTypeMap;
          _selectedBedTypes = bTypeMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
    List<Room> filteredRooms = _allRooms.where((room) {
      bool typeOk = _selectedRoomTypes[room.type] ?? true;
      bool bedOk = _selectedBedTypes[room.bedType] ?? true;

      if (!typeOk || !bedOk) return false;

      if (_showAvailableOnly) {
        String status = _calculateStatus(room);
        if (status != 'AVAILABLE') return false;
      }

      return true;
    }).toList();

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
          const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hotel, size: 50, color: Colors.white),
                    SizedBox(height: 10),
                    Text("Mini Hotel Admin", style: TextStyle(color: Colors.white, fontSize: 20))
                  ]
              )
          ),
          ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Trang chủ"),
              onTap: () => Navigator.pop(context)
          ),
          ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text("Quản lý Đặt phòng"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen()));
              }
          ),
          ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Quản lý Phòng"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomManagerScreen()));
              }
          ),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Đăng xuất"),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))
          ),
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

          ExpansionTile(
            title: Text("Bộ lọc (${filteredRooms.length} phòng)"),
            initiallyExpanded: _isFilterExpanded,
            onExpansionChanged: (val) => setState(() => _isFilterExpanded = val),
            children: [
              SwitchListTile(
                title: const Text("Chỉ hiện phòng Trống (Available)"),
                value: _showAvailableOnly,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => _showAvailableOnly = val),
              ),
              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(alignment: Alignment.centerLeft, child: Text("Loại phòng:", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold))),
              ),
              Wrap(
                spacing: 10,
                children: _selectedRoomTypes.keys.map((key) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selectedRoomTypes[key],
                        onChanged: (val) => setState(() => _selectedRoomTypes[key] = val!),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Checkbox(value: _selectedRoomTypes[key], onChanged: (val) => setState(() => _selectedRoomTypes[key] = val!), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      Text(key),
                      const SizedBox(width: 10),
                    ],
                  );
                }).toList(),
              ),

              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(alignment: Alignment.centerLeft, child: Text("Loại giường:", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold))),
              ),
              Wrap(
                spacing: 10,
                children: _selectedBedTypes.keys.map((key) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selectedBedTypes[key],
                        onChanged: (val) => setState(() => _selectedBedTypes[key] = val!),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Checkbox(value: _selectedBedTypes[key], onChanged: (val) => setState(() => _selectedBedTypes[key] = val!), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      Text(key),
                      const SizedBox(width: 10),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _loadData,
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10
                ),
                itemCount: filteredRooms.length,
                itemBuilder: (ctx, i) {
                  final room = filteredRooms[i];
                  final status = _calculateStatus(room);
                  final bookingCount = _countActiveBookings(room);
                  Color statusColor = status == 'AVAILABLE' ? Colors.green : status == 'OCCUPIED' ? Colors.red : Colors.orange;

                  return InkWell(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)));
                      _loadData();
                    },
                    child: Card(
                      elevation: 3,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(side: BorderSide(color: statusColor, width: 2), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  room.image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey, child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white))),
                                ),
                                if (bookingCount > 0)
                                  Positioned(
                                    top: 5, right: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]),
                                      child: Text("$bookingCount đơn", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("P.${room.roomNumber}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), border: Border.all(color: statusColor), borderRadius: BorderRadius.circular(4)),
                                        child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                                      )
                                    ],
                                  ),
                                  Text(room.type, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text("${NumberFormat('#,###').format(room.price)} đ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                                ],
                              ),
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