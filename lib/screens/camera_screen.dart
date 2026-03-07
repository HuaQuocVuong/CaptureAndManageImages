import 'package:camera/camera.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/database/product_dao.dart';

import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/models/product_model.dart';

import 'package:module_s1/screens/photo_gallery_screen.dart';
import 'package:module_s1/screens/bulk_edit_screen.dart';

import 'package:module_s1/widgets/grid_painter.dart';

import '../metadata/metadata_form.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CameraScreen extends StatefulWidget {
  final List<CameraDescription>
  cameras; // Danh sách các camera có sẵn trên thiết bị
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

// WidgetsBindingObserver: Theo dõi trạng thái ứng dụng (background/foreground)
class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller; // Bộ điều khiển camera chính
  bool _isBatchMode =
      false; //Chế độ chụp: false = Single Shot, true = Batch Short
  List<PhotoTask> _queue = []; // Hàng đợi hiển thị các ảnh đang xử lý
  bool _isFlashOn = false; // Trạng thái đèn Flash/Torch
  final PhotoDao _photoDao = PhotoDao(); // Data Access Object cho ảnh
  final ProductDao _productDao =
      ProductDao(); // Data Access Object cho sản phẩm
  List<Product> _recentProducts = []; // Danh sách sản phẩm gần đây để gán nhanh
  bool _isCameraInitializing = false; // Đang trong quá trình khởi tạo camera
  String? _cameraError; // Lưu thông báo lỗi nếu camera hỏng
  bool _disposed = false; // Kiểm soát để tránh gọi lệnh lên widget đã bị hủy

  @override
  void initState() {
    super.initState();
    // Đăng ký observer để theo dõi khi người dùng thoát app ra màn hình chính/quay lại
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera(); // Khởi tạo phần cứng camera
    _loadRecentPhotos(); // Lấy danh sách ảnh đã chụp từ database
    _loadRecentProducts(); // Lấy danh sách sản phẩm từ database
  }

  // Xử lý logic khi ứng dụng thay đổi trạng thái (background/foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;

    if (state == AppLifecycleState.inactive) {
      _disposeController(); // Giải phóng camera khi thoát ra ngoài để app khác có thể dùng
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null) {
        _initializeCamera();
      } else if (!_controller!.value.isInitialized) {
        _initializeCamera(); // Khởi tạo lại khi người dùng quay lại app
      }
    }
  }

  // Kiểm tra xem controller camera có sẵn sàng sử dụng không
  bool _isControllerUsable() {
    return !_disposed &&
        _controller != null &&
        _controller!.value.isInitialized &&
        mounted;
  }

  // Giải phóng controller camera an toàn
  Future<void> _disposeController() async {
    if (_disposed) return;
    try {
      if (_controller != null) {
        final controller = _controller;
        _controller = null; // Ngăn không cho gọi controller nữa
        await controller?.dispose(); // Giải phóng tài nguyên camera
      }
    } catch (e) {
      print('Lỗi dispose controller: $e');
    }
  }

  /// Thiết lập camera: Độ phân giải, camera trước/sau, xử lý quyền truy cập
  Future<void> _initializeCamera() async {
    if (_disposed) return;

    // Trường hợp thiết bị không có camera
    if (widget.cameras.isEmpty) {
      setState(() {
        _cameraError = 'Không tìm thấy camera trên thiết bị';
        _isCameraInitializing = false;
      });
      return;
    }

    if (_isCameraInitializing) return;

    setState(() {
      _isCameraInitializing = true;
      _cameraError = null;
    });

    try {
      await _disposeController();

      _controller = CameraController(
        widget.cameras[0], // Camera mặc định: Camera sau
        ResolutionPreset.medium, // Độ phân giải trung bình
        enableAudio: false, // Không cần ghi âm khi chụp ảnh
      );

      await _controller!.initialize(); // Khởi tạo phần cứng

      if (_disposed || !mounted) {
        await _disposeController();
        return;
      }

      setState(() {
        _isCameraInitializing = false;
      });
    } on CameraException catch (e) {
      // Xử lý các lỗi đặc thù: Từ chối quyền, Camera bị hỏng...
      //print('Lỗi camera: ${e.code} - ${e.description}');

      // Phân loại lỗi camera phổ biến
      String errorMessage = 'Không thể khởi tạo camera';
      if (e.code == 'CameraAccessDenied') {
        errorMessage = 'Không có quyền truy cập camera';
      } else if (e.code == 'CameraDisabled') {
        errorMessage = 'Camera đang bị vô hiệu hóa';
      } else if (e.code == 'CameraNotFound') {
        errorMessage = 'Không tìm thấy camera';
      }

      if (!_disposed && mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = errorMessage;
        });
      }
    } catch (e) {
      print('Lỗi không xác định: $e');
      if (!_disposed && mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = 'Lỗi không xác định';
        });
      }
    }
  }

  // Tải danh sách ảnh gần đây từ database để hiển thị trong queue
  Future<void> _loadRecentPhotos() async {
    if (!mounted || _disposed) return; // Ngăn chặn bấm nút liên tục

    try {
      final photos = await _photoDao.getAllPhotos();
      if (!_disposed && mounted) {
        setState(() {
          _queue = photos.take(10).toList(); // Lấy tối đa 10 mới nhất
        });
      }
    } catch (e) {
      print('Lỗi load ảnh: $e');
    }
  }

  // Tải danh sách sản phẩm gần đây từ database
  Future<void> _loadRecentProducts() async {
    if (!mounted || _disposed) return;

    try {
      final products = await _productDao.getAll();
      if (!_disposed && mounted) {
        setState(() {
          _recentProducts = products.take(5).toList();
        });
      }
    } catch (e) {
      print('Lỗi load sản phẩm: $e');
    }
  }

  // Hiển thị dialog lỗi với nút thử lại
  void _showErrorDialog(String title, String message) {
    if (!mounted || _disposed) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _initializeCamera();
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  // Xử lý chụp ảnh: lưu file, cập nhật database, điều hướng theo chế độ
  Future<void> _handleCapture() async {
    // Camera chưa sẵn sàng
    if (!_isControllerUsable()) {
      _showSnackBar('Camera chưa sẵn sàng', isError: true);
      return;
    }

    if (_controller == null || _disposed || !mounted) {
      return;
    }
    // Đang chụp ảnh trước đó
    if (_controller!.value.isTakingPicture) {
      //_showSnackBar('Đang xử lý ảnh trước đó...', isError: true);
      return;
    }

    try {
      // Lấy thư mục app
      final directory = await getApplicationDocumentsDirectory();
      // Tạo folder lưu ảnh
      final imageDir = Directory('${directory.path}/captured_images');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      // Tạo tên file duy nhất
      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imagePath = path.join(imageDir.path, fileName);

      if (!_isControllerUsable()) return;

      final XFile photo = await _controller!.takePicture();

      if (!mounted || _disposed) {
        await File(photo.path).delete();
        return;
      }
      // Copy ảnh từ cache sang thư mục app
      final savedFile = await File(photo.path).copy(imagePath);
      await File(photo.path).delete(); // Xóa file tạm

      if (_isBatchMode) {
        // Chế độ Batch-Short: thêm vào queue và xử lý background
        final id = await _photoDao.insert(savedFile.path);
        final newTask = PhotoTask(
          id: id.toString(),
          filePath: savedFile.path,
          status: PhotoStatus.captured,
        );

        if (mounted) {
          setState(() => _queue.insert(0, newTask));
        }

        _processImageInBackground(newTask);
        //_showSnackBar('Đã chụp ảnh #${_queue.length}');
      } else {
        // Chế độ Singer-Short
        final id = await _photoDao.insert(savedFile.path);
        if (mounted) {
          _navigateToMetadata(savedFile.path, id);
        }
      }
    } on CameraException catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi chụp ảnh: ${e.description}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi: $e', isError: true);
      }
    }
  }

  // Xử lý ảnh trong background: cập nhật trạng thái qua các bước (queued, processing, ready)
  Future<void> _processImageInBackground(PhotoTask task) async {
    if (!mounted || _disposed) return;
    try {
      // Cập nhật trạng thái queued
      if (mounted && !_disposed) {
        // processing
        setState(() {
          final index = _queue.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _queue[index] = PhotoTask(
              id: task.id,
              filePath: task.filePath,
              status: PhotoStatus.queued,
            );
          }
        });
      }
      await _photoDao.updateStatus(task.filePath, PhotoStatus.queued);
      await Future.delayed(const Duration(milliseconds: 500));
      // Chuyển sang processing
      if (mounted && !_disposed) {
        setState(() {
          final index = _queue.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _queue[index] = PhotoTask(
              id: task.id,
              filePath: task.filePath,
              status: PhotoStatus.processing,
            );
          }
        });
      }
      await _photoDao.updateStatus(task.filePath, PhotoStatus.processing);
      await Future.delayed(const Duration(seconds: 2));
      // Chuyển sang ready
      if (mounted && !_disposed) {
        setState(() {
          final index = _queue.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _queue[index] = PhotoTask(
              id: task.id,
              filePath: task.filePath,
              status: PhotoStatus.ready,
            );
          }
        });
      }
      await _photoDao.updateStatus(task.filePath, PhotoStatus.ready);
    } catch (e) {
      // Xảy ra lỗi chuyển sang failed
      if (mounted && !_disposed) {
        setState(() {
          final index = _queue.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _queue[index] = PhotoTask(
              id: task.id,
              filePath: task.filePath,
              status: PhotoStatus.failed,
            );
          }
        });
      }
      await _photoDao.updateStatus(task.filePath, PhotoStatus.failed);
    }
  }

  // Chuyển đến màn hình nhập metadata cho 1 ảnh
  void _navigateToMetadata(String imagePath, int photoId) {
    if (!mounted || _disposed) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MetadataForm(imagePath: imagePath, photoId: photoId),
      ),
    ).then((_) {
      // Sau khi quay lại từ metadata, tải lại danh sách ảnh và sản phẩm
      if (!_disposed && mounted) {
        _loadRecentPhotos();
        _loadRecentProducts();
      }
    });
  }

  // Chuyển đến màn hình gallery
  void _navigateToGallery() {
    if (!mounted || _disposed) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhotoGalleryScreen()),
    ).then((_) {
      if (!_disposed && mounted) {
        _loadRecentPhotos();
      }
    });
  }

  // Chuyển đến màn hình chỉnh sửa hàng loạt (bulk edit) nếu có ảnh ready
  void _navigateToBulkEdit() {
    if (!mounted || _disposed) return;
    // Lọc ảnh đã xử lý xong
    final readyPhotos = _queue
        .where((p) => p.status == PhotoStatus.ready)
        .toList();

    if (readyPhotos.isEmpty) {
      //_showSnackBar('Chưa có ảnh nào sẵn sàng để chỉnh sửa');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BulkEditScreen(photos: readyPhotos, products: _recentProducts),
      ),
    ).then((_) {
      if (!_disposed && mounted) {
        _loadRecentPhotos();
        _loadRecentProducts();
      }
    });
  }

  // Chức năng bật/tắt flash (torch mode)
  void _toggleFlash() {
    if (!_isControllerUsable()) return;

    setState(() => _isFlashOn = !_isFlashOn);

    try {
      // Torch = bật sáng liên tục
      _controller?.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      //print('Lỗi flash: $e');
      //_showSnackBar('Không thể bật/tắt flash', isError: true);
    }
  }

  // Hiển thị thông báo ngắn (SnackBar)
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || _disposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // DISPOSE
  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this); // Hủy đăng ký observer
    _disposeController(); // Giải phóng camera
    super.dispose();
  }

  //BUILD UI
  @override
  Widget build(BuildContext context) {
    // Hiển thị màn hình lỗi nếu có lỗi camera
    if (_cameraError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                // Hiển thị nội dung lỗi cho người dùng
                Text(
                  _cameraError!,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Nút thử lại
                ElevatedButton(
                  onPressed: () {
                    setState(() => _cameraError = null);
                    _initializeCamera();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Không có camera
    if (widget.cameras.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Không tìm thấy camera trên thiết bị",
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      );
    }
    // Đang khởi tạo camera
    if (_isCameraInitializing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Đang khởi tạo camera..."),
            ],
          ),
        ),
      );
    }
    // CAMERA UI CHÍNH
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview toàn màn hình
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // Overlay đen phía trên
          // Grid Overlay lưới căn chỉnh
          Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // THÊM PHẦN NỀN ĐEN TRÊN VÀ DƯỚI ĐỂ TĂNG ĐỘ TƯƠNG PHẢN CHO GIAO DIỆN CHỤP ẢNH
          // Nền đen phía trên
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top + 60, // Độ cao
              color: Colors.black.withOpacity(
                1.0,
              ), // Độ trong suốt có thể điều chỉnh
            ),
          ),

          // Nền đen phía dưới
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 190, // Điều chỉnh độ cao theo ý muốn
              color: Colors.black.withOpacity(
                1.0,
              ), // Độ trong suốt có thể điều chỉnh
            ),
          ),

          // TOP BAR
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nút quay lại
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                // Hiển thị mode hiện tại
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isBatchMode ? Icons.layers : Icons.photo_camera,
                        color: Colors.pinkAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isBatchMode ? 'Batch: ${_queue.length}' : 'Single',
                        style: const TextStyle(
                          color: Colors.pinkAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Nút bật tắt flash
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn ? Colors.yellow : Colors.grey,
                  ),
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // Hàng đợi ảnh đang xử lý (chỉ hiển thị khi ở chế độ hàng loạt và có ảnh trong queue)
          if (_isBatchMode && _queue.isNotEmpty)
            Positioned(
              top: 100,
              right: 10,
              bottom: 200,
              child: SizedBox(
                width: 80,
                child: ListView.builder(
                  itemCount: _queue.length > 10 ? 10 : _queue.length,
                  itemBuilder: (context, index) =>
                      _buildQueueThumbnail(_queue[index]),
                ),
              ),
            ),

          // CÁC NÚT ĐIỀU KHIỂN
          // NÚT GALLERY - Góc trái dưới
          Positioned(
            bottom: 40,
            left: 24,
            child: GestureDetector(
              onTap: _navigateToGallery,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: _queue.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.file(
                          File(_queue.first.filePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.photo_library,
                            color: Colors.green,
                            size: 30,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.photo_library,
                        color: Colors.green,
                        size: 30,
                      ),
              ),
            ),
          ),

          // NÚT CHỤP ẢNH - Chính giữa
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _handleCapture,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isBatchMode
                          ? Colors.pinkAccent
                          : Colors.blueAccent,
                      width: 4,
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // NÚT MODE SWITCH - Bên phải, phía trên
          Positioned(
            bottom: 127,
            right: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: Icon(
                  _isBatchMode ? Icons.layers_clear : Icons.layers,
                  color: _isBatchMode ? Colors.purple : Colors.pinkAccent,
                  size: 32,
                ),
                onPressed: () {
                  setState(() => _isBatchMode = !_isBatchMode);
                },
              ),
            ),
          ),

          // NÚT BULK EDIT - Bên phải, phía dưới (chỉ hiện khi batch mode)
          if (_isBatchMode)
            Positioned(
              bottom: 40,
              right: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: _queue.isNotEmpty ? Colors.black54 : Colors.black26,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.edit_note,
                    color: Colors.deepOrange,
                    size: 32,
                  ),
                  onPressed: (_queue.isNotEmpty)
                      ? () {
                          final readyPhotos = _queue
                              .where((p) => p.status == PhotoStatus.ready)
                              .toList();
                          if (readyPhotos.isEmpty) {
                            //_showSnackBar('Chưa có ảnh nào xử lý xong');
                          } else {
                            _navigateToBulkEdit();
                          }
                        }
                      : null,
                ),
              ),
            ),

          // MODE INDICATOR - Phía trên nút chụp
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isBatchMode ? Colors.pinkAccent : Colors.blueAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isBatchMode ? "BATCH MODE" : "SINGLE MODE",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // READY COUNT - Cạnh nút bulk edit
          if (_isBatchMode && _queue.isNotEmpty)
            Positioned(
              bottom: 100,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_queue.where((p) => p.status == PhotoStatus.ready).length}/${_queue.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueThumbnail(PhotoTask task) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.image;

    switch (task.status) {
      case PhotoStatus.captured:
        statusColor = Colors.blue;
        statusIcon = Icons.camera_alt;
        break;
      case PhotoStatus.queued:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case PhotoStatus.processing:
        statusColor = Colors.purple;
        statusIcon = Icons.sync;
        break;
      case PhotoStatus.ready:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PhotoStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return GestureDetector(
      onTap: () {
        // Chỉ cho mở metadata khi ảnh đã ready
        if (task.status == PhotoStatus.ready) {
          _navigateToMetadata(task.filePath, int.parse(task.id));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          border: Border.all(color: statusColor, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.black26,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail ảnh
            FutureBuilder<bool>(
              future: File(task.filePath).exists(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(task.filePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(Icons.broken_image, color: statusColor),
                        );
                      },
                    ),
                  );
                }
                // Nếu không tồn tại file
                return Center(child: Icon(statusIcon, color: statusColor));
              },
            ),

            // Overlay trạng thái (nếu chưa ready)
            if (task.status != PhotoStatus.ready)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (task.status == PhotoStatus.processing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.purple,
                            ),
                          ),
                        )
                      else
                        Icon(statusIcon, color: statusColor, size: 20),

                      const SizedBox(height: 2),
                      // Hiển thị chữ cái đầu của status
                      Text(
                        task.status.name[0].toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
