import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Booking.dart';
import 'Service.dart';

class BookingHistoryScreen extends StatefulWidget {
  @override
  _BookingHistoryScreenState createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final ApiService _apiService = ApiService();
  String _keyword = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Lịch sử đặt phòng")),
      body: Column(
        children: [
          // Ô tìm kiếm
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Tìm theo tên khách...",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _keyword = val),
            ),
          ),
          // Danh sách
          Expanded(
            child: FutureBuilder<List<Booking>>(
              future: _apiService.fetchBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                if (!snapshot.hasData) return Center(child: Text("Không có dữ liệu"));

                // Filter danh sách theo từ khóa (Search Logic)
                final list = snapshot.data!.where((b) =>
                    b.customerName.toLowerCase().contains(_keyword.toLowerCase())
                ).toList();

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.history),
                        title: Text(item.customerName),
                        subtitle: Text("${DateFormat('dd/MM').format(item.checkIn)} - ${DateFormat('dd/MM').format(item.checkOut)}"),
                        trailing: Text("Phòng ID: ${item.roomId}"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}