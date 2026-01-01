import '../models/Room.dart';
import '../Screen/Service.dart';

class RoomManager {
  static final RoomManager _instance = RoomManager._internal();
  factory RoomManager() => _instance;
  RoomManager._internal();

  final ApiService _apiService = ApiService();

  Future<List<Room>> getRooms({bool isAdmin = false}) async {
    try {
      List<Room> allRooms = await _apiService.fetchRooms();
      if (isAdmin) {
        return allRooms;
      } else {
        return allRooms.where((room) => room.isActive).toList();
      }
    } catch (e) {
      return [];
    }
  }

  Future<bool> addRoom(Room newRoom) async {
    return await _apiService.createRoom(newRoom);
  }

  Future<bool> editRoom(Room room) async {
    return await _apiService.updateRoom(room);
  }

  Future<bool> toggleRoomVisibility(Room room) async {
    Room updatedRoom = Room(
      id: room.id,
      roomNumber: room.roomNumber,
      type: room.type,
      bedType: room.bedType,
      price: room.price,
      isActive: !room.isActive,
      image: room.image,
    );
    return await editRoom(updatedRoom);
  }
}