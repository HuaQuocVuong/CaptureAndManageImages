import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// Quản lý toàn bộ các thao tác liên quan đến camera
// Gồm: Khởi tạo + Chụp + Lưu + bật tắt Flash + Quản lý vòng đời(Dispose, resume...) + Callback thông báo trạng thái UI
class CameraControllerManager {
  CameraController? _controller; // Controller camera chính
  bool _disposed = false; // Cờ kiểm tra đã dispose chưa
  final List<CameraDescription> cameras; // Danh sách camera trên thiết bị
  final Function(String?) onError; // Callback khi xảy ra lỗi
  final Function(bool)
  onInitializingChanged; // Callback khi bắt đầu/kết thúc khởi tạo
  final Function() onCameraReady; // Callback khi camera đã sẵn sàng

  CameraControllerManager({
    required this.cameras,
    required this.onError,
    required this.onInitializingChanged,
    required this.onCameraReady,
  });
  // Kiểm tra xem camera đã được khởi tạo thành công chưa
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  CameraController? get controller => _controller;

  // Khởi tạo camera với thiết lập mặc định (camera trước, độ phân giải medium).
  // Nếu thành công, gọi onCameraReady; nếu lỗi, gọi onError.
  Future<void> initialize() async {
    if (cameras.isEmpty) {
      onError('Không tìm thấy camera trên thiết bị');
      return;
    }

    onInitializingChanged(true);
    try {
      await dispose();
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (!_disposed) {
        onCameraReady();
      }
    } on CameraException catch (e) {
      String errorMsg = 'Không thể khởi tạo camera';
      if (e.code == 'CameraAccessDenied')
        errorMsg = 'Không có quyền truy cập camera';
      else if (e.code == 'CameraDisabled')
        errorMsg = 'Camera đang bị vô hiệu hóa';
      else if (e.code == 'CameraNotFound')
        errorMsg = 'Không tìm thấy camera';
      onError(errorMsg);
    } catch (e) {
      onError('Lỗi không xác định');
    } finally {
      onInitializingChanged(false);
    }
  }

  // Giải phóng tài nguyên camera
  Future<void> dispose() async {
    _disposed = true;
    if (_controller != null) {
      await _controller?.dispose();
      _controller = null;
    }
  }

  // Chụp ảnh và lưu file vào thư mục `captured_images` trong bộ nhớ ứng dụng
  // Trả về đường dẫn file đã lưu, hoặc null nếu thất bại
  Future<String?> capture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${directory.path}/captured_images');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imagePath = path.join(imageDir.path, fileName);

      final XFile photo = await _controller!.takePicture();
      final savedFile = await File(photo.path).copy(imagePath);
      await File(photo.path).delete();
      return savedFile.path;
    } catch (e) {
      return null;
    }
  }

  // Bật/tắt đèn flash (torch mode)
  void toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final isFlashOn = _controller!.value.flashMode == FlashMode.torch;
    _controller?.setFlashMode(isFlashOn ? FlashMode.off : FlashMode.torch);
  }

  // Kiểm tra đèn flash hiện tại có đang bật không
  bool get isFlashOn => _controller?.value.flashMode == FlashMode.torch;
}
