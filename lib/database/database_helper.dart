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

  // Khởi tạo database: xóa cũ (chỉ trong development) và tạo mới
  Future<Database> _initDatabase() async {
    // Lấy đường dẫn đến thư mục databases của ứng dụng
    String path = join(await getDatabasesPath(), 'product_manager.db');

    // XÓA DATABASE CŨ(Test)
    try {
      await deleteDatabase(path);
      debugPrint('Đã xóa database cũ');
    } catch (e) {
      debugPrint('Lỗi khi xóa database cũ: $e');
    }

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
    // In ra một phần nội dung để kiểm tra (200 ký tự đầu)
    debugPrint('Nội dung file (200 ký tự đầu):');
    debugPrint(sql.substring(0, sql.length > 200 ? 200 : sql.length));

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
        debugPrint(
          'Đang chạy câu lệnh ${i + 1}: ${statement.substring(0, statement.length > 50 ? 50 : statement.length)}...',
        );
        await db.execute(statement);
        debugPrint('Câu lệnh ${i + 1} thành công');
      } catch (e) {
        debugPrint('LỖI ở câu lệnh ${i + 1}:');
        debugPrint('Câu lệnh: $statement');
        debugPrint('Lỗi: $e');
        rethrow; // Ném lại lỗi để dừng quá trình tạo database
      }
    }
    debugPrint('=== HOÀN THÀNH FILE: $fileName ===');
  }

  // Hàm callback khi database được tạo lần đầu
  // Thực thi các file SQL theo đúng thứ tự: tạo bảng, index, trigger, và dữ liệu mẫu
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
      debugPrint('LỖI TẠO DATABASE: $e');
    }
  }

  // Hàm callback sau khi mở database thành công
  // Bật ràng buộc khóa ngoại và kiểm tra cấu trúc bảng (dùng để debug)
  Future<void> _onOpen(Database db) async {
    // Bật hỗ trợ khóa ngoại (foreign key) cho SQLite
    await db.execute('PRAGMA foreign_keys = ON');
    debugPrint('Đã bật foreign_keys');

    // Lấy danh sách các bảng trong database (kiểm tra)
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    debugPrint('Các bảng trong database: $tables');

    // Kiểm tra cấu trúc bảng photos (in các cột và kiểu dữ liệu)
    final columns = await db.rawQuery('PRAGMA table_info(photos)');
    debugPrint('Cấu trúc bảng photos:');
    for (var col in columns) {
      debugPrint('  - ${col['name']} (${col['type']})');
    }
  }
}
