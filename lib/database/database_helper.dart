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

    // QUAN TRỌNG: Uncomment dòng dưới đây nêú bạn muốn xóa DB cũ để áp dụng thay đổi mới
    await deleteDatabase(path);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  Future<String> _loadSQLFile(String fileName) async {
    try {
      // Đường dẫn phải khớp chính xác với khai báo trong pubspec.yaml
      return await rootBundle.loadString('lib/database/script/$fileName');
    } catch (e) {
      print('❌ Không tìm thấy file script: $fileName. Lỗi: $e');
      return '';
    }
  }

  Future<void> _executeSQLFile(Database db, String fileName) async {
    String sql = await _loadSQLFile(fileName);
    if (sql.isEmpty) return;

    // Tách các câu lệnh SQL nhưng giữ nguyên khối BEGIN...END của Trigger
    // Đây là điểm mấu chốt để tránh lỗi "Syntax error near END" trong SQLite
    final RegExp statementRegex = RegExp(r';(?=(?:[^]*BEGIN[^]*END)*[^]*$)');

    List<String> statements = sql
        .split(statementRegex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (var statement in statements) {
      try {
        await db.execute(statement);
      } catch (e) {
        //print('🚨 Lỗi thực thi lệnh trong $fileName:');
        //print('👉 Câu lệnh: $statement');
        //print('👉 Chi tiết lỗi: $e');
        rethrow; // Ném lỗi để dừng quá trình onCreate nếu có sai sót
      }
    }
    print('✅ Đã chạy xong file: $fileName');
  }

  Future<void> _onCreate(Database db, int version) async {
    //print('🔄 Đang bắt đầu quy trình tạo Database...');
    try {
      // Phải thực thi theo thứ tự: Bảng -> Index -> Trigger
      await _executeSQLFile(db, 'create_tables.sql');
      await _executeSQLFile(db, 'create_indexes.sql');
      await _executeSQLFile(db, 'create_triggers.sql');

      // Chạy seed data nếu file không trống
      await _executeSQLFile(db, 'seed_data.sql');

      //print('🚀 Database đã được khởi tạo thành công!');
    } catch (e) {
      //print('💥 Lỗi nghiêm trọng khi khởi tạo Database: $e');
    }
  }

  Future<void> _onOpen(Database db) async {
    // Kích hoạt Foreign Keys để tính năng xóa CASCADE hoạt động
    await db.execute('PRAGMA foreign_keys = ON');
    print('🔓 Kết nối Database mở - Foreign Keys đã bật');
  }
}
