import 'package:module_s1/database/database_helper.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:sqflite/sqflite.dart';

/// Data Access Object (DAO) cho bảng photos
class PhotoDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Database> get _database async => await _dbHelper.database;

  // ==================== PHƯƠNG THỨC THÊM ====================

  /// Thêm một bản ghi ảnh mới sau khi chụp.
  /// Ghi nhận thời gian chụp thực tế (capturedAt).
  Future<int> insert(String imagePath, DateTime capturedAt) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('photos', {
      'image_path': imagePath,
      'status': PhotoStatus.captured.name,
      'product_id': null,
      'captured_at': capturedAt.toIso8601String(),
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Thêm ảnh với đầy đủ metadata và thời gian chụp.
  Future<int> insertWithMetadata({
    required String imagePath,
    int? productId,
    String? title,
    String? description,
    double? price,
    String? category,
    String? note,
    String? productType,
    String? color,
    PhotoStatus status = PhotoStatus.captured,
    DateTime? capturedAt,
  }) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    final capturedAtStr = (capturedAt ?? DateTime.now()).toIso8601String();

    final map = {
      'image_path': imagePath,
      'status': status.name,
      'product_id': productId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'note': note,
      'productType': productType,
      'color': color,
      'captured_at': capturedAtStr,
      'created_at': now,
      'updated_at': now,
    };
    map.removeWhere((key, value) => value == null);
    return await db.insert('photos', map);
  }

  // ==================== PHƯƠNG THỨC TRUY VẤN ====================

  Future<PhotoTask?> getPhotoById(int id) async {
    final db = await _database;
    try {
      final maps = await db.query('photos', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return _mapToPhotoTask(maps.first);
    } catch (e) {
      return null;
    }
  }

  Future<PhotoTask?> getPhotoByPath(String imagePath) async {
    final db = await _database;
    try {
      final maps = await db.query(
        'photos',
        where: 'image_path = ?',
        whereArgs: [imagePath],
      );
      if (maps.isEmpty) return null;
      return _mapToPhotoTask(maps.first);
    } catch (e) {
      return null;
    }
  }

  Future<List<PhotoTask>> getAllPhotos() async {
    final db = await _database;
    try {
      final maps = await db.query('photos', orderBy: 'created_at DESC');
      return maps.map(_mapToPhotoTask).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PhotoTask>> getPhotosByStatus(PhotoStatus status) async {
    final db = await _database;
    try {
      final maps = await db.query(
        'photos',
        where: 'status = ?',
        whereArgs: [status.name],
        orderBy: 'created_at DESC',
      );
      return maps.map(_mapToPhotoTask).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PhotoTask>> getPhotosByProduct(int productId) async {
    final db = await _database;
    try {
      final maps = await db.query(
        'photos',
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'created_at DESC',
      );
      return maps.map(_mapToPhotoTask).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PhotoTask>> getPendingTasks() async {
    final db = await _database;
    try {
      final maps = await db.query(
        'photos',
        where: 'status NOT IN (?, ?)',
        whereArgs: [PhotoStatus.ready.name, PhotoStatus.failed.name],
        orderBy: 'created_at DESC',
      );
      return maps.map(_mapToPhotoTask).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PhotoTask>> searchPhotos(String query) async {
    final db = await _database;
    try {
      final maps = await db.query(
        'photos',
        where: 'title LIKE ? OR description LIKE ? OR note LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'created_at DESC',
      );
      return maps.map(_mapToPhotoTask).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== PHƯƠNG THỨC CẬP NHẬT ====================

  Future<void> updatePhotoMetadata(
    int photoId, {
    int? productId,
    String? title,
    String? description,
    double? price,
    String? category,
    String? note,
    String? productType,
    String? color,
    PhotoStatus? status,
  }) async {
    final db = await _database;
    final updates = <String, dynamic>{};
    if (productId != null) updates['product_id'] = productId;
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (category != null) updates['category'] = category;
    if (note != null) updates['note'] = note;
    if (productType != null) updates['productType'] = productType;
    if (color != null) updates['color'] = color;
    if (status != null) updates['status'] = status.name;
    updates['updated_at'] = DateTime.now().toIso8601String();
    if (updates.isNotEmpty) {
      await db.update('photos', updates, where: 'id = ?', whereArgs: [photoId]);
    }
  }

  Future<void> updatePhoto(PhotoTask photo) async {
    final db = await _database;
    try {
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
          'productType': photo.productType,
          'color': photo.color,
          'captured_at': photo.capturedAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [int.parse(photo.id)],
      );
    } catch (e) {}
  }

  Future<void> updateStatus(String imagePath, PhotoStatus status) async {
    final db = await _database;
    try {
      await db.update(
        'photos',
        {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
        where: 'image_path = ?',
        whereArgs: [imagePath],
      );
    } catch (e) {}
  }

  Future<void> updatePhotoStatus(int photoId, PhotoStatus status) async {
    final db = await _database;
    try {
      await db.update(
        'photos',
        {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [photoId],
      );
    } catch (e) {}
  }

  // ==================== PHƯƠNG THỨC GÁN CHO SẢN PHẨM ====================

  Future<void> assignToProduct(
    String imagePath,
    int productId, {
    PhotoStatus newStatus = PhotoStatus.ready,
  }) async {
    final db = await _database;
    try {
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
    } catch (e) {}
  }

  Future<void> assignToProductById(
    int photoId,
    int productId, {
    PhotoStatus newStatus = PhotoStatus.ready,
  }) async {
    final db = await _database;
    try {
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
    } catch (e) {}
  }

  // ==================== PHƯƠNG THỨC XÓA ====================

  Future<void> deletePhoto(int id) async {
    final db = await _database;
    try {
      await db.delete('photos', where: 'id = ?', whereArgs: [id]);
    } catch (e) {}
  }

  Future<void> deletePhotoByPath(String imagePath) async {
    final db = await _database;
    try {
      await db.delete(
        'photos',
        where: 'image_path = ?',
        whereArgs: [imagePath],
      );
    } catch (e) {}
  }

  Future<void> deleteMultiplePhotos(List<int> photoIds) async {
    final db = await _database;
    try {
      await db.delete(
        'photos',
        where: 'id IN (${List.filled(photoIds.length, '?').join(',')})',
        whereArgs: photoIds,
      );
    } catch (e) {}
  }

  // ==================== PHƯƠNG THỨC THỐNG KÊ ====================

  Future<int> countPhotos() async {
    final db = await _database;
    try {
      return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM photos'),
          ) ??
          0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> countPhotosByStatus(PhotoStatus status) async {
    final db = await _database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM photos WHERE status = ?',
        [status.name],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getPhotoMetadata(int photoId) async {
    final db = await _database;
    try {
      final maps = await db.query(
        'photos',
        where: 'id = ?',
        whereArgs: [photoId],
        columns: [
          'title',
          'description',
          'price',
          'category',
          'note',
          'status',
          'productType',
          'color',
        ],
      );
      if (maps.isEmpty) return null;
      return maps.first;
    } catch (e) {
      return null;
    }
  }

  // ==================== PHƯƠNG THỨC BỔ SUNG ====================

  Future<bool> isPhotoExists(String imagePath) async {
    final db = await _database;
    try {
      final result = await db.query(
        'photos',
        where: 'image_path = ?',
        whereArgs: [imagePath],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<PhotoTask>> getPhotosPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _database;
    try {
      final maps = await db.query(
        'photos',
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );
      return maps.map(_mapToPhotoTask).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== HELPER ====================

  PhotoTask _mapToPhotoTask(Map<String, dynamic> map) {
    // Xử lý captured_at: nếu null (dữ liệu cũ) thì dùng created_at
    DateTime capturedAt;
    if (map['captured_at'] != null) {
      capturedAt = DateTime.parse(map['captured_at']);
    } else {
      capturedAt = map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now();
    }

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
      productType: map['productType'] as String?,
      color: map['color'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      capturedAt: capturedAt,
    );
  }
}
