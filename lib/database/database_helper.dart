import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Lớp DatabaseHelper quản lý kết nối và thao tác với cơ sở dữ liệu SQLite
/// Sử dụng Singleton pattern để đảm bảo chỉ có một instance duy nhất
class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Khởi tạo database: KHÔNG xóa database cũ để giữ dữ liệu
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'product_manager.db');

    // Mở database với version = 3 (đã thêm cột captured_at)
    return await openDatabase(
      path,
      version: 3, // Tăng version lên 3 để thêm cột captured_at
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  /// Xử lý nâng cấp database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('=== NÂNG CẤP DATABASE từ $oldVersion lên $newVersion ===');

    if (oldVersion < 2) {
      // Nâng cấp từ version 1 lên 2: thêm productType, color
      try {
        await _addNewColumnsToProducts(db);
        await _addNewColumnsToPhotos(db);
        debugPrint('=== NÂNG CẤP LÊN VERSION 2 THÀNH CÔNG ===');
      } catch (e) {
        debugPrint('=== LỖI NÂNG CẤP VERSION 2: $e ===');
        rethrow;
      }
    }

    if (oldVersion < 3) {
      // Nâng cấp từ version 2 lên 3: thêm cột captured_at vào bảng photos
      try {
        await _addCapturedAtColumn(db);
        debugPrint('=== NÂNG CẤP LÊN VERSION 3 THÀNH CÔNG ===');
      } catch (e) {
        debugPrint('=== LỖI NÂNG CẤP VERSION 3: $e ===');
        rethrow;
      }
    }
  }

  /// Thêm cột productType và color cho bảng products (nếu chưa có)
  Future<void> _addNewColumnsToProducts(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(products)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('productType')) {
        await db.execute('ALTER TABLE products ADD COLUMN productType TEXT');
        debugPrint('Đã thêm cột productType vào bảng products');
      }
      if (!columnNames.contains('color')) {
        await db.execute('ALTER TABLE products ADD COLUMN color TEXT');
        debugPrint('Đã thêm cột color vào bảng products');
      }
    } catch (e) {
      debugPrint('Lỗi khi thêm cột mới cho products: $e');
      rethrow;
    }
  }

  /// Thêm cột productType và color cho bảng photos (nếu chưa có)
  Future<void> _addNewColumnsToPhotos(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(photos)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('productType')) {
        await db.execute('ALTER TABLE photos ADD COLUMN productType TEXT');
        debugPrint('Đã thêm cột productType vào bảng photos');
      }
      if (!columnNames.contains('color')) {
        await db.execute('ALTER TABLE photos ADD COLUMN color TEXT');
        debugPrint('Đã thêm cột color vào bảng photos');
      }
    } catch (e) {
      debugPrint('Lỗi khi thêm cột mới cho photos: $e');
      rethrow;
    }
  }

  /// Thêm cột captured_at vào bảng photos (lưu thời gian chụp thực tế)
  Future<void> _addCapturedAtColumn(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(photos)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('captured_at')) {
        await db.execute('ALTER TABLE photos ADD COLUMN captured_at DATETIME');
        debugPrint('Đã thêm cột captured_at vào bảng photos');

        // Cập nhật giá trị captured_at cho các ảnh cũ bằng created_at
        await db.execute(
          'UPDATE photos SET captured_at = created_at WHERE captured_at IS NULL',
        );
        debugPrint('Đã cập nhật captured_at = created_at cho ảnh cũ');
      } else {
        debugPrint('Cột captured_at đã tồn tại trong bảng photos');
      }
    } catch (e) {
      debugPrint('Lỗi khi thêm cột captured_at: $e');
      rethrow;
    }
  }

  /// Đọc nội dung file SQL từ assets
  Future<String> _loadSQLFile(String fileName) async {
    try {
      String path = 'lib/database/script/$fileName';
      return await rootBundle.loadString(path);
    } catch (e) {
      debugPrint('LỖI: Không tìm thấy file $fileName. Lỗi: $e');
      return '';
    }
  }

  /// Thực thi toàn bộ các câu lệnh SQL trong một file
  Future<void> _executeSQLFile(Database db, String fileName) async {
    debugPrint('=== BẮT ĐẦU THỰC THI FILE: $fileName ===');
    String sql = await _loadSQLFile(fileName);
    if (sql.isEmpty) return;

    List<String> statements = sql
        .split(';')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    for (int i = 0; i < statements.length; i++) {
      String statement = statements[i].trim();
      if (statement.isEmpty || statement.startsWith('--')) continue;
      try {
        await db.execute(statement);
      } catch (e) {
        debugPrint('✗ LỖI ở câu lệnh ${i + 1}: $statement\nLỗi: $e');
        rethrow;
      }
    }
    debugPrint('=== HOÀN THÀNH FILE: $fileName ===');
  }

  /// Tạo database lần đầu
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('=== BẮT ĐẦU TẠO DATABASE ===');
    try {
      await _executeSQLFile(db, 'create_tables.sql');
      await _executeSQLFile(db, 'create_indexes.sql');
      await _executeSQLFile(db, 'create_triggers.sql');
      await _executeSQLFile(db, 'seed_data.sql');
      debugPrint('=== TẠO DATABASE THÀNH CÔNG ===');
    } catch (e) {
      debugPrint('=== LỖI TẠO DATABASE: $e ===');
      rethrow;
    }
  }

  /// Sau khi mở database
  Future<void> _onOpen(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
      debugPrint('Đã bật foreign_keys');
    } catch (e) {
      debugPrint('Lỗi trong _onOpen: $e');
    }
  }

  // ========== CÁC PHƯƠNG THỨC CRUD (giữ nguyên, không cần sửa) ==========
  // Chỉ cần đảm bảo khi gọi insertPhoto/updatePhoto có truyền trường 'captured_at'
  // Các phương thức dưới đây giữ nguyên như cũ

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query('products', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    product['created_at'] = now;
    product['updated_at'] = now;
    product.removeWhere((key, value) => value == null);
    return await db.insert('products', product);
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    product['updated_at'] = DateTime.now().toIso8601String();
    product.removeWhere((key, value) => value == null);
    return await db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // --- Photos ---
  Future<List<Map<String, dynamic>>> getAllPhotos() async {
    final db = await database;
    return await db.query('photos', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getPhotosByProductId(int productId) async {
    final db = await database;
    return await db.query(
      'photos',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getPhotoById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'photos',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getPhotoByPath(String imagePath) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'photos',
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getPhotosByStatus(String status) async {
    final db = await database;
    return await db.query(
      'photos',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> insertPhoto(Map<String, dynamic> photo) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    photo['created_at'] = now;
    photo['updated_at'] = now;
    // Nếu không có captured_at thì gán bằng created_at (cho ảnh mới)
    if (!photo.containsKey('captured_at') || photo['captured_at'] == null) {
      photo['captured_at'] = now;
    }
    photo.removeWhere((key, value) => value == null);
    return await db.insert('photos', photo);
  }

  Future<int> updatePhoto(Map<String, dynamic> photo) async {
    final db = await database;
    photo['updated_at'] = DateTime.now().toIso8601String();
    photo.removeWhere((key, value) => value == null);
    return await db.update(
      'photos',
      photo,
      where: 'id = ?',
      whereArgs: [photo['id']],
    );
  }

  Future<int> updatePhotoStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'photos',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePhoto(int id) async {
    final db = await database;
    return await db.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePhotoByPath(String imagePath) async {
    final db = await database;
    return await db.delete(
      'photos',
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
  }

  Future<int> deletePhotosByProductId(int productId) async {
    final db = await database;
    return await db.delete(
      'photos',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> deletePhotosByStatus(String status) async {
    final db = await database;
    return await db.delete('photos', where: 'status = ?', whereArgs: [status]);
  }

  // ========== CÁC PHƯƠNG THỨC TÌM KIẾM, THỐNG KÊ, TIỆN ÍCH ==========
  // (Giữ nguyên như code cũ, không thay đổi)

  Future<List<Map<String, dynamic>>> searchProducts(String keyword) async {
    final db = await database;
    return await db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> searchProductsAdvanced({
    String? keyword,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) async {
    final db = await database;
    List<String> conditions = [];
    List<dynamic> args = [];
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('name LIKE ?');
      args.add('%$keyword%');
    }
    if (category != null && category.isNotEmpty) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (minPrice != null) {
      conditions.add('price >= ?');
      args.add(minPrice);
    }
    if (maxPrice != null) {
      conditions.add('price <= ?');
      args.add(maxPrice);
    }
    String whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : '';
    return await db.query(
      'products',
      where: whereClause,
      whereArgs: args,
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> searchPhotos(String keyword) async {
    final db = await database;
    return await db.query(
      'photos',
      where: 'title LIKE ? OR description LIKE ? OR note LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> countProducts() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countPhotos() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM photos');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countPhotosByStatus(String status) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM photos WHERE status = ?',
      [status],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countPhotosByProduct(int productId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM photos WHERE product_id = ?',
      [productId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalProductValue() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(price) as total FROM products',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getAverageProductPrice() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(price) as avg_price FROM products',
    );
    return (result.first['avg_price'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getProductsGroupByCategory() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        category, 
        COUNT(*) as count,
        SUM(price) as total_value,
        AVG(price) as avg_price
      FROM products 
      WHERE category IS NOT NULL
      GROUP BY category
      ORDER BY count DESC
    ''');
  }

  Future<bool> isPhotoExists(String imagePath) async {
    final db = await database;
    final result = await db.query(
      'photos',
      where: 'image_path = ?',
      whereArgs: [imagePath],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> insertMultiplePhotos(List<Map<String, dynamic>> photos) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    Batch batch = db.batch();
    for (var photo in photos) {
      photo['created_at'] = now;
      photo['updated_at'] = now;
      if (!photo.containsKey('captured_at') || photo['captured_at'] == null) {
        photo['captured_at'] = now;
      }
      photo.removeWhere((key, value) => value == null);
      batch.insert('photos', photo);
    }
    await batch.commit(noResult: true);
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('photos');
    await db.delete('products');
    debugPrint('Đã xóa tất cả dữ liệu');
  }

  Future<void> deleteDatabaseFile() async {
    try {
      String path = join(await getDatabasesPath(), 'product_manager.db');
      await deleteDatabase(path);
      _database = null;
      debugPrint('Đã xóa database file');
    } catch (e) {
      debugPrint('Lỗi deleteDatabaseFile: $e');
    }
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    );
    return {
      'databasePath': await getDatabasesPath(),
      'tableCount': tables.length,
      'indexCount': indexes.length,
      'tables': tables,
      'indexes': indexes,
    };
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      debugPrint('Đã đóng database');
    }
  }
}
