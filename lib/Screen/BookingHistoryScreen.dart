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
      if (!_tabController.indexIsChanging) _filterData();
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
        if (b.status == BookingStatus.Confirmed && now.isAfter(b.checkIn.add(const Duration(minutes: 5)))) {
          await _apiService.updateBookingStatus(b, BookingStatus.Cancelled);
          hasAutoCancelled = true;
        }
      }
      if (hasAutoCancelled) list = await _apiService.fetchBookings();
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
        return b.customerName.toLowerCase().contains(k) || b.customerPhone.contains(k) || roomName.contains(k);
      }).toList();
    }
    setState(() => _filteredBookings = temp);
  }

  void _checkIn(Booking b) async {
    bool isAvailable = await _apiService.checkAvailability(b.roomId, DateTime.now(), b.checkOut, excludeBookingId: b.id);
    if (!isAvailable) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phòng đang kẹt!")));
      return;
    }
    if (await _apiService.updateBookingStatus(b, BookingStatus.CheckedIn)) _loadData();
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
    if (confirm && await _apiService.updateBookingStatus(b, BookingStatus.CheckedOut, totalPrice: finalPrice)) _loadData();
  }

  void _cancelBooking(Booking b) async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Hủy đơn"),
      content: const Text("Xác nhận hủy đơn này?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Không")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xác nhận"))
      ],
    )) ?? false;
    if (confirm && await _apiService.updateBookingStatus(b, BookingStatus.Cancelled)) _loadData();
  }

  void _showDetailOrEdit(Booking b) {
    bool canEdit = b.status == BookingStatus.Confirmed;
    final nameCtrl = TextEditingController(text: b.customerName);
    final phoneCtrl = TextEditingController(text: b.customerPhone);
    DateTime start = b.checkIn;
    DateTime end = b.checkOut;
    String roomLabel = _getRoomNumber(b.roomId);

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text(canEdit ? "Sửa đơn đặt" : "Chi tiết đơn"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text("Mã đơn: ${b.id}"), subtitle: Text("Phòng: $roomLabel"), contentPadding: EdgeInsets.zero),
              TextField(controller: nameCtrl, enabled: canEdit, decoration: const InputDecoration(labelText: "Tên khách", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, enabled: canEdit, decoration: const InputDecoration(labelText: "SĐT", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 15),
              InkWell(
                onTap: canEdit ? () async {
                  final range = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030), initialDateRange: DateTimeRange(start: start, end: end));
                  if (range == null) return;
                  if (!mounted) return;
                  final timeIn = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
                  if (timeIn == null) return;
                  final timeOut = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(end));
                  if (timeOut == null) return;
                  setStateDialog(() {
                    start = DateTime(range.start.year, range.start.month, range.start.day, timeIn.hour, timeIn.minute);
                    end = DateTime(range.end.year, range.end.month, range.end.day, timeOut.hour, timeOut.minute);
                  });
                } : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                  child: Text("${DateFormat('dd/MM HH:mm').format(start)} - ${DateFormat('dd/MM HH:mm').format(end)}"),
                ),
              ),
              const SizedBox(height: 10),
              Text("Tổng tiền: ${currencyFormatter.format(b.totalPrice)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
          if (canEdit)
            ElevatedButton(onPressed: () async {
              Booking newB = Booking(id: b.id, roomId: b.roomId, customerName: nameCtrl.text, customerPhone: phoneCtrl.text, checkIn: start, checkOut: end, status: b.status, totalPrice: b.totalPrice);
              if (await _apiService.updateBookingInfo(newB)) {
                Navigator.pop(ctx);
                _loadData();
              }
            }, child: const Text("Lưu"))
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quản lý Đặt phòng"),
        backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: "Sắp tới"), Tab(text: "Đang ở"), Tab(text: "Lịch sử")]),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(hintText: "Tìm kiếm...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              onChanged: (val) { _searchKeyword = val; _filterData(); },
            ),
          ),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: _filteredBookings.length,
              itemBuilder: (ctx, i) {
                final item = _filteredBookings[i];
                return InkWell(
                  onTap: () => _showDetailOrEdit(item),
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