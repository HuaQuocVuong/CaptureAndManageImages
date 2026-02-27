
import 'package:flutter/material.dart';

enum PhotoStatus {
  captured, // Vừa chụp xong
  queued, // Đang chờ xử lý
  processing, // Đang xử lý
  ready, // Sẵn sàng
  failed, // Lỗi
}

extension PhotoStatusExtension on PhotoStatus {
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

  Color get color {
    switch (this) {
      case PhotoStatus.captured:
        return Colors.blue;
      case PhotoStatus.queued:
        return Colors.orange;
      case PhotoStatus.processing:
        return Colors.purple;
      case PhotoStatus.ready:
        return Colors.green;
      case PhotoStatus.failed:
        return Colors.red;
    }
  }
}

class PhotoTask {
  final String id;
  final String filePath;
  final PhotoStatus status;

  PhotoTask({required this.id, required this.filePath, required this.status});
}
