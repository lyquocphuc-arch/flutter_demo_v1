import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Room.dart';
import '../models/Booking.dart';
import 'Service.dart';
import 'RoomDetailScreen.dart';
import 'RoomManagerScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    DateTime timeNow = DateTime.now();
    if (timeNow.isAfter(_viewTime)) {
      _viewTime = timeNow.add(const Duration(minutes: 5));
    }
    try {
      final rooms = await _apiService.fetchRooms();
      final bookings = await _apiService.fetchBookings();

      final activeRooms = rooms.where((r) => r.isActive).toList();
      activeRooms.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));

      final rTypes = activeRooms.map((e) => e.type).toSet().toList();
      final bTypes = activeRooms.map((e) => e.bedType).toSet().toList();

      if (_selectedRoomTypes.isEmpty) {
        for (var t in rTypes) _selectedRoomTypes[t] = true;
      }
      if (_selectedBedTypes.isEmpty) {
        for (var t in bTypes) _selectedBedTypes[t] = true;
      }

      if (mounted) {
        setState(() {
          _allRooms = activeRooms;
          _bookings = bookings;
          _isLoading = false;
        });
      }
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
    if (!mounted) return;
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomManagerScreen())),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
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
                title: const Text("Chỉ hiện phòng Trống"),
                value: _showAvailableOnly,
                activeThumbColor: Colors.green,
                onChanged: (val) => setState(() => _showAvailableOnly = val),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(alignment: Alignment.centerLeft, child: Text("Loại phòng:", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold))),
              ),
              Column(
                children: _selectedRoomTypes.keys.map((key) {
                  return CheckboxListTile(
                    title: Text(key),
                    value: _selectedRoomTypes[key],
                    onChanged: (val) => setState(() => _selectedRoomTypes[key] = val!),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    dense: true,
                  );
                }).toList(),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(alignment: Alignment.centerLeft, child: Text("Loại giường:", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold))),
              ),
              Column(
                children: _selectedBedTypes.keys.map((key) {
                  return CheckboxListTile(
                    title: Text(key),
                    value: _selectedBedTypes[key],
                    onChanged: (val) => setState(() => _selectedBedTypes[key] = val!),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    dense: true,
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
                    crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 10, mainAxisSpacing: 10
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Image.network(
                              room.image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey, child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white))),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("P.${room.roomNumber}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)),
                                        child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                  Text(room.type, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(room.bedType, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text("${NumberFormat('#,###').format(room.price)} đ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                                  if (bookingCount > 0)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(4),
                                      color: Colors.blue.shade50,
                                      child: Text("$bookingCount đơn sắp tới/đang ở", style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    )
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