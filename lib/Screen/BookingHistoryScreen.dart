import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Booking.dart';
import '../models/Room.dart';
import 'Service.dart';

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
      if (_allRooms.isEmpty) return "Phòng $roomId";
      final room = _allRooms.firstWhere((r) => r.id == roomId);
      return "P.${room.roomNumber}";
    } catch (e) {
      return "Phòng $roomId";
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phòng đang kẹt, không thể Check-in!")));
      return;
    }

    bool ok = await _apiService.updateBookingStatus(b, BookingStatus.CheckedIn);
    if (ok) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Check-in thành công")));
      _loadData();
    }
  }

  void _checkOut(Booking b) async {
    if (!mounted) return;

    Room? room;
    try {
      room = _allRooms.firstWhere((r) => r.id == b.roomId);
    } catch (_) {
      room = await _apiService.fetchRoomById(b.roomId);
    }

    if (room == null) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi: Không tìm thấy thông tin phòng!")));
      return;
    }

    double originalPrice = b.totalPrice;
    double penalty = _apiService.calculateLatePenalty(room.price, b.checkOut);
    double finalPrice = originalPrice + penalty;
    bool isLate = penalty > 0;

    if (!mounted) return;
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Xác nhận Trả phòng"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDetailRow("Phòng:", "P.${room!.roomNumber}"),
          _buildDetailRow("Khách hàng:", b.customerName),
          const Divider(),
          _buildDetailRow("Check-out (Lịch):", DateFormat('HH:mm dd/MM').format(b.checkOut)),
          _buildDetailRow("Hiện tại:", DateFormat('HH:mm dd/MM').format(DateTime.now())),
          if (isLate)
            const Text("(Quá giờ - Có phạt)", style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          _buildDetailRow("Giá tạm tính:", currencyFormatter.format(originalPrice)),
          _buildDetailRow("Phạt quá giờ:", currencyFormatter.format(penalty), color: Colors.red),
          const Divider(thickness: 1.5),
          _buildDetailRow("TỔNG THU:", currencyFormatter.format(finalPrice), isBold: true, color: Colors.blue, scale: 1.2),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Xác nhận & Thu tiền")
        )
      ],
    )) ?? false;

    if (!confirm) return;

    bool ok = await _apiService.updateBookingStatus(
        b,
        BookingStatus.CheckedOut,
        totalPrice: finalPrice
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trả phòng thành công")));
      _loadData();
    }
  }

  Widget _buildDetailRow(String label, String value, {Color color = Colors.black, bool isBold = false, double scale = 1.0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 14 * scale, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
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

  void _showDetailOrEdit(Booking b) {
    bool canEdit = b.status == BookingStatus.Confirmed;
    final nameCtrl = TextEditingController(text: b.customerName);
    final phoneCtrl = TextEditingController(text: b.customerPhone);
    DateTime start = b.checkIn;
    DateTime end = b.checkOut;

    bool isOverdue = b.status == BookingStatus.Confirmed && DateTime.now().isAfter(b.checkOut);
    String roomLabel = _getRoomNumber(b.roomId);

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(canEdit ? "Sửa đơn" : "Chi tiết"),
              if (isOverdue)
                const Text("(Quá hạn)", style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(5)),
                  child: Column(
                    children: [
                      _buildInfoRow("Mã đơn:", b.id),
                      const SizedBox(height: 5),
                      _buildInfoRow("Phòng:", roomLabel),
                      const SizedBox(height: 5),
                      _buildInfoRow("Trạng thái:", b.status.toString().split('.').last),
                      const SizedBox(height: 5),
                      _buildInfoRow("Tổng tiền:", currencyFormatter.format(b.totalPrice), isPrice: true),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                TextField(
                    controller: nameCtrl,
                    enabled: canEdit,
                    decoration: const InputDecoration(labelText: "Tên khách", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0))
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: phoneCtrl,
                    enabled: canEdit,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "SĐT", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0))
                ),
                const SizedBox(height: 10),
                const Text("Thời gian:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 5),
                InkWell(
                  onTap: canEdit ? () async {
                    final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                        initialDateRange: DateTimeRange(start: start, end: end)
                    );
                    if (range == null) return;
                    if (!mounted) return;

                    final timeIn = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(start),
                        helpText: "Chọn giờ nhận"
                    );
                    if (timeIn == null) return;
                    if (!mounted) return;

                    final timeOut = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(end),
                        helpText: "Chọn giờ trả"
                    );
                    if (timeOut == null) return;

                    setStateDialog(() {
                      start = DateTime(range.start.year, range.start.month, range.start.day, timeIn.hour, timeIn.minute);
                      end = DateTime(range.end.year, range.end.month, range.end.day, timeOut.hour, timeOut.minute);
                    });
                  } : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4), color: canEdit ? Colors.white : Colors.grey[200]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd/MM HH:mm').format(start)),
                        const Icon(Icons.arrow_right_alt, size: 16),
                        Text(DateFormat('dd/MM HH:mm').format(end)),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
            if (canEdit)
              ElevatedButton(onPressed: () async {
                if (start.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giờ nhận phòng phải sau hiện tại ít nhất 5 phút!")));
                  return;
                }
                if (end.isBefore(start)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giờ trả phải sau giờ nhận!")));
                  return;
                }
                if (!RegExp(r'^0\d{9}$').hasMatch(phoneCtrl.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SĐT sai (10 số, bắt đầu bằng 0)")));
                  return;
                }
                bool avail = await _apiService.checkAvailability(b.roomId, start, end, excludeBookingId: b.id);
                if (!avail) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lịch mới bị trùng!")));
                  return;
                }

                Room? r;
                try {
                  r = _allRooms.firstWhere((room) => room.id == b.roomId);
                } catch (_) {
                  r = await _apiService.fetchRoomById(b.roomId);
                }

                double newPrice = b.totalPrice;
                if(r != null) {
                  newPrice = _apiService.calculateTotalPrice(r.price, start, end);
                }

                Booking newB = Booking(
                    id: b.id, roomId: b.roomId, customerName: nameCtrl.text, customerPhone: phoneCtrl.text,
                    checkIn: start, checkOut: end, status: b.status,
                    totalPrice: newPrice
                );

                bool ok = await _apiService.updateBookingInfo(newB);
                if (ok) {
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật thành công")));
                }
              }, child: const Text("Lưu"))
          ],
        );
      },
    ));
  }

  Widget _buildInfoRow(String label, String value, {bool isPrice = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isPrice ? Colors.blue : Colors.black)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quản lý Đặt phòng"),
        backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
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
              decoration: InputDecoration(hintText: "Tìm tên, SĐT, số phòng...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10)),
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
                  onTap: () => _showDetailOrEdit(item),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.status == BookingStatus.CheckedIn ? Colors.red : item.status == BookingStatus.Cancelled ? Colors.grey : Colors.blue,
                        child: Text(_getRoomNumber(item.roomId).replaceAll("P.", ""), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(item.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SĐT: ${item.customerPhone}", style: const TextStyle(fontSize: 11)),
                          Text("${DateFormat('dd/MM HH:mm').format(item.checkIn)} - ${DateFormat('dd/MM HH:mm').format(item.checkOut)}"),
                        ],
                      ),
                      trailing: _buildActionButtons(item),
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

  Widget? _buildActionButtons(Booking b) {
    if (b.status == BookingStatus.Confirmed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.login, color: Colors.green), onPressed: () => _checkIn(b), tooltip: "Check-in"),
        IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _cancelBooking(b), tooltip: "Hủy"),
      ]);
    } else if (b.status == BookingStatus.CheckedIn) {
      return IconButton(icon: const Icon(Icons.logout, color: Colors.orange), onPressed: () => _checkOut(b), tooltip: "Trả phòng");
    }
    return null;
  }
}