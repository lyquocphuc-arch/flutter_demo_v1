import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Room.dart';
import '../models/Booking.dart';
import 'Service.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  const RoomDetailScreen({super.key, required this.room});
  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  double _estimatedPrice = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _calculatePreviewPrice() {
    if (_selectedDateRange == null) return;
    double price = _apiService.calculateTotalPrice(
        widget.room.price,
        _selectedDateRange!.start,
        _selectedDateRange!.end
    );
    setState(() => _estimatedPrice = price);
  }

  Future<void> _pickDateAndTime(BuildContext ctx) async {
    final DateTimeRange? dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      saveText: 'Tiếp tục',
    );
    if (dateRange == null) return;
    if (!mounted) return;
    final TimeOfDay? timeCheckIn = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 14, minute: 0), helpText: "Giờ Check-in");
    if (timeCheckIn == null) return;
    if (!mounted) return;
    final TimeOfDay? timeCheckOut = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0), helpText: "Giờ Check-out");
    if (timeCheckOut == null) return;

    DateTime startDateTime = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day, timeCheckIn.hour, timeCheckIn.minute);
    DateTime endDateTime = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, timeCheckOut.hour, timeCheckOut.minute);

    if (endDateTime.isBefore(startDateTime)) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Giờ trả phải sau giờ nhận!")));
      return;
    }
    setState(() => _selectedDateRange = DateTimeRange(start: startDateTime, end: endDateTime));
    _calculatePreviewPrice();
    Navigator.pop(ctx);
    _showBookingForm(context);
  }

  void _showBookingForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Đặt phòng ${widget.room.roomNumber}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Tên khách", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Số điện thoại", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              InkWell(
                onTap: () => _pickDateAndTime(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_selectedDateRange == null ? "Chọn Ngày & Giờ" : "${DateFormat('dd/MM HH:mm').format(_selectedDateRange!.start)} - ...")),
                    ],
                  ),
                ),
              ),
              if (_estimatedPrice > 0)
                Padding(padding: const EdgeInsets.only(top: 15), child: Text("Tạm tính: ${currencyFormatter.format(_estimatedPrice)}", style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { await _handleBookingSubmit(ctx); }, child: const Text("XÁC NHẬN"))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleBookingSubmit(BuildContext ctx) async {
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty || _selectedDateRange == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đủ thông tin!")));
      return;
    }

    if (_selectedDateRange!.start.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Giờ nhận phòng phải sau hiện tại ít nhất 5 phút!")));
      return;
    }

    if (!RegExp(r'^0\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("SĐT sai (10 số, bắt đầu bằng 0)")));
      return;
    }

    try {
      if (!mounted) return;
      bool isAvailable = await _apiService.checkAvailability(widget.room.id, _selectedDateRange!.start, _selectedDateRange!.end);
      if (!mounted) return;
      if (!isAvailable) {
        Navigator.pop(ctx);
        showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Thất bại"), content: const Text("Phòng bị trùng lịch!"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))]));
        return;
      }

      Booking newBooking = Booking(
          id: '', roomId: widget.room.id, customerName: name, customerPhone: phone,
          checkIn: _selectedDateRange!.start, checkOut: _selectedDateRange!.end,
          status: BookingStatus.Confirmed, totalPrice: _estimatedPrice
      );

      bool ok = await _apiService.createBooking(newBooking);
      if (ok) {
        if (!mounted) return;
        Navigator.pop(ctx);
        await showDialog(context: context, builder: (_) => const AlertDialog(content: Text("Đặt phòng thành công!")));
        if(mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết phòng")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.network(widget.room.image, height: 250, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(height: 250, color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Phòng ${widget.room.roomNumber} - ${widget.room.type}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(currencyFormatter.format(widget.room.price), style: const TextStyle(fontSize: 20, color: Colors.blue)),
                  const SizedBox(height: 10),
                  Text("Giường: ${widget.room.bedType}"),
                  const Divider(),
                  const Text("Mô tả: Tiện nghi, view đẹp, Wifi freee"),
                ],
              ),
            )
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(onPressed: () => _showBookingForm(context), child: const Text("ĐẶT PHÒNG NGAY")),
      ),
    );
  }
}