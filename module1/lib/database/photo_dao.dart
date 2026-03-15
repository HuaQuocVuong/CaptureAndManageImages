import 'package:module_s1/database/database_helper.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:sqflite/sqflite.dart';

class PhotoDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Lấy database instance
  Future<Database> get _database async => await _dbHelper.database;

  // ==================== PHƯƠNG THỨC CƠ BẢN ====================

  /// Thêm ảnh mới (khi chụp)
  Future<int> insert(String imagePath) async {
    Database db = await _database;
    final now = DateTime.now().toIso8601String();

    return await db.insert('photos', {
      'image_path': imagePath,
      'status': PhotoStatus.captured.name,
      'product_id': null,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Thêm ảnh mới với đầy đủ metadata
  Future<int> insertWithMetadata({
    required String imagePath,
    int? productId,
    String? title,
    String? description,
    double? price,
    String? category,
    String? note,
    PhotoStatus status = PhotoStatus.captured,
  }) async {
    Database db = await _database;

    final now = DateTime.now().toIso8601String();

    final map = {
      'image_path': imagePath,
      'status': status.name,
      'product_id': productId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'note': note,
      'created_at': now,
      'updated_at': now,
    };

    // Loại bỏ các trường null để tránh lỗi
    map.removeWhere((key, value) => value == null);

    final id = await db.insert('photos', map);
    //print('Đã thêm ảnh mới với metadata, id: $id');
    return id;
  }

  /// Lấy ảnh theo ID
  Future<PhotoTask?> getPhotoById(String id) async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
    );

    if (maps.isEmpty) return null;
    return _mapToPhotoTask(maps.first);
  }

  /// Lấy ảnh theo đường dẫn
  Future<PhotoTask?> getPhotoByPath(String imagePath) async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );

    if (maps.isEmpty) return null;
    return _mapToPhotoTask(maps.first);
  }

  /// Lấy tất cả ảnh
  Future<List<PhotoTask>> getAllPhotos() async {
    Database db = await _database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'photos',
        orderBy: 'created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return _mapToPhotoTask(maps[i]);
      });
    } catch (e) {
      //print('Lỗi getAllPhotos: $e');
      return [];
    }
  }

  /// Lấy ảnh theo trạng thái
  Future<List<PhotoTask>> getPhotosByStatus(PhotoStatus status) async {
    Database db = await _database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'photos',
        where: 'status = ?',
        whereArgs: [status.name],
        orderBy: 'created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return _mapToPhotoTask(maps[i]);
      });
    } catch (e) {
      print('Lỗi getPhotosByStatus: $e');
      return [];
    }
  }

  /// Lấy ảnh theo sản phẩm
  Future<List<PhotoTask>> getPhotosByProduct(int productId) async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToPhotoTask).toList();
  }

  /// Lấy ảnh chưa xử lý
  Future<List<PhotoTask>> getPendingTasks() async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'status NOT IN (?, ?)',
      whereArgs: [PhotoStatus.ready.name, PhotoStatus.failed.name],
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToPhotoTask).toList();
  }

  /// Tìm kiếm ảnh theo tiêu đề hoặc mô tả
  Future<List<PhotoTask>> searchPhotos(String query) async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'title LIKE ? OR description LIKE ? OR note LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToPhotoTask).toList();
  }

  // THỨC CẬP NHẬT

  /// Cập nhật metadata của ảnh (phương thức quan trọng nhất)
  Future<void> updatePhotoMetadata(
    int photoId, {
    int? productId,
    String? title,
    String? description,
    double? price,
    String? category,
    String? note,
    PhotoStatus? status,
  }) async {
    Database db = await _database;

    final Map<String, dynamic> updates = {};

    if (productId != null) updates['product_id'] = productId;
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (category != null) updates['category'] = category;
    if (note != null) updates['note'] = note;
    if (status != null) updates['status'] = status.name;

    // Luôn cập nhật thời gian sửa đổi
    updates['updated_at'] = DateTime.now().toIso8601String();

    if (updates.isNotEmpty) {
      await db.update('photos', updates, where: 'id = ?', whereArgs: [photoId]);
      //print('Đã cập nhật metadata cho photoId: $photoId');
    }
  }

  /// Cập nhật toàn bộ thông tin ảnh
  Future<void> updatePhoto(PhotoTask photo) async {
    Database db = await _database;
    await db.update(
      'photos',
      {
        'image_path': photo.filePath,
        'status': photo.status.name,
        'product_id': photo.productId,
        'title': photo.title,
        'description': photo.description,
        'price': photo.price,
        'category': photo.category,
        'note': photo.note,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [int.parse(photo.id)],
    );
  }

  /// Cập nhật trạng thái theo đường dẫn
  Future<void> updateStatus(String imagePath, PhotoStatus status) async {
    Database db = await _database;
    await db.update(
      'photos',
      {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
  }

  /// Cập nhật trạng thái theo ID
  Future<void> updatePhotoStatus(int photoId, PhotoStatus status) async {
    Database db = await _database;
    await db.update(
      'photos',
      {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  // ==================== PHƯƠNG THỨC GÁN CHO SẢN PHẨM ====================

  /// Gán ảnh cho sản phẩm (theo đường dẫn)
  Future<void> assignToProduct(
    String imagePath,
    int productId, {
    PhotoStatus newStatus = PhotoStatus.ready,
  }) async {
    Database db = await _database;
    await db.update(
      'photos',
      {
        'product_id': productId,
        'status': newStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
  }

  /// Gán ảnh cho sản phẩm (theo ID)
  Future<void> assignToProductById(
    int photoId,
    int productId, {
    PhotoStatus newStatus = PhotoStatus.ready,
  }) async {
    Database db = await _database;
    await db.update(
      'photos',
      {
        'product_id': productId,
        'status': newStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  // ==================== PHƯƠNG THỨC XÓA ====================

  /// Xóa ảnh
  Future<void> deletePhoto(int id) async {
    Database db = await _database;
    await db.delete('photos', where: 'id = ?', whereArgs: [id]);
    //print('Đã xóa ảnh ID: $id');
  }

  /// Xóa ảnh theo đường dẫn
  Future<void> deletePhotoByPath(String imagePath) async {
    Database db = await _database;
    await db.delete('photos', where: 'image_path = ?', whereArgs: [imagePath]);
    //print('Đã xóa ảnh: $imagePath');
  }

  // ==================== PHƯƠNG THỨC THỐNG KÊ ====================

  /// Đếm số ảnh
  Future<int> countPhotos() async {
    Database db = await _database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM photos'),
        ) ??
        0;
  }

  /// Đếm số ảnh theo trạng thái
  Future<int> countPhotosByStatus(PhotoStatus status) async {
    Database db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM photos WHERE status = ?',
      [status.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Lấy metadata của ảnh
  Future<Map<String, dynamic>?> getPhotoMetadata(int photoId) async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'id = ?',
      whereArgs: [photoId],
      columns: ['title', 'description', 'price', 'category', 'note', 'status'],
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  // ==================== HELPER METHOD ====================

  /// Helper method để chuyển đổi Map thành PhotoTask
  PhotoTask _mapToPhotoTask(Map<String, dynamic> map) {
    return PhotoTask(
      id: map['id'].toString(),
      filePath: map['image_path'] ?? '',
      status: PhotoStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PhotoStatus.captured,
      ),
      productId: map['product_id'] as int?,
      title: map['title'] as String?,
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble(),
      category: map['category'] as String?,
      note: map['note'] as String?,
    );
  }
}
