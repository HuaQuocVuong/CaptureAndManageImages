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
      version: 2, // Tăng version lên 2 để có thể cập nhật cấu trúc
      onCreate: _onCreate, // Gọi khi database được tạo lần đầu
      onUpgrade: _onUpgrade, // Gọi khi nâng cấp version
      onOpen: _onOpen, // Gọi sau khi mở database thành công
    );
  }

  // Xử lý nâng cấp database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('=== NÂNG CẤP DATABASE từ $oldVersion lên $newVersion ===');

    if (oldVersion < 2) {
      try {
        // Thêm các cột mới cho bảng products
        await _addNewColumnsToProducts(db);

        // Thêm các cột mới cho bảng photos
        await _addNewColumnsToPhotos(db);

        debugPrint('=== NÂNG CẤP DATABASE THÀNH CÔNG ===');
      } catch (e) {
        debugPrint('=== LỖI NÂNG CẤP DATABASE: $e ===');
        rethrow;
      }
    }
  }

  // Thêm cột mới cho bảng products (nếu chưa có)
  Future<void> _addNewColumnsToProducts(Database db) async {
    try {
      // Kiểm tra cấu trúc bảng products
      final columns = await db.rawQuery('PRAGMA table_info(products)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      // Thêm cột productType nếu chưa có
      if (!columnNames.contains('productType')) {
        await db.execute('ALTER TABLE products ADD COLUMN productType TEXT');
        debugPrint('Đã thêm cột productType vào bảng products');
      } else {
        debugPrint('Cột productType đã tồn tại trong bảng products');
      }

      // Thêm cột color nếu chưa có
      if (!columnNames.contains('color')) {
        await db.execute('ALTER TABLE products ADD COLUMN color TEXT');
        debugPrint('Đã thêm cột color vào bảng products');
      } else {
        debugPrint('Cột color đã tồn tại trong bảng products');
      }
    } catch (e) {
      debugPrint('Lỗi khi thêm cột mới cho products: $e');
      rethrow;
    }
  }

  // Thêm cột mới cho bảng photos (nếu chưa có)
  Future<void> _addNewColumnsToPhotos(Database db) async {
    try {
      // Kiểm tra cấu trúc bảng photos
      final columns = await db.rawQuery('PRAGMA table_info(photos)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      // Thêm cột productType nếu chưa có
      if (!columnNames.contains('productType')) {
        await db.execute('ALTER TABLE photos ADD COLUMN productType TEXT');
        debugPrint('Đã thêm cột productType vào bảng photos');
      } else {
        debugPrint('Cột productType đã tồn tại trong bảng photos');
      }

      // Thêm cột color nếu chưa có
      if (!columnNames.contains('color')) {
        await db.execute('ALTER TABLE photos ADD COLUMN color TEXT');
        debugPrint('Đã thêm cột color vào bảng photos');
      } else {
        debugPrint('Cột color đã tồn tại trong bảng photos');
      }
    } catch (e) {
      debugPrint('Lỗi khi thêm cột mới cho photos: $e');
      rethrow;
    }
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

      // Kiểm tra cấu trúc bảng products
      final hasProducts = tables.any((t) => t['name'] == 'products');
      if (hasProducts) {
        final columns = await db.rawQuery('PRAGMA table_info(products)');
        debugPrint('Cấu trúc bảng products:');
        for (var col in columns) {
          debugPrint('  - ${col['name']} (${col['type']})');
        }
      } else {
        debugPrint('Bảng products chưa được tạo!');
      }

      // Kiểm tra cấu trúc bảng photos
      final hasPhotos = tables.any((t) => t['name'] == 'photos');
      if (hasPhotos) {
        final columns = await db.rawQuery('PRAGMA table_info(photos)');
        debugPrint('Cấu trúc bảng photos:');
        for (var col in columns) {
          debugPrint('  - ${col['name']} (${col['type']})');
        }
      } else {
        debugPrint('Bảng photos chưa được tạo!');
      }
    } catch (e) {
      debugPrint('Lỗi trong _onOpen: $e');
    }
  }

  // ========== PHƯƠNG THỨC CRUD CHO PRODUCTS ==========

  // Lấy tất cả sản phẩm
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    try {
      return await db.query('products', orderBy: 'created_at DESC');
    } catch (e) {
      debugPrint('Lỗi getAllProducts: $e');
      return [];
    }
  }

  // Lấy sản phẩm theo ID
  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> results = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Lỗi getProductById: $e');
      return null;
    }
  }

  // Thêm sản phẩm mới
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    try {
      final now = DateTime.now().toIso8601String();
      product['created_at'] = now;
      product['updated_at'] = now;

      // Loại bỏ các giá trị null để tránh lỗi
      product.removeWhere((key, value) => value == null);

      return await db.insert('products', product);
    } catch (e) {
      debugPrint('Lỗi insertProduct: $e');
      debugPrint('Product data: $product');
      return -1;
    }
  }

  // Cập nhật sản phẩm
  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    try {
      product['updated_at'] = DateTime.now().toIso8601String();

      // Loại bỏ các giá trị null
      product.removeWhere((key, value) => value == null);

      return await db.update(
        'products',
        product,
        where: 'id = ?',
        whereArgs: [product['id']],
      );
    } catch (e) {
      debugPrint('Lỗi updateProduct: $e');
      return 0;
    }
  }

  // Xóa sản phẩm (cascade sẽ tự động xóa các ảnh liên quan)
  Future<int> deleteProduct(int id) async {
    final db = await database;
    try {
      return await db.delete('products', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Lỗi deleteProduct: $e');
      return 0;
    }
  }

  // ========== PHƯƠNG THỨC CRUD CHO PHOTOS ==========

  // Lấy tất cả ảnh
  Future<List<Map<String, dynamic>>> getAllPhotos() async {
    final db = await database;
    try {
      return await db.query('photos', orderBy: 'created_at DESC');
    } catch (e) {
      debugPrint('Lỗi getAllPhotos: $e');
      return [];
    }
  }

  // Lấy ảnh theo product_id
  Future<List<Map<String, dynamic>>> getPhotosByProductId(int productId) async {
    final db = await database;
    try {
      return await db.query(
        'photos',
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint('Lỗi getPhotosByProductId: $e');
      return [];
    }
  }

  // Lấy ảnh theo ID
  Future<Map<String, dynamic>?> getPhotoById(int id) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> results = await db.query(
        'photos',
        where: 'id = ?',
        whereArgs: [id],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Lỗi getPhotoById: $e');
      return null;
    }
  }

  // Lấy ảnh theo đường dẫn
  Future<Map<String, dynamic>?> getPhotoByPath(String imagePath) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> results = await db.query(
        'photos',
        where: 'image_path = ?',
        whereArgs: [imagePath],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Lỗi getPhotoByPath: $e');
      return null;
    }
  }

  // Lấy ảnh theo trạng thái
  Future<List<Map<String, dynamic>>> getPhotosByStatus(String status) async {
    final db = await database;
    try {
      return await db.query(
        'photos',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint('Lỗi getPhotosByStatus: $e');
      return [];
    }
  }

  // Thêm ảnh mới
  Future<int> insertPhoto(Map<String, dynamic> photo) async {
    final db = await database;
    try {
      final now = DateTime.now().toIso8601String();
      photo['created_at'] = now;
      photo['updated_at'] = now;

      // Loại bỏ các giá trị null
      photo.removeWhere((key, value) => value == null);

      return await db.insert('photos', photo);
    } catch (e) {
      debugPrint('Lỗi insertPhoto: $e');
      debugPrint('Photo data: $photo');
      return -1;
    }
  }

  // Cập nhật ảnh
  Future<int> updatePhoto(Map<String, dynamic> photo) async {
    final db = await database;
    try {
      photo['updated_at'] = DateTime.now().toIso8601String();

      // Loại bỏ các giá trị null
      photo.removeWhere((key, value) => value == null);

      return await db.update(
        'photos',
        photo,
        where: 'id = ?',
        whereArgs: [photo['id']],
      );
    } catch (e) {
      debugPrint('Lỗi updatePhoto: $e');
      return 0;
    }
  }

  // Cập nhật trạng thái ảnh
  Future<int> updatePhotoStatus(int id, String status) async {
    final db = await database;
    try {
      return await db.update(
        'photos',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Lỗi updatePhotoStatus: $e');
      return 0;
    }
  }

  // Xóa ảnh
  Future<int> deletePhoto(int id) async {
    final db = await database;
    try {
      return await db.delete('photos', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Lỗi deletePhoto: $e');
      return 0;
    }
  }

  // Xóa ảnh theo đường dẫn
  Future<int> deletePhotoByPath(String imagePath) async {
    final db = await database;
    try {
      return await db.delete(
        'photos',
        where: 'image_path = ?',
        whereArgs: [imagePath],
      );
    } catch (e) {
      debugPrint('Lỗi deletePhotoByPath: $e');
      return 0;
    }
  }

  // Xóa tất cả ảnh của một sản phẩm
  Future<int> deletePhotosByProductId(int productId) async {
    final db = await database;
    try {
      return await db.delete(
        'photos',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    } catch (e) {
      debugPrint('Lỗi deletePhotosByProductId: $e');
      return 0;
    }
  }

  // Xóa ảnh theo trạng thái
  Future<int> deletePhotosByStatus(String status) async {
    final db = await database;
    try {
      return await db.delete(
        'photos',
        where: 'status = ?',
        whereArgs: [status],
      );
    } catch (e) {
      debugPrint('Lỗi deletePhotosByStatus: $e');
      return 0;
    }
  }

  // ========== PHƯƠNG THỨC TÌM KIẾM ==========

  // Tìm kiếm sản phẩm theo tên
  Future<List<Map<String, dynamic>>> searchProducts(String keyword) async {
    final db = await database;
    try {
      return await db.query(
        'products',
        where: 'name LIKE ?',
        whereArgs: ['%$keyword%'],
        orderBy: 'name ASC',
      );
    } catch (e) {
      debugPrint('Lỗi searchProducts: $e');
      return [];
    }
  }

  // Tìm kiếm sản phẩm nâng cao (theo tên và danh mục)
  Future<List<Map<String, dynamic>>> searchProductsAdvanced({
    String? keyword,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) async {
    final db = await database;
    try {
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

      String whereClause = conditions.isNotEmpty
          ? conditions.join(' AND ')
          : '';

      return await db.query(
        'products',
        where: whereClause,
        whereArgs: args,
        orderBy: 'name ASC',
      );
    } catch (e) {
      debugPrint('Lỗi searchProductsAdvanced: $e');
      return [];
    }
  }

  // Tìm kiếm ảnh theo tiêu đề hoặc mô tả
  Future<List<Map<String, dynamic>>> searchPhotos(String keyword) async {
    final db = await database;
    try {
      return await db.query(
        'photos',
        where: 'title LIKE ? OR description LIKE ? OR note LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint('Lỗi searchPhotos: $e');
      return [];
    }
  }

  // ========== PHƯƠNG THỨC THỐNG KÊ ==========

  // Đếm tổng số sản phẩm
  Future<int> countProducts() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Lỗi countProducts: $e');
      return 0;
    }
  }

  // Đếm tổng số ảnh
  Future<int> countPhotos() async {
    final db = await database;
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM photos');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Lỗi countPhotos: $e');
      return 0;
    }
  }

  // Đếm số ảnh theo trạng thái
  Future<int> countPhotosByStatus(String status) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM photos WHERE status = ?',
        [status],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Lỗi countPhotosByStatus: $e');
      return 0;
    }
  }

  // Đếm số ảnh theo sản phẩm
  Future<int> countPhotosByProduct(int productId) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM photos WHERE product_id = ?',
        [productId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Lỗi countPhotosByProduct: $e');
      return 0;
    }
  }

  // Lấy tổng giá trị sản phẩm
  Future<double> getTotalProductValue() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT SUM(price) as total FROM products',
      );
      return result.first['total'] as double? ?? 0.0;
    } catch (e) {
      debugPrint('Lỗi getTotalProductValue: $e');
      return 0.0;
    }
  }

  // Lấy giá trị trung bình của sản phẩm
  Future<double> getAverageProductPrice() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT AVG(price) as avg_price FROM products',
      );
      return result.first['avg_price'] as double? ?? 0.0;
    } catch (e) {
      debugPrint('Lỗi getAverageProductPrice: $e');
      return 0.0;
    }
  }

  // Lấy sản phẩm theo danh mục (kèm số lượng)
  Future<List<Map<String, dynamic>>> getProductsGroupByCategory() async {
    final db = await database;
    try {
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
    } catch (e) {
      debugPrint('Lỗi getProductsGroupByCategory: $e');
      return [];
    }
  }

  // ========== PHƯƠNG THỨC TIỆN ÍCH ==========

  // Kiểm tra ảnh đã tồn tại chưa
  Future<bool> isPhotoExists(String imagePath) async {
    final db = await database;
    try {
      final result = await db.query(
        'photos',
        where: 'image_path = ?',
        whereArgs: [imagePath],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Lỗi isPhotoExists: $e');
      return false;
    }
  }

  // Thêm nhiều ảnh cùng lúc (batch insert)
  Future<void> insertMultiplePhotos(List<Map<String, dynamic>> photos) async {
    final db = await database;
    try {
      Batch batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (var photo in photos) {
        photo['created_at'] = now;
        photo['updated_at'] = now;
        photo.removeWhere((key, value) => value == null);
        batch.insert('photos', photo);
      }

      await batch.commit(noResult: true);
      debugPrint('Đã thêm ${photos.length} ảnh thành công');
    } catch (e) {
      debugPrint('Lỗi insertMultiplePhotos: $e');
    }
  }

  // Reset database (xóa và tạo lại)
  Future<void> resetDatabase() async {
    final db = await database;
    try {
      await db.delete('photos');
      await db.delete('products');
      debugPrint('Đã xóa tất cả dữ liệu');
    } catch (e) {
      debugPrint('Lỗi resetDatabase: $e');
    }
  }

  // Xóa hoàn toàn database file (chỉ dùng cho development)
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

  // Lấy thông tin database
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    try {
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
    } catch (e) {
      debugPrint('Lỗi getDatabaseInfo: $e');
      return {};
    }
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
