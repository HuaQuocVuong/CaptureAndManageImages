import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Lớp DatabaseHelper quản lý kết nối và thao tác với cơ sở dữ liệu SQLite
// Sử dụng Singleton pattern để đảm bảo chỉ có một instance duy nhất
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

  // Khởi tạo database: KHÔNG xóa database cũ để giữ dữ liệu
  Future<Database> _initDatabase() async {
    // Lấy đường dẫn đến thư mục databases của ứng dụng
    String path = join(await getDatabasesPath(), 'product_manager.db');

    // ĐÃ COMMENT: Không xóa database cũ để giữ dữ liệu
    // try {
    //   await deleteDatabase(path);
    //   debugPrint('Đã xóa database cũ');
    // } catch (e) {
    //   debugPrint('Lỗi khi xóa database cũ: $e');
    // }

    // Mở database (hoặc tạo mới nếu chưa tồn tại)
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate, // Gọi khi database được tạo lần đầu
      onOpen: _onOpen, // Gọi sau khi mở database thành công
    );
  }

  // Đọc nội dung file SQL từ assets (thư mục lib/database/script)
  Future<String> _loadSQLFile(String fileName) async {
    try {
      String path = 'lib/database/script/$fileName';
      debugPrint('Đang đọc file: $path');
      return await rootBundle.loadString(path);
    } catch (e) {
      debugPrint('LỖI: Không tìm thấy file $fileName. Lỗi: $e');
      return '';
    }
  }

  // Thực thi toàn bộ các câu lệnh SQL trong một file
  Future<void> _executeSQLFile(Database db, String fileName) async {
    debugPrint('=== BẮT ĐẦU THỰC THI FILE: $fileName ===');

    String sql = await _loadSQLFile(fileName);
    if (sql.isEmpty) {
      debugPrint('FILE TRỐNG: $fileName');
      return;
    }

    // In toàn bộ nội dung file để kiểm tra
    debugPrint('Nội dung file SQL:');
    debugPrint(sql);
    debugPrint('=== KẾT THÚC NỘI DUNG FILE ===');

    // Tách các câu lệnh SQL bằng dấu chấm phẩy (;)
    List<String> statements = sql
        .split(';')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    debugPrint('Tổng số câu lệnh: ${statements.length}');

    // Duyệt và thực thi từng câu lệnh
    for (int i = 0; i < statements.length; i++) {
      String statement = statements[i].trim();
      if (statement.isEmpty || statement.startsWith('--')) continue;

      try {
        debugPrint('Đang chạy câu lệnh ${i + 1}: $statement');
        await db.execute(statement);
        debugPrint('✓ Câu lệnh ${i + 1} thành công');
      } catch (e) {
        debugPrint('✗ LỖI ở câu lệnh ${i + 1}:');
        debugPrint('Câu lệnh: $statement');
        debugPrint('Lỗi: $e');
        rethrow; // Ném lại lỗi để dừng quá trình tạo database
      }
    }
    debugPrint('=== HOÀN THÀNH FILE: $fileName ===');
  }

  // Hàm callback khi database được tạo lần đầu
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('=== BẮT ĐẦU TẠO DATABASE ===');

    try {
      // Thực thi theo thứ tự
      await _executeSQLFile(db, 'create_tables.sql');
      await _executeSQLFile(db, 'create_indexes.sql');
      await _executeSQLFile(db, 'create_triggers.sql');
      await _executeSQLFile(db, 'seed_data.sql');

      debugPrint('=== TẠO DATABASE THÀNH CÔNG ===');
    } catch (e) {
      debugPrint('=== LỖI TẠO DATABASE: $e ===');
      rethrow; // Ném lỗi ra ngoài để biết nguyên nhân
    }
  }

  // Hàm callback sau khi mở database thành công
  Future<void> _onOpen(Database db) async {
    try {
      // Bật hỗ trợ khóa ngoại (foreign key) cho SQLite
      await db.execute('PRAGMA foreign_keys = ON');
      debugPrint('Đã bật foreign_keys');

      // Lấy danh sách các bảng trong database
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      debugPrint('Các bảng trong database:');
      for (var table in tables) {
        debugPrint('  - ${table['name']}');
      }

      // Kiểm tra cấu trúc bảng photos nếu tồn tại
      final hasPhotos = tables.any((t) => t['name'] == 'photos');
      if (hasPhotos) {
        final columns = await db.rawQuery('PRAGMA table_info(photos)');
        debugPrint('Cấu trúc bảng photos:');
        for (var col in columns) {
          debugPrint('  - ${col['name']} (${col['type']})');
        }
      } else {
        debugPrint('⚠️ Bảng photos chưa được tạo!');
      }
    } catch (e) {
      debugPrint('Lỗi trong _onOpen: $e');
    }
  }

  // ========== PHƯƠNG THỨC CRUD CHO PRODUCTS ==========

  // Lấy tất cả sản phẩm
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query('products', orderBy: 'created_at DESC');
  }

  // Lấy sản phẩm theo ID
  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Thêm sản phẩm mới
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    product['created_at'] = now;
    product['updated_at'] = now;
    return await db.insert('products', product);
  }

  // Cập nhật sản phẩm
  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    product['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }

  // Xóa sản phẩm
  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ========== PHƯƠNG THỨC CRUD CHO PHOTOS ==========

  // Lấy tất cả ảnh
  Future<List<Map<String, dynamic>>> getAllPhotos() async {
    final db = await database;
    return await db.query('photos', orderBy: 'created_at DESC');
  }

  // Lấy ảnh theo product_id
  Future<List<Map<String, dynamic>>> getPhotosByProductId(int productId) async {
    final db = await database;
    return await db.query(
      'photos',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
  }

  // Lấy ảnh theo ID
  Future<Map<String, dynamic>?> getPhotoById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'photos',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Thêm ảnh mới
  Future<int> insertPhoto(Map<String, dynamic> photo) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    photo['created_at'] = now;
    photo['updated_at'] = now;

    return await db.insert('photos', photo);
  }

  // Cập nhật ảnh
  Future<int> updatePhoto(Map<String, dynamic> photo) async {
    final db = await database;
    photo['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'photos',
      photo,
      where: 'id = ?',
      whereArgs: [photo['id']],
    );
  }

  // Xóa ảnh
  Future<int> deletePhoto(int id) async {
    final db = await database;
    return await db.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  // Xóa tất cả ảnh của một sản phẩm
  Future<int> deletePhotosByProductId(int productId) async {
    final db = await database;
    return await db.delete(
      'photos',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  // ========== PHƯƠNG THỨC TÌM KIẾM ==========

  // Tìm kiếm sản phẩm theo tên
  Future<List<Map<String, dynamic>>> searchProducts(String keyword) async {
    final db = await database;
    return await db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'name ASC',
    );
  }

  // Tìm kiếm ảnh theo tiêu đề
  Future<List<Map<String, dynamic>>> searchPhotos(String keyword) async {
    final db = await database;
    return await db.query(
      'photos',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'created_at DESC',
    );
  }

  // ========== PHƯƠNG THỨC THỐNG KÊ ==========

  // Đếm tổng số sản phẩm
  Future<int> countProducts() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Đếm tổng số ảnh
  Future<int> countPhotos() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM photos');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Đếm số ảnh theo trạng thái
  Future<int> countPhotosByStatus(String status) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM photos WHERE status = ?',
      [status],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Lấy tổng giá trị sản phẩm
  Future<double> getTotalProductValue() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(price) as total FROM products',
    );
    return result.first['total'] as double? ?? 0.0;
  }

  // ========== PHƯƠNG THỨC TIỆN ÍCH ==========

  // Xóa tất cả dữ liệu (chỉ dùng cho test)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('photos');
    await db.delete('products');
    debugPrint('Đã xóa tất cả dữ liệu');
  }

  // Đóng database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      debugPrint('Đã đóng database');
    }
  }
}
