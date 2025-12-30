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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Đặt phòng ${widget.room.roomNumber}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 15),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Tên khách hàng", prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Số điện thoại", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
              const SizedBox(height: 15),
              InkWell(
                onTap: () async {
                  // --- SỬA Ở ĐÂY ---
                  // Đổi lastDate từ 2026 thành 2030 (hoặc xa hơn tùy ý)
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030), // Cho phép đặt lịch trước đến năm 2030
                    helpText: 'Chọn ngày nhận và trả phòng', // Tiêu đề tiếng Việt cho dễ hiểu
                    saveText: 'Xong',
                  );
                  // ------------------

                  if (picked != null) {
                    setState(() => _selectedDateRange = picked);
                    Navigator.pop(ctx);
                    _showBookingForm(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.blue),
                      const SizedBox(width: 10),
                      Text(_selectedDateRange == null ? "Chọn ngày Check-in - Check-out" : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}", style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: () async { await _handleBookingSubmit(ctx); },
                  child: const Text("XÁC NHẬN ĐẶT PHÒNG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleBookingSubmit(BuildContext ctx) async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _selectedDateRange == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin!"), backgroundColor: Colors.orange));
      return;
    }
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Đang kiểm tra lịch trống...")));

    try {
      if (!mounted) return;
      bool isAvailable = await _apiService.checkAvailability(widget.room.id, _selectedDateRange!.start, _selectedDateRange!.end);
      if (!mounted) return;
      if (!isAvailable) {
        Navigator.pop(ctx);
        showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Thất bại", style: TextStyle(color: Colors.red)), content: const Text("Phòng đã bị trùng lịch!"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))]));
        return;
      }

      Booking newBooking = Booking(id: '', roomId: widget.room.id, customerName: _nameController.text, customerPhone: _phoneController.text, checkIn: _selectedDateRange!.start, checkOut: _selectedDateRange!.end);
      await _apiService.createBooking(newBooking);

      await _apiService.updateRoomStatus(widget.room.id, "Reserved");

      if (!mounted) return;
      Navigator.pop(ctx);

      await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
              title: const Text("Thành công", style: TextStyle(color: Colors.green)),
              content: const Text("Đặt phòng thành công!"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text("OK")
                )
              ]
          )
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Container(
          height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
          child: const TextField(decoration: InputDecoration(hintText: "Tìm kiếm...", prefixIcon: Icon(Icons.search, color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.only(top: 5))),
        ),
        actions: [Padding(padding: const EdgeInsets.only(right: 16.0), child: Row(children: const [Text("Admin", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), SizedBox(width: 8), CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.blueAccent))]))],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              Image.network(widget.room.image, width: double.infinity, height: 250, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(height: 250, color: Colors.grey, child: const Center(child: Icon(Icons.error)))),
              Positioned(bottom: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), color: Colors.black54, child: Text("P. ${widget.room.roomNumber}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))))
            ]),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(widget.room.type, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text(currencyFormatter.format(widget.room.price), style: const TextStyle(fontSize: 22, color: Colors.blue, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 10),
                  Row(children: [const Icon(Icons.bed, color: Colors.grey), const SizedBox(width: 8), Text(widget.room.bedType, style: const TextStyle(fontSize: 16)), const SizedBox(width: 20), Icon(Icons.circle, size: 12, color: widget.room.status == 'Available' ? Colors.green : Colors.red), const SizedBox(width: 5), Text(widget.room.status, style: const TextStyle(fontSize: 16))]),
                  const Divider(height: 30),
                  const Text("Mô tả", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Phòng được trang bị đầy đủ tiện nghi, view đẹp thoáng mát. Bao gồm Wifi miễn phí, bữa sáng và dịch vụ dọn phòng hàng ngày.", style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: () => _showBookingForm(context),
          child: const Text("ĐẶT PHÒNG NGAY", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}