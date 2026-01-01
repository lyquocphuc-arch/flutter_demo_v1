import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Booking.dart';
import 'Service.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<Booking> _allBookings = [];
  List<Booking> _filteredBookings = [];
  String _searchKeyword = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => _filterData());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _apiService.fetchBookings();
      setState(() {
        _allBookings = list;
        _isLoading = false;
      });
      _filterData();
    } catch (e) {
      setState(() => _isLoading = false);
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
      temp = temp.where((b) =>
      b.customerName.toLowerCase().contains(k) ||
          b.customerPhone.contains(k) ||
          b.roomId.contains(k)
      ).toList();
    }
    setState(() => _filteredBookings = temp);
  }

  void _checkIn(Booking b) async {
    bool ok = await _apiService.updateBookingStatus(b, BookingStatus.CheckedIn);
    if (ok) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Check-in thành công")));
      _loadData();
    }
  }

  void _checkOut(Booking b) async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Xác nhận Trả phòng"),
      content: const Text("Hệ thống sẽ tính tiền và kết thúc đơn này."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Đồng ý"))
      ],
    )) ?? false;

    if (!confirm) return;
    bool ok = await _apiService.performCheckOut(b);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trả phòng thành công")));
      _loadData();
    }
  }

  void _cancelBooking(Booking b) async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Xác nhận Hủy"),
      content: const Text("Hủy đơn đặt phòng này?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Không")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text("Hủy đơn", style: TextStyle(color: Colors.white)))
      ],
    )) ?? false;

    if (!confirm) return;
    bool ok = await _apiService.updateBookingStatus(b, BookingStatus.Cancelled);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã hủy đơn")));
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
          labelColor: Colors.white, unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: "Sắp tới"), Tab(text: "Đang ở"), Tab(text: "Lịch sử")],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                  hintText: "Tìm tên, SĐT, số phòng...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10)
              ),
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
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.status == BookingStatus.CheckedIn ? Colors.red : Colors.blue,
                      child: Text(item.roomId, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(item.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${DateFormat('dd/MM HH:mm').format(item.checkIn)} - ${DateFormat('dd/MM HH:mm').format(item.checkOut)}"),
                        if (item.totalPrice > 0)
                          Text("Tổng: ${NumberFormat('#,###').format(item.totalPrice)} đ", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                      ],
                    ),
                    trailing: _buildActionButtons(item),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget? _buildActionButtons(Booking b) {
    if (b.status == BookingStatus.Confirmed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.login, color: Colors.green), onPressed: () => _checkIn(b), tooltip: "Check-in"),
        IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _cancelBooking(b), tooltip: "Hủy"),
      ]);
    } else if (b.status == BookingStatus.CheckedIn) {
      return ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: () => _checkOut(b),
          child: const Text("Trả phòng", style: TextStyle(color: Colors.white, fontSize: 12))
      );
    } else {
      return Text(b.status == BookingStatus.Cancelled ? "Đã Hủy" : "Hoàn tất", style: TextStyle(color: b.status == BookingStatus.Cancelled ? Colors.red : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12));
    }
  }
}