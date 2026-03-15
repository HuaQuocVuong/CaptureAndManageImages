import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'product_manager.db');

    // XÓA DATABASE CŨ - CHỈ DÙNG KHI PHÁT TRIỂN
    try {
      await deleteDatabase(path);
      debugPrint('Đã xóa database cũ');
    } catch (e) {
      debugPrint('Lỗi khi xóa database cũ: $e');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

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

  Future<void> _executeSQLFile(Database db, String fileName) async {
    debugPrint('=== BẮT ĐẦU THỰC THI FILE: $fileName ===');

    String sql = await _loadSQLFile(fileName);
    if (sql.isEmpty) {
      debugPrint('FILE TRỐNG: $fileName');
      return;
    }

    debugPrint('Nội dung file (200 ký tự đầu):');
    debugPrint(sql.substring(0, sql.length > 200 ? 200 : sql.length));

    // Tách các câu lệnh SQL
    List<String> statements = sql
        .split(';')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    debugPrint('Tổng số câu lệnh: ${statements.length}');

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
        rethrow;
      }
    }
    debugPrint('=== HOÀN THÀNH FILE: $fileName ===');
  }

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

  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    debugPrint('Đã bật foreign_keys');

    // In cấu trúc bảng để kiểm tra
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    debugPrint('Các bảng trong database: $tables');

    // Kiểm tra cấu trúc bảng photos
    final columns = await db.rawQuery('PRAGMA table_info(photos)');
    debugPrint('Cấu trúc bảng photos:');
    for (var col in columns) {
      debugPrint('  - ${col['name']} (${col['type']})');
    }
  }
}
