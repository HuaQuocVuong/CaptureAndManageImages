// batch_mode_service.dart
/*

import 'package:flutter/material.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/models/product_model.dart';
import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/database/product_dao.dart';

class BatchModeService {
  final PhotoDao _photoDao = PhotoDao();
  final ProductDao _productDao = ProductDao();
  
  // Lưu trạng thái batch hiện tại
  static List<PhotoTask>? currentBatch;
  static bool isBatchMode = true;
  
  // Thêm ảnh vào batch
  Future<void> addToBatch(PhotoTask photo) async {
    if (currentBatch == null) {
      currentBatch = [];
    }
    currentBatch!.add(photo);
    
    // Lưu vào database với status queued
    await _photoDao.insert(photo);
  }
  
  // Lấy tất cả ảnh trong batch
  List<PhotoTask> getBatchPhotos() {
    return currentBatch ?? [];
  }
  
  // Xóa ảnh khỏi batch
  Future<void> removeFromBatch(String photoId) async {
    currentBatch?.removeWhere((p) => p.id == photoId);
    await _photoDao.delete(photoId);
  }
  
  // Clear batch
  Future<void> clearBatch() async {
    if (currentBatch != null) {
      for (var photo in currentBatch!) {
        await _photoDao.delete(photo.id);
      }
      currentBatch = null;
    }
  }
  
  // Xử lý batch metadata
  // Cập nhật hàm processBatchMetadata để gán metadata đồng loạt
  Future<BatchProcessResult> processBatchMetadata({
    required List<PhotoTask> photos,
    required Product product,
    String? title,
    String? category,
    double? price,
    String? note,
  }) async {
    int successCount = 0;
    List<String> errors = [];

    for (var photo in photos) {
      try {
        // Gán cùng một bộ metadata từ form cho từng photoId
        await _photoDao.updatePhotoMetadata(
          int.parse(photo.id),
          productId: product.id!,
          title: title ?? product.name, // Ưu tiên title từ form, nếu không lấy tên SP
          description: note, 
          category: category ?? product.category,
          price: price ?? product.price,
          note: note ?? product.note,
          status: PhotoStatus.ready, // Đánh dấu đã xong để ẩn khỏi queue camera
        );
        successCount++;
      } catch (e) {
        errors.add('Lỗi ảnh ${photo.id}: $e');
      }
    }

    return BatchProcessResult(
      successCount: successCount,
      totalCount: photos.length,
      errors: errors,
    );
  }
  
  // Thống kê batch
  BatchStatistics getBatchStatistics() {
    if (currentBatch == null || currentBatch!.isEmpty) {
      return BatchStatistics.empty();
    }
    
    return BatchStatistics(
      total: currentBatch!.length,
      captured: currentBatch!.where((p) => p.status == PhotoStatus.captured).length,
      queued: currentBatch!.where((p) => p.status == PhotoStatus.queued).length,
      processing: currentBatch!.where((p) => p.status == PhotoStatus.processing).length,
      ready: currentBatch!.where((p) => p.status == PhotoStatus.ready).length,
      failed: currentBatch!.where((p) => p.status == PhotoStatus.failed).length,
    );
  }
}

class BatchProcessResult {
  final int successCount;
  final int totalCount;
  final List<String> errors;
  
  BatchProcessResult({
    required this.successCount,
    required this.totalCount,
    required this.errors,
  });
  
  bool get isSuccess => successCount == totalCount;
  bool get hasErrors => errors.isNotEmpty;
}

class BatchStatistics {
  final int total;
  final int captured;
  final int queued;
  final int processing;
  final int ready;
  final int failed;
  
  BatchStatistics({
    required this.total,
    required this.captured,
    required this.queued,
    required this.processing,
    required this.ready,
    required this.failed,
  });
  
  factory BatchStatistics.empty() {
    return BatchStatistics(
      total: 0,
      captured: 0,
      queued: 0,
      processing: 0,
      ready: 0,
      failed: 0,
    );
  }
}
*/
