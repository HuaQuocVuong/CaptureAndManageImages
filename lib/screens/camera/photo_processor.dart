import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/models/photo_model.dart';

// Xử lý ảnh sau khi chụp của Bacth-Short  (Chưa hoàn thiện)
// captured -> queued -> processing -> ready
class PhotoProcessor {
  final PhotoDao _photoDao = PhotoDao();
  // Callback được gọi mỗi khi trạng thái ảnh thay đổi
  // cho phép UI cập nhật tương ứng (thường dùng để refresh danh sách hàng đợi).
  final Function(PhotoTask) onUpdate;

  PhotoProcessor({required this.onUpdate});

  Future<void> process(PhotoTask task) async {
    try {
      // Cập nhật trạng thái queued (đã đưa vào hàng đợi)
      onUpdate(
        PhotoTask(
          id: task.id,
          filePath: task.filePath,
          status: PhotoStatus.queued,
        ),
      );
      await _photoDao.updateStatus(task.filePath, PhotoStatus.queued);
      // Mô phỏng thời gian xử lý (có thể thay bằng logic thực tế)
      await Future.delayed(const Duration(milliseconds: 500));

      // Chuyển sang trạng thái processing (đang xử lý)
      onUpdate(
        PhotoTask(
          id: task.id,
          filePath: task.filePath,
          status: PhotoStatus.processing,
        ),
      );
      await _photoDao.updateStatus(task.filePath, PhotoStatus.processing);
      // Mô phỏng thời gian xử lý ảnh
      await Future.delayed(const Duration(seconds: 2));

      // Chuyển sang trạng thái ready (sẵn sàng để nhập metadata)
      onUpdate(
        PhotoTask(
          id: task.id,
          filePath: task.filePath,
          status: PhotoStatus.ready,
        ),
      );
      await _photoDao.updateStatus(task.filePath, PhotoStatus.ready);
    } catch (e) {
      // Nếu có lỗi, cập nhật trạng thái failed
      onUpdate(
        PhotoTask(
          id: task.id,
          filePath: task.filePath,
          status: PhotoStatus.failed,
        ),
      );
      await _photoDao.updateStatus(task.filePath, PhotoStatus.failed);
    }
  }
}
