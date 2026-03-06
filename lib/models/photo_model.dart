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
        return Colors.green;  // Thành công
      case PhotoStatus.failed:
        return Colors.red;  // Lỗi
    }
  }
}
// Lớp đại diện cho một tác vụ ảnh cụ thể.
// Mỗi đối tượng PhotoTask sẽ chứa đầy đủ thông tin về định danh, đường dẫn file và trạng thái hiện tại.
class PhotoTask {
  final String id;  // ID duy nhất để phân biệt các tác vụ (thường dùng UUID hoặc timestamp).
  final String filePath;  // Đường dẫn vật lý của file ảnh trên thiết bị.
  final PhotoStatus status; // Trạng thái hiện tại của ảnh (sử dụng enum đã định nghĩa ở trên).
  
  // Constructor yêu cầu cung cấp đầy đủ thông tin khi khởi tạo một tác vụ.
  PhotoTask({
    required this.id, 
    required this.filePath, 
    required this.status
  });
}
