import 'package:module_s1/database/database_helper.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:sqflite/sqflite.dart';
//import 'package:your_app/database/database_helper.dart';
//import 'package:your_app/models/photo_model.dart'; // chứa PhotoStatus, PhotoTask

class PhotoDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Thêm ảnh mới (khi chụp)
  Future<int> insert(String imagePath) async {
    Database db = await _dbHelper.database;
    return await db.insert('photos', {
      'image_path': imagePath,
      'status': PhotoStatus.captured.name,
    });
  }

  // Gán ảnh cho sản phẩm và cập nhật trạng thái
  Future<void> assignToProduct(String imagePath, int productId, {PhotoStatus newStatus = PhotoStatus.queued}) async {
    Database db = await _dbHelper.database;
    await db.update(
      'photos',
      {
        'product_id': productId,
        'status': newStatus.name,
      },
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
  }

  // Cập nhật trạng thái
  Future<void> updateStatus(String imagePath, PhotoStatus status) async {
    Database db = await _dbHelper.database;
    await db.update(
      'photos',
      {'status': status.name},
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
  }

  // Lấy tất cả ảnh chưa xử lý (chưa gán sản phẩm hoặc đang chờ)
  Future<List<PhotoTask>> getPendingTasks() async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'status != ?',
      whereArgs: [PhotoStatus.ready.name],
    );
    return maps.map((map) {
      return PhotoTask(
        id: map['id'].toString(),
        filePath: map['image_path'],
        status: PhotoStatus.values.firstWhere((e) => e.name == map['status']),
      );
    }).toList();
  }

  // Lấy tất cả ảnh (có thể dùng để hiển thị gallery)
  Future<List<PhotoTask>> getAllPhotos() async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('photos');
    return maps.map((map) {
      return PhotoTask(
        id: map['id'].toString(),
        filePath: map['image_path'],
        status: PhotoStatus.values.firstWhere((e) => e.name == map['status']),
      );
    }).toList();
  }
}