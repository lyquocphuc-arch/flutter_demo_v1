import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Booking.dart';
import 'Service.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final ApiService _apiService = ApiService();
  String _keyword = "";

  // Key để force reload FutureBuilder
  UniqueKey _refreshKey = UniqueKey();

  // Hàm làm mới danh sách
  Future<void> _handleRefresh() async {
    setState(() {
      _refreshKey = UniqueKey();
    });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // --- 1. HÀM XỬ LÝ XÓA ---
  void _confirmDelete(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận hủy", style: TextStyle(color: Colors.red)),
        content: const Text("Bạn có chắc chắn muốn hủy đơn đặt phòng này không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Đóng"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // Đóng dialog

              bool success = await _apiService.deleteBooking(bookingId);

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã hủy thành công!")));
                  _handleRefresh(); // Load lại danh sách ngay
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi: Không thể hủy.")));
                }
              }
            },
            child: const Text("Xác nhận hủy", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 2. HÀM XỬ LÝ SỬA (HIỆN FORM) ---
  void _showEditForm(BuildContext context, Booking booking) {
    final nameController = TextEditingController(text: booking.customerName);
    final phoneController = TextEditingController(text: booking.customerPhone);
    DateTimeRange selectedDateRange = DateTimeRange(start: booking.checkIn, end: booking.checkOut);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // Dùng StatefulBuilder để cập nhật UI trong Modal khi chọn ngày
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Sửa đơn P.${booking.roomId}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  const SizedBox(height: 15),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: "Tên khách hàng", prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Số điện thoại", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: selectedDateRange,
                      );
                      if (picked != null) {
                        setModalState(() => selectedDateRange = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 10),
                          Text("${DateFormat('dd/MM').format(selectedDateRange.start)} - ${DateFormat('dd/MM').format(selectedDateRange.end)}", style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () async {
                        // Tạo object mới
                        Booking updatedBooking = Booking(
                          id: booking.id, // ID cũ
                          roomId: booking.roomId, // Phòng cũ
                          customerName: nameController.text,
                          customerPhone: phoneController.text,
                          checkIn: selectedDateRange.start,
                          checkOut: selectedDateRange.end,
                        );

                        bool success = await _apiService.updateBooking(updatedBooking);

                        if (mounted) {
                          Navigator.pop(ctx);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật thành công!")));
                            _handleRefresh();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi cập nhật!")));
                          }
                        }
                      },
                      child: const Text("LƯU THAY ĐỔI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lịch sử đặt phòng"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Ô TÌM KIẾM
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                hintText: "Tìm tên khách...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
              onChanged: (val) => setState(() => _keyword = val),
            ),
          ),

          // 2. DANH SÁCH
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: FutureBuilder<List<Booking>>(
                key: _refreshKey,
                future: _apiService.fetchBookings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text("Lỗi kết nối: ${snapshot.error}"));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Chưa có đơn đặt phòng nào"));

                  // Lọc theo tên
                  final list = snapshot.data!.where((b) => b.customerName.toLowerCase().contains(_keyword.toLowerCase())).toList();

                  if (list.isEmpty) return const Center(child: Text("Không tìm thấy kết quả"));

                  return ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final checkInStr = DateFormat('dd/MM').format(item.checkIn);
                      final checkOutStr = DateFormat('dd/MM').format(item.checkOut);

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            child: const Icon(Icons.person, color: Colors.blueAccent),
                          ),
                          title: Text(item.customerName.isEmpty ? "Khách vãng lai" : item.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.customerPhone, style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Row(children: [const Icon(Icons.calendar_today, size: 14, color: Colors.green), const SizedBox(width: 4), Text("$checkInStr - $checkOutStr")]),
                            ],
                          ),

                          // --- MENU SỬA / XÓA ---
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                                child: Text("P.${item.roomId}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showEditForm(context, item);
                                  if (value == 'delete') _confirmDelete(context, item.id);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 10), Text('Sửa')])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 10), Text('Hủy')])),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}