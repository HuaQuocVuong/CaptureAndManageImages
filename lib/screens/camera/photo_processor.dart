import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/models/photo_model.dart';

class PhotoProcessor {
  final PhotoDao _photoDao = PhotoDao();
  final Function(PhotoTask) onUpdate;

  PhotoProcessor({required this.onUpdate});

  Future<void> process(PhotoTask task) async {
    // Lưu lại capturedAt từ task gốc
    final capturedAt = task.capturedAt;
    try {
      // Cập nhật trạng thái queued
      onUpdate(
        PhotoTask(
          id: task.id,
          filePath: task.filePath,
          status: PhotoStatus.queued,
          capturedAt: capturedAt,
        ),
      );
      await _photoDao.updateStatus(task.filePath, PhotoStatus.queued);
      await Future.delayed(const Duration(milliseconds: 500));

      // processing
      onUpdate(
        PhotoTask(
          id: task.id,
          filePath: task.filePath,
          status: PhotoStatus.processing,
          capturedAt: capturedAt,
        ),
      );
      await _photoDao.updateStatus(task.filePath, PhotoStatus.processing);
      await Future.delayed(const Duration(seconds: 2));

      // ready
      onUpdate(
        PhotoTask(
          id: task.id,
          filePath: task.filePath,
          status: PhotoStatus.ready,
          capturedAt: capturedAt,
        ),
      );
      await _photoDao.updateStatus(task.filePath, PhotoStatus.ready);
    } catch (e) {
      onUpdate(
        PhotoTask(
          id: task.id,
          filePath: task.filePath,
          status: PhotoStatus.failed,
          capturedAt: capturedAt,
        ),
      );
      await _photoDao.updateStatus(task.filePath, PhotoStatus.failed);
    }
  }
}
