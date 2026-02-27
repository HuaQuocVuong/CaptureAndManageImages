import 'package:module_s1/database/database_helper.dart';
import 'package:module_s1/models/product_model.dart';
import 'package:sqflite/sqflite.dart';

// DAO (Data Access Object) cho đối tượng Product
// Quản lý việc truy vấn và thao tác dữ liệu trong bảng 'products'
class ProductDao {
  // Khởi tạo DatabaseHelper để quản lý việc mở và kết nối kết nối DB
  final DatabaseHelper _dbHelper = DatabaseHelper();

  //Thêm 1 sản phẩm mới - Trả về ID của dòng vừa được chèn (Dạng int)
  Future<int> insert(Product product) async {
    // Đợi lấy đối tượng Database từ helper
    Database db = await _dbHelper.database;
    // Chuyển đổi Product object sang Map để SQLite có thể hiểu và lưu trữ
    return await db.insert('products', product.toMap());
  }

  // Lấy danh sách tất cả sản phẩm - trả về đối tượng Product nếu tìm thấy, hoặc null nếu không tồn tại.
  Future<List<Product>> getAll() async {
    Database db = await _dbHelper.database;
    // Thực hiện truy vấn 'SELECT * FROM products'
    final List<Map<String, dynamic>> maps = await db.query('products');
    // Chuyển đổi danh sách các Map (dữ liệu thô từ DB) ngược lại thành danh sách Product objects
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  // Tìm kiếm sản phẩm theo theo ID - trả về đối tượng Product nếu tìm thấy, hoặc null nếu không tồn tại.
  Future<Product?> getById(int id) async {
    Database db = await _dbHelper.database;
    // Truy vấn có điều kiện WHERE để tránh SQL Injection bằng cách dùng whereArgs
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    // Nếu kết quả trả về có dữ liệu, lấy phần tử đầu tiên và chuyển sang object Product
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null; // Trả về null nếu không tìm thấy ID tương ứng
  }

  // Cập nhật thông tin sản phẩm - trả về số lượng dòng bị tác động
  Future<int> update(Product product) async {
    Database db = await _dbHelper.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?', // Xác định dòng cần cập nhật dựa trên ID
      whereArgs: [product.id],
    );
  }

  //Xóa sản phẩm khỏi CSDL - trả về số lượng dòng bị xóa
  Future<int> delete(int id) async {
    Database db = await _dbHelper.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
