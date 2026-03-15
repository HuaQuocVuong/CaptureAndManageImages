import 'package:flutter/material.dart';

/// Khai báo các trạng thái có thể có của một tác vụ xử lý ảnh.
enum PhotoStatus {
  captured, // Vừa chụp xong
  queued, // Đang chờ xử lý
  processing, // Đang xử lý
  ready, // Sẵn sàng (đã xử lý xong, có thể gán cho sản phẩm)
  failed, // Lỗi trong quá trình xử lý
}

// Trình bày tên trạng thái dưới dạng văn bản tiếng Việt để hiển thị lên giao diện (UI).
extension PhotoStatusExtension on PhotoStatus {
  /// Trình bày tên trạng thái dưới dạng văn bản tiếng Việt để hiển thị lên giao diện (UI).
  String get displayName {
    switch (this) {
      case PhotoStatus.captured:
        return 'Đã chụp';
      case PhotoStatus.queued:
        return 'Đang chờ';
      case PhotoStatus.processing:
        return 'Đang xử lý';
      case PhotoStatus.ready:
        return 'Sẵn sàng';
      case PhotoStatus.failed:
        return 'Lỗi';
    }
  }

  /// Trình bày màu sắc tương ứng với từng trạng thái để người dùng dễ nhận diện.
  Color get color {
    switch (this) {
      case PhotoStatus.captured:
        return Colors.blue; // Khởi đầu
      case PhotoStatus.queued:
        return Colors.orange; // Chờ
      case PhotoStatus.processing:
        return Colors.purple; // Đang xử lý
      case PhotoStatus.ready:
        return Colors.green; // Thành công
      case PhotoStatus.failed:
        return Colors.red; // Lỗi
    }
  }
}

// Lớp đại diện cho một tác vụ ảnh cụ thể.
// Mỗi đối tượng PhotoTask sẽ chứa đầy đủ thông tin về định danh, đường dẫn file và trạng thái hiện tại.
class PhotoTask {
  final String
  id; // ID duy nhất để phân biệt các tác vụ (thường dùng UUID hoặc timestamp).
  final String filePath; // Đường dẫn vật lý của file ảnh trên thiết bị.
  final PhotoStatus
  status; // Trạng thái hiện tại của ảnh (sử dụng enum đã định nghĩa ở trên).

  // Các trường metadata bổ sung
  final int? productId; // ID của sản phẩm liên kết (nếu có)
  final String? title; // Tiêu đề ảnh
  final String? description; // Mô tả ảnh
  final double? price; // Giá sản phẩm (nếu liên kết với sản phẩm)
  final String? category; // Danh mục sản phẩm
  final String? note; // Ghi chú thêm

  // Constructor yêu cầu cung cấp đầy đủ thông tin khi khởi tạo một tác vụ.
  PhotoTask({
    required this.id,
    required this.filePath,
    required this.status,
    this.productId,
    this.title,
    this.description,
    this.price,
    this.category,
    this.note,
  });

  /// Factory constructor để tạo PhotoTask từ Map (dùng khi query từ database)
  factory PhotoTask.fromMap(Map<String, dynamic> map) {
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

  /// Chuyển đổi PhotoTask thành Map để lưu vào database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': filePath,
      'status': status.name,
      'product_id': productId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'note': note,
    };
  }

  /// Tạo bản sao của PhotoTask với các giá trị được thay đổi
  PhotoTask copyWith({
    String? id,
    String? filePath,
    PhotoStatus? status,
    int? productId,
    String? title,
    String? description,
    double? price,
    String? category,
    String? note,
  }) {
    return PhotoTask(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }
}
