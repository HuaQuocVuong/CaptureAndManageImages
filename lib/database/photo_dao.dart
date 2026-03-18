import 'package:module_s1/database/database_helper.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:sqflite/sqflite.dart';

// Data Access Object (DAO) cho bảng photos
// Tương tác với cơ sở dữ liệu cho các thao tác liên quan đến ảnh
class PhotoDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Getter để lấy database instance từ DatabaseHelper
  Future<Database> get _database async => await _dbHelper.database;

  // PHƯƠNG THỨC CƠ BẢN
  // Thêm một bản ghi ảnh mới vào database khi người dùng chụp ảnh
  // Trả về ID của bản ghi vừa được chèn
  Future<int> insert(String imagePath) async {
    Database db = await _database;
    final now = DateTime.now().toIso8601String(); // Timestamp hiện tại

    return await db.insert('photos', {
      'image_path': imagePath, // imagePath đường dẫn đến file ảnh trên thiết bị
      'status': PhotoStatus.captured.name, // Trạng thái mặc định: vừa chụp
      'product_id': null, // Chưa gán cho sản phẩm nào
      'created_at': now, // Thời gian tạo
      'updated_at': now, // Thời gian cập nhật
    });
  }

  // Thêm ảnh mới với đầy đủ thông tin metadata
  // Cho phép chèn ảnh kèm thông tin sản phẩm ngay từ đầu
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

    // Loại bỏ các trường null để tránh lỗi khi insert vào database
    // SQLite sẽ tự động gán NULL cho các trường không được cung cấp
    map.removeWhere((key, value) => value == null);

    final id = await db.insert('photos', map);
    //print('Đã thêm ảnh mới với metadata, id: $id');
    return id;
  }

  // Lấy ảnh theo ID
  // Trả về đối tượng PhotoTask hoặc null nếu không tìm thấy
  Future<PhotoTask?> getPhotoById(String id) async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'id = ?',
      whereArgs: [int.tryParse(id)], // Chuyển String sang int
    );

    if (maps.isEmpty) return null;
    return _mapToPhotoTask(maps.first);
  }

  // Lấy thông tin ảnh dựa trên đường dẫn file
  Future<PhotoTask?> getPhotoByPath(String imagePath) async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'image_path = ?',
      whereArgs: [imagePath],

      /// imagePath đường dẫn tuyệt đối đến file ảnh
    );

    if (maps.isEmpty) return null;
    return _mapToPhotoTask(maps.first);
  }

  // Lấy tất cả ảnh từ database, sắp xếp theo thời gian tạo mới nhất
  // Trả về danh sách các đối tượng PhotoTask
  Future<List<PhotoTask>> getAllPhotos() async {
    Database db = await _database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'photos',
        orderBy: 'created_at DESC', // Sắp xếp giảm dần theo thời gian tạo
      );

      return List.generate(maps.length, (i) {
        return _mapToPhotoTask(maps[i]);
      });
    } catch (e) {
      //print('Lỗi getAllPhotos: $e');
      return []; // Trả về danh sách rỗng nếu có lỗi
    }
  }

  // Lọc ảnh theo trạng thái
  /// status: trạng thái cần lọc (captured, processing, ready, failed)
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
      //print('Lỗi getPhotosByStatus: $e');
      return [];
    }
  }

  // Lấy danh sách ảnh thuộc về một sản phẩm cụ thể
  // productId: ID của sản phẩm
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

  // Lấy các ảnh đang chờ xử lý (không phải ready hoặc failed)
  // Thường dùng để hiển thị các tác vụ cần xử lý trong queue
  Future<List<PhotoTask>> getPendingTasks() async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'status NOT IN (?, ?)', // Loại trừ ready và failed
      whereArgs: [PhotoStatus.ready.name, PhotoStatus.failed.name],
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToPhotoTask).toList();
  }

  // Tìm kiếm ảnh dựa trên tiêu đề, mô tả hoặc ghi chú
  // query từ khóa tìm kiếm (không phân biệt hoa thường)
  Future<List<PhotoTask>> searchPhotos(String query) async {
    Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photos',
      where: 'title LIKE ? OR description LIKE ? OR note LIKE ?',
      whereArgs: [
        '%$query%',
        '%$query%',
        '%$query%',
      ], // cho phép tìm kiếm chứa từ khóa
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToPhotoTask).toList();
  }

  // PHƯƠNG THỨC CẬP NHẬT
  // Cập nhật metadata của ảnh (phương thức quan trọng nhất)
  // Đây là phương thức quan trọng nhất cho việc cập nhật thông tin ảnh
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

    // Chỉ thêm vào map nếu tham số không null
    if (productId != null) updates['product_id'] = productId;
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (category != null) updates['category'] = category;
    if (note != null) updates['note'] = note;
    if (status != null) updates['status'] = status.name;

    // Luôn cập nhật thời gian sửa đổi để biết lần cuối thay đổi
    updates['updated_at'] = DateTime.now().toIso8601String();

    if (updates.isNotEmpty) {
      await db.update('photos', updates, where: 'id = ?', whereArgs: [photoId]);
      //print('Đã cập nhật metadata cho photoId: $photoId');
    }
  }

  // Cập nhật toàn bộ thông tin của một đối tượng PhotoTask
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

  // Cập nhật trạng thái của ảnh dựa trên ID
  Future<void> updateStatus(String imagePath, PhotoStatus status) async {
    Database db = await _database;
    await db.update(
      'photos',
      {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
  }

  // Cập nhật trạng thái theo ID
  Future<void> updatePhotoStatus(int photoId, PhotoStatus status) async {
    Database db = await _database;
    await db.update(
      'photos',
      {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  // PHƯƠNG THỨC GÁN CHO SẢN PHẨM
  // Gán ảnh cho sản phẩm (theo đường dẫn)
  Future<void> assignToProduct(
    String imagePath, // imagePath đường dẫn file ảnh
    int productId, { // ID sản phẩm
    PhotoStatus newStatus =
        PhotoStatus.ready, // Trạng thái mới sau khi gán (mặc định là ready)
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

  /// Gán ảnh cho sản phẩm dựa trên ID
  Future<void> assignToProductById(
    int photoId, // [photoId] ID của ảnh
    int productId, { // [productId] ID sản phẩm
    PhotoStatus newStatus =
        PhotoStatus.ready, // newStatus trạng thái mới sau khi gán
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

  // PHƯƠNG THỨC XÓA
  // Xóa một ảnh khỏi database dựa trên ID
  Future<void> deletePhoto(int id) async {
    Database db = await _database;
    await db.delete('photos', where: 'id = ?', whereArgs: [id]);
    //print('Đã xóa ảnh ID: $id');
  }

  // Xóa một ảnh khỏi database dựa trên đường dẫn file
  Future<void> deletePhotoByPath(String imagePath) async {
    Database db = await _database;
    await db.delete('photos', where: 'image_path = ?', whereArgs: [imagePath]);
    //print('Đã xóa ảnh: $imagePath');
  }

  // PHƯƠNG THỨC THỐNG KÊ
  // Đếm số ảnh trong database, trả về số lượng ảnh
  Future<int> countPhotos() async {
    Database db = await _database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM photos'),
        ) ??
        0; // Trả về 0 nếu kết quả null
  }

  // Đếm số ảnh theo trạng thái cụ thể
  // Trả về số lượng ảnh với trạng thái đó
  Future<int> countPhotosByStatus(PhotoStatus status) async {
    Database db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM photos WHERE status = ?',
      [status.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Lấy metadata của ảnh (không bao gồm đường dẫn file)
  // Trả về Map chứa các trường metadata hoặc null nếu không tìm thấy
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

  // HELPER METHOD
  // Phương thức chuyển đổi Map từ database thành đối tượng PhotoTask
  // Trả về đối tượng PhotoTask tương ứng
  PhotoTask _mapToPhotoTask(Map<String, dynamic> map) {
    return PhotoTask(
      id: map['id'].toString(), // Chuyển int ID sang String
      filePath:
          map['image_path'] ?? '', // Đường dẫn file, mặc định rỗng nếu null
      status: PhotoStatus.values.firstWhere(
        (e) => e.name == map['status'], // Tìm enum tương ứng với tên trạng thái
        orElse: () =>
            PhotoStatus.captured, // Mặc định là captured nếu không tìm thấy
      ),
      productId: map['product_id'] as int?,
      title: map['title'] as String?,
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble(), // Chuyển từ num sang double
      category: map['category'] as String?,
      note: map['note'] as String?,
    );
  }
}
