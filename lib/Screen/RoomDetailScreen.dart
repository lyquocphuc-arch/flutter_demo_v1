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
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  DateTime _checkIn = DateTime.now().add(const Duration(minutes: 5));
  int _duration = 2;
  double _estimatedPrice = 0;

  @override
  void initState() {
    super.initState();
    _calculatePrice();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _calculatePrice() {
    setState(() {
      _estimatedPrice = _apiService.calculateTotalPrice(
        widget.room.price,
        _checkIn,
        _checkIn.add(Duration(hours: _duration)),
      );
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_checkIn),
    );
    if (time == null) return;

    setState(() {
      _checkIn = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
    _calculatePrice();
  }

  Future<void> _handleBookingSubmit() async {
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();
    DateTime checkOut = _checkIn.add(Duration(hours: _duration));

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đủ thông tin!")));
      return;
    }

    if (!RegExp(r'^0\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SĐT không hợp lệ!")));
      return;
    }

    try {
      bool isAvailable = await _apiService.checkAvailability(widget.room.id, _checkIn, checkOut);
      if (!mounted) return;
      if (!isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phòng bị trùng lịch!")));
        return;
      }

      Booking newBooking = Booking(
          id: '', roomId: widget.room.id, customerName: name, customerPhone: phone,
          checkIn: _checkIn, checkOut: checkOut,
          status: BookingStatus.Confirmed, totalPrice: _estimatedPrice
      );

      bool ok = await _apiService.createBooking(newBooking);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đặt phòng thành công!"), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Phòng ${widget.room.roomNumber}"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.network(widget.room.image, height: 250, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.room.type, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(currencyFormatter.format(widget.room.price), style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text("Giường: ${widget.room.bedType}", style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 30),
                  const Text("THÔNG TIN ĐẶT PHÒNG", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  const SizedBox(height: 15),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Tên khách hàng", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 15),
                  TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Số điện thoại", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 15),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                    title: const Text("Giờ nhận phòng"),
                    subtitle: Text(DateFormat('HH:mm - dd/MM/yyyy').format(_checkIn)),
                    onTap: _pickDateTime,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.blueAccent),
                      const SizedBox(width: 15),
                      const Text("Thời lượng:"),
                      const SizedBox(width: 20),
                      DropdownButton<int>(
                        value: _duration,
                        items: [1, 2, 4, 8, 12, 24].map((h) => DropdownMenuItem(value: h, child: Text("$h giờ"))).toList(),
                        onChanged: (v) {
                          setState(() => _duration = v!);
                          _calculatePrice();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_estimatedPrice > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text("Tạm tính: ${currencyFormatter.format(_estimatedPrice)}", style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleBookingSubmit,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text("XÁC NHẬN ĐẶT PHÒNG", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}